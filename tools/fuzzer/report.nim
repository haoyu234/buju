import buju

import std/asyncdispatch
import std/os
import std/sequtils
import std/strutils

import ./action
import ./browserdiff
import ./diff
import ./webdriverops

proc footerLine(codeCounts: array[DiffResult, int32], total: int32): string =
  let
    passed = codeCounts[NoError]
    failed = total - passed
  if failed == 0:
    "  all " & $total & " clean"
  else:
    "  " & $passed & " passed, " & $failed & " failed"

const
  CRASH_OUT_DIR = "crash"

proc main =
  try:
    var
      files: seq[string]

    if paramCount() >= 1:
      let
        path = paramStr(1)
      if dirExists(path):
        files = toSeq(walkFiles(path / "*"))
      else:
        files.add(path)
    else:
      if not dirExists(CRASH_OUT_DIR):
        createDir(CRASH_OUT_DIR)

      files = toSeq(walkFiles(CRASH_OUT_DIR / "*"))

    var
      codeCounts: array[DiffResult, int32]

    let
      b = waitFor openBrowserAndPage()
      totalStr = $files.len
      width = totalStr.len

    try:
      for idx, item in files.pairs:
        let
          name = item.extractFilename()
          data = cast[seq[byte]](readFile(item))

          actions = data.actions().toSeq

        stderr.writeLine("[" & align($(idx + 1), width) & "/" & totalStr &
            "] " & name & " " & $actions.len & " actions")

        let
          report = doDiff(b, actions)

        inc codeCounts[report.code], 1

        if report.code != NoError:
          echo fmtReport(report, name)

      echo footerLine(codeCounts, int32(files.len))

    finally:
      waitFor b.close()

  except Exception as e:
    echo "Error: ", e.msg
    quit(1)

main()
