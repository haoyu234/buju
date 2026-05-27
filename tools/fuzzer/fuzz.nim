import buju

import std/sequtils

import ./action
import ./diff
import ./nodes
import ./utils

const
  USE_LIBFUZZER = true
  USE_BROWSER_DIFF = false

when USE_BROWSER_DIFF:
  import ./client

  var
    c: TcpClient

  let
    PORT = uint16(2026)
    HOST = getEnv("server", "localhost")

  proc ensureClient(host: string, port: uint16) =
    # Loop until the serve process is reachable. A missing or not-yet-ready
    # serve must not be reported as a fuzzing crash (the harness turns
    # exceptions into a signal), so wait here instead of failing fast.
    var
      attempts = int32(0)
    while c.isNil or c.isClosed:
      try:
        c = connect(host, port)
      except CatchableError as e:
        echo e.msg

        c = nil
        inc attempts
        if attempts mod 50 == 0:
          echo "serve not reachable, retrying, attempt ", attempts
        sleep(200)

  proc runFuzzDiff(data: openArray[byte]): DiffReport =
    var
      ctx: Context

    ensureClient(HOST, PORT)

    c.send([byte(0)]) # mode: step-by-step
    c.send(data)

    let
      actions = data.actions().toSeq

    for idx in 0 ..< int32(actions.len):
      let
        param = actions[idx]

      if param.action == NEW:
        doAction(ctx, param)
        continue

      var
        copied = ctx

      doAction(copied, param)

      let
        n = copied.node1(param)
      if not copied.contains(n):
        assert false

      var
        root = n
      if param.action != COMPUTE:
        root = copied.getRoot(n)
      copied.compute(root)

      let
        result1 = dumpResultBinary(copied, root)
        result2 = c.next()

      if c.isClosed:
        raise newException(DiffError, "serve closed mid-replay")

      result = doDiff(idx, root, result1, result2)
      if result.code != NoError:
        c.send([byte(1)]) # divergence found: stop this input early
        break

      ctx = move copied

      if idx == actions.len - 1:
        c.send([byte(1)])
      else:
        c.send([byte(0)])

else:
  proc runFuzzDiff(data: openArray[byte]): DiffReport =
    var
      ctx: Context

    let
      actions = data.actions().toSeq

    for idx in 0 ..< int32(actions.len):
      let
        param = actions[idx]

      if param.action == NEW:
        doAction(ctx, param)
        continue

      var
        copied = ctx

      doAction(copied, param)

      let
        n = copied.node1(param)
      if not copied.contains(n):
        assert false

      var
        root = n
      if param.action != COMPUTE:
        root = copied.getRoot(n)
      copied.compute(root)

      discard dumpResultBinary(copied, root)

      ctx = move copied

when USE_LIBFUZZER:
  # libFuzzer harness. Build with e.g.
  #   nim c -d:libFuzzer -fsanitize=fuzzer fuzz.nim
  # Requires a Clang/libFuzzer toolchain (typically Linux). The standalone CLI
  # build below is unaffected by this branch.
  when defined(linux):
    import std/posix

  proc LLVMFuzzerInitialize(): cint {.exportc: "LLVMFuzzerInitialize".} =
    {.emit: "N_CDECL(void, NimMain)(void); NimMain();".}

  proc LLVMFuzzerTestOneInput(data: ptr UncheckedArray[byte], len: int): cint {.
      exportc: "LLVMFuzzerTestOneInput", raises: [].} =
    try:
      if len <= 0:
        return

      let
        report = runFuzzDiff(data.toOpenArray(0, len - 1))
      if report.code != NoError:
        echo fmtReport(report, "fuzz")

        when defined(linux):
          discard kill(getpid(), SIGSEGV)

    except Exception as e:
      echo "Error: ", e.msg

      when defined(linux):
        discard kill(getpid(), SIGSEGV)
