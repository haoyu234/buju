import vmath

import ./buju/core

export vmath

export LayoutNodeID
export LayoutBoxWrap, LayoutBoxStart, LayoutBoxMiddle, LayoutBoxEnd,
    LayoutBoxJustify, LayoutBoxRow, LayoutBoxColumn, LayoutLeft, LayoutTop,
    LayoutRight, LayoutBottom, LayoutHorizontalFill, LayoutVerticalFill, LayoutFill

type
  Layout* = distinct LayoutObj

proc len*(l: var Layout): int {.inline.} =
  LayoutObj(l).nodes.len

proc clear*(l: var Layout) {.inline.} =
  LayoutObj(l).nodes.setLen(0)

proc compute*(l: var Layout) {.inline.} =
  let l = LayoutObj(l).addr

  let firstChild = l.node(ROOT)
  l.compute(firstChild)

proc compute*(l: var Layout, n: LayoutNodeID) {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(n)
  l.compute(node)

proc firstChild*(l: var Layout, n: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(n)
  if not node.isNil:
    result = node.firstChild

proc lastChild*(l: var Layout, n: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(n)
  if not node.isNil:
    result = node.lastChild

proc nextSibling*(l: var Layout, n: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(n)
  if not node.isNil:
    result = node.nextSibling

iterator children*(
  l: var Layout, n: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  if n != NIL:
    var node = l.node(n)
    var id = node.firstChild

    while id != NIL:
      node = l.node(id)
      yield id

      id = node.nextSibling

proc node*(l: var Layout): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let len = uint(l.nodes.len)
  let newLen = len + 1

  l.nodes.setLen(newLen)

  cast[LayoutNodeID](newLen)

proc node*(l: var Layout, label: string): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let len = uint(l.nodes.len)
  let newLen = len + 1

  l.nodes.setLen(newLen)
  l.nodes[len].label = label

  cast[LayoutNodeID](newLen)

proc setBoxFlags*(
  l: var Layout, id: LayoutNodeID, boxFlags: int) {.inline.} =
  let l = LayoutObj(l).addr

  let child = l.node(id)
  child.boxFlags = uint8(boxFlags)

proc setLayoutFlags*(
  l: var Layout, id: LayoutNodeID, layoutFlags: int) {.inline.} =
  let l = LayoutObj(l).addr

  let child = l.node(id)
  child.layoutFlags = uint8(layoutFlags)

proc setSize*(
  l: var Layout, id: LayoutNodeID, size: Vec2) {.inline.} =
  let l = LayoutObj(l).addr

  let child = l.node(id)
  child.size = size

proc setMargin*(
  l: var Layout, id: LayoutNodeID, margin: Vec4) {.inline.} =
  let l = LayoutObj(l).addr

  let child = l.node(id)
  child.margin = margin

proc insertChild*(
  l: var Layout, p, c: LayoutNodeID) {.inline.} =
  let l = LayoutObj(l).addr

  let parent = l.node(p)
  if parent.lastChild != NIL:
    let lastChild = l.lastChild(parent)
    lastChild.nextSibling = c
    parent.lastChild = c
  else:
    parent.firstChild = c
    parent.lastChild = c

proc insertAfter*(
  l: var Layout, n, n2: LayoutNodeID) {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(n)
  let node2 = l.node(n2)

  node2.nextSibling = node.nextSibling
  node.nextSibling = n2

proc computed*(
  l: var Layout, id: LayoutNodeID): Vec4 {.inline.} =
  let l = LayoutObj(l).addr

  let child = l.node(id)
  child.computed
