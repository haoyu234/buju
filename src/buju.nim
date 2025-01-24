import vmath
import std/typetraits

import ./buju/core

export vmath

export LayoutNodeID, isNil, `$`
export
  LayoutBoxWrap, LayoutBoxStart, LayoutBoxEnd, LayoutBoxJustify, LayoutBoxRow,
  LayoutBoxColumn, LayoutLeft, LayoutTop, LayoutRight, LayoutBottom,
  LayoutHorizontalFill, LayoutVerticalFill, LayoutFill

type
  Layout* = distinct LayoutObj ## Layout context objects. To avoid private method 
                               ## leaks, we use distinct type.

template getAddr(body): auto =
  when NimMajor > 1:
    body.addr
  else:
    body.unsafeAddr

proc len*(l: Layout): int {.inline.} =
  ## Returns the length of `nodes`.

  distinctBase(l).nodes.len

proc clear*(l: var Layout) {.inline.} =
  ## Clears all of the items in a `Layout`. Use this when
  ## you want to re-declare your layout starting from the root item. This does not
  ## free any memory or perform allocations. It's safe to use the `Layout` again
  ## after calling this.

  distinctBase(l).nodes.setLen(0)

proc firstChild*(l: Layout, item: LayoutNodeID): LayoutNodeID {.inline.} =
  ## Get the id of first child of an item, if any. Returns `LayoutNodeID.NIL` if there
  ## is no child.

  let l = distinctBase(l).getAddr

  let node = l.node(item)
  if not node.isNil:
    return node.firstChild
  return NIL

proc lastChild*(l: Layout, item: LayoutNodeID): LayoutNodeID {.inline.} =
  ## Get the id of last child of an item, if any. Returns `LayoutNodeID.NIL` if there
  ## is no child.

  let l = distinctBase(l).getAddr

  let node = l.node(item)
  if not node.isNil:
    return node.lastChild
  return NIL

proc nextSibling*(l: Layout, item: LayoutNodeID): LayoutNodeID {.inline.} =
  ## Get the id of the next sibling of an item, if any. Returns `LayoutNodeID.NIL` if
  ## there is no next sibling.

  let l = distinctBase(l).getAddr

  let node = l.node(item)
  if not node.isNil:
    return node.nextSibling
  return NIL

iterator children*(l: Layout, item: LayoutNodeID): LayoutNodeID {.inline.} =
  ## Iterates over all direct children of an item.

  let l = distinctBase(l).getAddr

  if not item.isNil:
    var node = l.node(item)
    var item = node.firstChild

    while not item.isNil:
      node = l.node(item)
      yield item

      item = node.nextSibling

proc node*(l: var Layout): LayoutNodeID {.inline.} =
  ## Create a new item, which can just be thought of as a rectangle. Returns the
  ## id used to identify the item.

  let l = distinctBase(l).getAddr

  let len = l.nodes.len
  let newLen = len +% 1

  l.nodes.setLen(newLen)

  when defined(js):
    l.nodes[len].id = cast[LayoutNodeID](newLen)

  cast[LayoutNodeID](newLen)

proc setBoxFlags*(l: var Layout, item: LayoutNodeID, boxFlags: int) {.inline.} =
  ## Set the flags on an item which determines how it behaves as a parent.
  ## For example, setting `LayoutBoxColumn` will make an item behave as if it were a column,
  ## it will layout its children vertically.

  let l = distinctBase(l).getAddr

  let node = l.node(item)
  node.boxFlags = uint8(boxFlags)

proc setLayoutFlags*(l: var Layout, item: LayoutNodeID,
    layoutFlags: int) {.inline.} =
  ## Set the flags on an item which determines how it behaves as a child inside of
  ## a parent item. For example, setting `LayoutVerticalFill` will make an item try to fill
  ## up all available vertical space inside of its parent.

  let l = distinctBase(l).getAddr

  let node = l.node(item)
  node.layoutFlags = uint8(layoutFlags)

