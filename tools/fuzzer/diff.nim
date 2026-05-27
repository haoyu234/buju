import buju

import std/strutils

import ./reader
import ./utils

type
  DiffError* = object of CatchableError

  DiffResult* = enum
    NoError
    LayoutError
    ShapeError
    VersionError

  DiffLayoutEntry* = object
    id*: NodeID
    buju*: array[4, float32]
    jsBuju*: array[4, float32]
    jsHtml*: array[4, float32]

  DiffReport* = object
    code*: DiffResult
    root*: NodeID
    actionIdx*: int32
    nodes*: seq[DiffLayoutEntry]

proc rectGap(a, b: array[4, float32]): float32 =
  for k in 0 .. 3:
    result = max(result, abs(a[k] - b[k]))

proc fmtEntry*(e: DiffLayoutEntry): string =
  let
    jsBujuGap = rectGap(e.buju, e.jsBuju)
    jsHtmlGap = rectGap(e.buju, e.jsHtml)
    detail = if jsBujuGap > 0.1: "jsBuju"
           elif jsHtmlGap > 0.1: "jsHtml"
           else: ""

  result = "id=" & $e.id &
           "  buju=" & fmtRect(e.buju) &
           "  jsBuju=" & fmtRect(e.jsBuju) &
           "  jsHtml=" & fmtRect(e.jsHtml) &
           "  jsBujuGap=" & formatFloat(jsBujuGap, ffDecimal, 2) &
           "  jsHtmlGap=" & formatFloat(jsHtmlGap, ffDecimal, 2)
  if detail.len > 0:
    result &= "  [DIVERGED: " & detail & "]"

proc statusWord(code: DiffResult): string =
  if code == NoError: "PASS" else: "FAIL"

proc fmtReport*(d: DiffReport, name: string): string =
  result = "  [" & statusWord(d.code) & "] " & name &
           "  code=" & $d.code & "  action=" & $d.actionIdx &
           "  root=" & $d.root
  if d.nodes.len > 0:
    result = result & "\n  nodes(" & $d.nodes.len & "):"
    for e in d.nodes:
      result &= "\n    " & fmtEntry(e)

proc doDiff*(actionIdx: int32, root: NodeID, result1,
    result2: openArray[byte]): DiffReport =
  result.root = root
  result.actionIdx = actionIdx

  var
    a = reader(result1)
    b = reader(result2)

  while not a.empty and not b.empty:
    let
      id1 = cast[NodeID](a.next(int32))
      id2 = cast[NodeID](b.next(int32))

    if id1 != id2:
      result.code = ShapeError
      return

    var
      item = default(DiffLayoutEntry)

    item.id = id1
    item.buju = a.takeRect()
    item.jsBuju = b.takeRect()
    item.jsHtml = b.takeRect()

    if not rectEqual(item.buju, item.jsBuju, 0.1):
      result.code = VersionError
      return

    if not rectEqual(item.buju, item.jsHtml, 0.1):
      result.nodes.add(item)

  if result.nodes.len > 0:
    result.code = LayoutError
    return

  if not a.empty or not b.empty:
    result.code = ShapeError
    return
