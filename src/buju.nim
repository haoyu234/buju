import vmath

import ./buju/core

export vmath

export LayoutNodeID, isNil
export LayoutBoxWrap, LayoutBoxStart, LayoutBoxEnd,
    LayoutBoxJustify, LayoutBoxRow, LayoutBoxColumn, LayoutLeft, LayoutTop,
    LayoutRight, LayoutBottom, LayoutHorizontalFill, LayoutVerticalFill, LayoutFill

type
  Layout* = distinct LayoutObj

proc len*(l: Layout): int {.inline.} =
  LayoutObj(l).nodes.len

proc clear*(l: var Layout) {.inline.} =
  LayoutObj(l).nodes.setLen(0)

proc firstChild*(l: Layout, id: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(id)
  if not node.isNil:
    result = node.firstChild

proc lastChild*(l: Layout, id: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(id)
  if not node.isNil:
    result = node.lastChild

proc nextSibling*(l: Layout, id: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(id)
  if not node.isNil:
    result = node.nextSibling

iterator children*(
  l: Layout, id: LayoutNodeID): LayoutNodeID {.inline.} =
  let l = LayoutObj(l).addr

  if not id.isNil:
    var node = l.node(id)
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

  let node = l.node(id)
  node.boxFlags = uint8(boxFlags)

proc setLayoutFlags*(
  l: var Layout, id: LayoutNodeID, layoutFlags: int) {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(id)
  node.layoutFlags = uint8(layoutFlags)

proc setSize*(
  l: var Layout, id: LayoutNodeID, size: Vec2) {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(id)
  node.size = size

proc setMargin*(
  l: var Layout, id: LayoutNodeID, margin: Vec4) {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(id)
  node.margin = margin

proc insertChild*(
  l: var Layout, parentId, childId: LayoutNodeID) {.inline.} =
  let l = LayoutObj(l).addr

  let parent = l.node(parentId)

  if not parent.lastChild.isNil:
    let lastChild = l.lastChild(parent)
    lastChild.nextSibling = childId

    let node = l.node(childId)
    node.prevSibling = parent.lastChild
    parent.lastChild = childId
  else:
    parent.firstChild = childId
    parent.lastChild = childId

proc removeChild*(l: var Layout, parentId, childId: LayoutNodeID) {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(childId)
  let parent = l.node(parentId)

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

  if parent.firstChild == childId:
    parent.firstChild = next

  if parent.lastChild == childId:
    parent.lastChild = prev

  if not next.isNil:
    let sibling = l.node(next)
    sibling.prevSibling = prev
    reset(node.nextSibling)

  if not prev.isNil:
    let sibling = l.node(prev)
    sibling.nextSibling = next
    reset(node.prevSibling)

proc compute*(l: var Layout, id: LayoutNodeID) {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(id)
  l.compute(node)

proc computed*(
  l: Layout, id: LayoutNodeID): Vec4 {.inline.} =
  let l = LayoutObj(l).addr

  let node = l.node(id)
  node.computed
