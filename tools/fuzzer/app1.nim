import buju
import buju/dumps

import std/sequtils

import ./action
import ./client
import ./utils

when defined(linux):
  import std/posix

type
  ProcessResult = enum
    Next
    Break
    Exit

echo "listen: ", 2026

var
  c = listen(2026)

proc initialize(): cint {.exportc: "LLVMFuzzerInitialize".} =
  {.emit: "N_CDECL(void, NimMain)(void); NimMain();".}

proc fuzzBody(data: openArray[byte]) =
  var
    ctx: Context
    hasError = false
    lastSuccessJson: string

  try:
    c.send(data)

    let
      actions = data.actions().toSeq

    for idx in 0 ..< actions.len:
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

      if param.action != COMPUTE:
        copied.compute(n)

      let
        result1 = dumpResultBinary(copied, n)
        result2 = c.next()

      if c.isClosed:
        break

      hasError = result1 != result2
      if not hasError:
        ctx = move copied
      else:
        dumpDiffResultBinary(result1, result2)

        let
          root = ctx.getRoot(n)
        lastSuccessJson = ctx.dumpJson(root)

      var
        processResult = Next
      if hasError:
        processResult = Exit
      elif idx == actions.len - 1:
        processResult = Break

      c.send([byte(processResult)])

      if processResult == Exit:
        break

  except Exception as e:
    hasError = true
    echo e.msg
    echo getStackTrace(e)

  if hasError:
    writeFile("buju.json", lastSuccessJson)

    when defined(linux):
      discard kill(getpid(), SIGSEGV)

proc fuzzBody(data: ptr UncheckedArray[byte], len: int): cint {.
    exportc: "LLVMFuzzerTestOneInput", raises: [].} =
  try:
    fuzzBody(data.toOpenArray(0, len - 1))
  except Exception:
    discard
