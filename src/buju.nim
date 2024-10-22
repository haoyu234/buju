import vmath

import ./buju/core

export vmath

export LayoutNodeID, isNil
export LayoutBoxWrap, LayoutBoxStart, LayoutBoxMiddle, LayoutBoxEnd,
    LayoutBoxJustify, LayoutBoxRow, LayoutBoxColumn, LayoutLeft, LayoutTop,
    LayoutRight, LayoutBottom, LayoutHorizontalFill, LayoutVerticalFill, LayoutFill

type
  Layout* = distinct LayoutObj

proc len*(l: Layout): int {.inline.} =
  LayoutObj(l).nodes.len

proc clear*(l: var Layout) {.inline.} =
  LayoutObj(l).nodes.setLen(0)

proc firstChild*(l: Layout, n: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(n)
  if not node.isNil:
    result = node.firstChild

proc lastChild*(l: Layout, n: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(n)
  if not node.isNil:
    result = node.lastChild

proc nextSibling*(l: Layout, n: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(n)
  if not node.isNil:
    result = node.nextSibling

iterator children*(
  l: Layout, n: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  if not n.isNil:
    var node = l.node(n)
    var id = node.firstChild

    while not id.isNil:
      node = l.node(id)
      yield id

      id = node.nextSibling

proc node*(l: var Layout): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let len = l.nodes.len
  let newLen = len +% 1

  l.nodes.setLen(newLen)

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

  if not parent.lastChild.isNil:
    let lastChild = l.lastChild(parent)
    lastChild.nextSibling = c

    let node = l.node(c)
    node.prevSibling = parent.lastChild
    parent.lastChild = c
  else:
    parent.firstChild = c
    parent.lastChild = c

proc removeChild*(l: var Layout, p, n: LayoutNodeID) {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(n)
  let parent = l.node(p)

  let
    prev = node.prevSibling
    next = node.nextSibling

  if next == prev:
    reset(parent.lastChild)
    reset(parent.firstChild)

    if not next.isNil:
      reset(node.prevSibling)
      reset(node.nextSibling)

      let sibling = l.node(next)
      reset(sibling.prevSibling)
      reset(sibling.nextSibling)
    return

  if parent.firstChild == n:
    parent.firstChild = next

  if parent.lastChild == n:
    parent.lastChild = prev

  if not next.isNil:
    let sibling = l.node(next)
    sibling.prevSibling = prev
    reset(node.nextSibling)

  if not prev.isNil:
    let sibling = l.node(prev)
    sibling.nextSibling = next
    reset(node.prevSibling)

proc compute*(l: var Layout, n: LayoutNodeID) {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(n)
  l.compute(node)

proc computed*(
  l: Layout, id: LayoutNodeID): Vec4 {.inline.} =
  let l = LayoutObj(l).addr

  let child = l.node(id)
  child.computed
