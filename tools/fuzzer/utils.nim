import buju
import buju/core

import std/strutils

import ./reader
import ./writer

proc takeRect*(r: var Reader): array[4, float32] =
  for idx in 0 ..< 4:
    result[idx] = r.next(float32)

proc writeRect*(w: var Writer, val: array[4, float32]) =
  for v in val:
    w.next(v)

proc fmtRect*(r: array[4, float32]): string =
  result.add("[")

  for k in 0 .. 3:
    if k > 0:
      result.add(", ")
    let
      f = r[k]
    if float32(int32(f)) == f:
      result.add($int32(f))
    else:
      result.add(formatFloat(f, ffDecimal, 2))

  result.add("]")

proc rectEqual*(a, b: array[4, float32], eps: float32 = 0.1): bool =
  result = true

  for k in 0 .. 3:
    if abs(a[k] - b[k]) > eps:
      result = false
      return

proc dumpResultBinary(l: Context, root: NodeID, writer: var Writer) =
  let
    computed = l.computed(root)

  writer.next(int32(root))
  writer.writeRect(computed)

  for child in l.children(root):
    dumpResultBinary(l, child, writer)

proc dumpResultBinary*(l: Context, root: NodeID): seq[byte] =
  if root.isNil:
    return

  var
    writer = Writer()
  dumpResultBinary(l, root, writer)
  writer.buffer

proc dumpDiffResultBinary*(d1: openArray[byte], d2: openArray[byte]) =
  var
    idx = int32(0)
    a = reader(d1)
    b = reader(d2)

  while not a.empty and not b.empty:
    inc idx, 1

    let
      id1 = cast[NodeID](a.next(int32, 0))
      id2 = cast[NodeID](b.next(int32, 0))

    assert id1 == id2

    let
      computed1 = a.takeRect()
      computed2 = b.takeRect()

    if not rectEqual(computed1, computed2, 0.1):
      echo "id: ", id1, " a: ", fmtRect(computed1), " b: ", fmtRect(computed2)
    else:
      echo "id: ", id1, " computed: ", fmtRect(computed1)