proc setSize*(l: var Layout, item: LayoutNodeID, size: Vec2) {.inline.} =
  ## Sets the size of an item. The components of the vector are:
  ## 0: width, 1: height.

  let l = distinctBase(l).getAddr

  let node = l.node(item)
  node.size = size

proc setMargin*(l: var Layout, item: LayoutNodeID, margin: Vec4) {.inline.} =
  ## Set the margins on an item. The components of the vector are:
  ## 0: left, 1: top, 2: right, 3: bottom.

  let l = distinctBase(l).getAddr

  let node = l.node(item)
  node.margin = margin

proc insertChild*(l: var Layout, parentItem,
    childItem: LayoutNodeID) {.inline.} =
  ## Inserts an item into another item, forming a parent - child relationship. An
  ## item can contain any number of child items. Items inserted into a parent are
  ## put at the end of the ordering, after any existing siblings.

  let l = distinctBase(l).getAddr

  let parent = l.node(parentItem)

  if not parent.lastChild.isNil:
    let lastChild = l.lastChild(parent)
    lastChild.nextSibling = childItem

    let node = l.node(childItem)
    node.prevSibling = parent.lastChild
    parent.lastChild = childItem
  else:
    parent.firstChild = childItem
    parent.lastChild = childItem

proc removeChild*(l: var Layout, parentItem,
    childItem: LayoutNodeID) {.inline.} =
  ## Removing an item from another, will untie the parent-child relationship between them.

  let l = distinctBase(l).getAddr

  let node = l.node(childItem)
  let parent = l.node(parentItem)

  let
    prev = node.prevSibling
    next = node.nextSibling

  if next == prev:
    parent.lastChild = LayoutNodeID.NIL
    parent.firstChild = LayoutNodeID.NIL

    if not next.isNil:
      node.prevSibling = LayoutNodeID.NIL
      node.nextSibling = LayoutNodeID.NIL

      let sibling = l.node(next)
      sibling.prevSibling = LayoutNodeID.NIL
      sibling.nextSibling = LayoutNodeID.NIL
    return

  if parent.firstChild == childItem:
    parent.firstChild = next

  if parent.lastChild == childItem:
    parent.lastChild = prev

  if not next.isNil:
    let sibling = l.node(next)
    sibling.prevSibling = prev
    node.nextSibling = LayoutNodeID.NIL

  if not prev.isNil:
    let sibling = l.node(prev)
    sibling.nextSibling = next
    node.prevSibling = LayoutNodeID.NIL

proc compute*(l: var Layout, item: LayoutNodeID) {.inline.} =
  ## Running the layout calculations from a specific item is useful if you want
  ## need to iteratively re-run parts of your layout hierarchy, or if you are only
  ## interested in updating certain subsets of it. Be careful when using this,
  ## it's easy to generated bad output if the parent items haven't yet had their
  ## output rectangles calculated, or if they've been invalidated (e.g. due to
  ## re-allocation).
  ##
  ## After calling this, you can use `computed` to query for an item's calculated
  ## rectangle. If you use procedures such as `insertChild` or `removeChild` after
  ## calling this, your calculated data may become invalid if a reallocation
  ## occurs.
  ##
  ## You should prefer to recreate your items starting from the root instead of
  ## doing fine-grained updates to the existing `Layout`.
  ##
  ## However, it's safe to use `setSize` on an item, and then re-run
  ## `compute`. This might be useful if you are doing a resizing animation
  ## on items in a layout without any contents changing.

  let l = distinctBase(l).getAddr

  let node = l.node(item)
  l.compute(node)

proc computed*(l: Layout, item: LayoutNodeID): Vec4 {.inline.} =
  ## Returns the calculated rectangle of an item. This is only valid after calling
  ## `compute` and before any other reallocation occurs. Otherwise, the
  ## result will be undefined. The components of the vector are:
  ## 0: x starting position, 1: y starting position, 2: width, 3: height.

  let l = distinctBase(l).getAddr

  let node = l.node(item)
  node.computed
