import buju

import std/sequtils

import ./action
import ./utils

when defined(linux):
  import std/posix

proc initialize(): cint {.exportc: "LLVMFuzzerInitialize".} =
  {.emit: "N_CDECL(void, NimMain)(void); NimMain();".}

proc fuzzBody(data: ptr UncheckedArray[byte], len: int): cint {.
    exportc: "LLVMFuzzerTestOneInput", raises: [].} =
  var
    ctx: Context
    hasError = false

  try:
    let
      actions = data.toOpenArray(0, len - 1).actions().toSeq

    for idx in 0 ..< actions.len:
      let
        param = actions[idx]

      doAction(ctx, param)

  except Exception as e:
    hasError = true
    echo getStackTrace(e)

  if hasError:
    dumpParams(ctx)

    when defined(linux):
      discard kill(getpid(), SIGSEGV)