else:
  import std/os
  import std/random
  import std/times

  const
    MAX_INPUT_LEN = 600

    CRASH_OUT_DIR = "crash"

    CORPUS_CAP = 2000
    CORPUS_IN_DIR = "fuzz_corpus"

  proc ensureDirs() =
    for d in [CRASH_OUT_DIR, CORPUS_IN_DIR]:
      if not dirExists(d):
        createDir(d)

  proc loadSeeds(): seq[seq[byte]] =
    for pattern in ["crash-*", CORPUS_IN_DIR & "/*", CRASH_OUT_DIR & "/*"]:
      for f in walkFiles(pattern):
        result.add(cast[seq[byte]](readFile(f)))

  proc saveBinary(input: seq[byte], iters: int32, prefix: string) =
    let
      name = CRASH_OUT_DIR / prefix & "-" & $iters & "-" & $(int(epochTime()))
    writeFile(name, input)
    echo "  >> saved: ", name, " ", input.len, " bytes"

  proc genRandom(r: var Rand): seq[byte] =
    let
      n = r.rand(1 .. MAX_INPUT_LEN)
    result = newSeq[byte](n)
    for i in 0 ..< n:
      result[i] = byte(r.rand(255))

  proc mutate(r: var Rand, data: var seq[byte]) =
    if data.len == 0:
      data.add(byte(r.rand(255)))
      return

    case r.rand(0 .. 3):
    of 0: # bit flip
      let
        i = r.rand(0 ..< data.len)
      data[i] = byte(uint8(data[i]) xor (uint8(1) shl r.rand(0 .. 7)))
    of 1: # byte overwrite
      let
        i = r.rand(0 ..< data.len)
      data[i] = byte(r.rand(255))
    of 2: # insert
      let
        i = r.rand(0 .. data.len)
      data.insert(byte(r.rand(255)), i)
      if data.len > MAX_INPUT_LEN:
        data.setLen(MAX_INPUT_LEN)
    else: # delete
      let
        i = r.rand(0 ..< data.len)
      data.delete(i)

  proc replayFile(path: string) =
    if not fileExists(path):
      quit("replay: file not found: " & path)

    let
      data = cast[seq[byte]](readFile(path))
      report = runFuzzDiff(data)

    echo fmtReport(report, path.extractFilename())

  proc main =
    try:
      # A file argument is a replay target: diff one saved crash/seed through the
      # native engine and the serve process. `fuzz <file>` is the targeted
      # counterpart to the generative loop below.
      if paramCount() >= 1 and fileExists(paramStr(1)):
        replayFile(paramStr(1))
        return

      ensureDirs()

      var
        corpus = loadSeeds()
      if corpus.len == 0:
        var
          r0 = initRand()
        corpus.add(genRandom(r0))

      var
        r = initRand(int32(epochTime()))
        iters = int32(0)
        crashCount = int32(0)
        divergenceCount = int32(0)

      echo "fuzzing: seeds=", corpus.len

      while true:
        inc iters

        var
          input: seq[byte]
          hasCrash = false
          hasDivergence = false

        if r.rand(1.0) < 0.85 and corpus.len > 0:
          input = corpus[r.rand(0 ..< corpus.len)]
          mutate(r, input)
        else:
          input = genRandom(r)

        try:
          let
            report = runFuzzDiff(input)

          if report.code != NoError:
            hasDivergence = true
            inc divergenceCount, 1

        except Exception as e:
          echo e.msg
          hasCrash = true

          inc crashCount, 1

        if hasCrash or hasDivergence:
          if hasCrash:
            saveBinary(input, iters, "crash")
          else:
            saveBinary(input, iters, "divergence")

          if corpus.len < CORPUS_CAP:
            corpus.add(input)

        elif corpus.len < CORPUS_CAP and r.rand(1.0) < 0.02:
          corpus.add(input)

        if iters mod 500 == 0:
          echo "iters=", iters, " crashCount=", crashCount, " divergenceCount=",
              divergenceCount, " corpus=", corpus.len

      echo "DONE iters=", iters, " crashCount=", crashCount,
          " divergenceCount=", divergenceCount

    except Exception as e:
      echo "Error: ", e.msg

      quit(1)

  main()
