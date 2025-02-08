import vmath
import std/typetraits

import ./buju/core

export vmath

export LayoutNodeID, isNil, `$`
export
  LayoutBoxWrap, LayoutBoxStart, LayoutBoxEnd, LayoutBoxJustify, LayoutBoxRow,
  LayoutBoxColumn, LayoutLeft, LayoutTop, LayoutRight, LayoutBottom,
  LayoutHorizontalFill, LayoutVerticalFill, LayoutFill

type Layout* = distinct LayoutObj ## Layout context object.

template getAddr(body): auto =
  when NimMajor > 1: body.addr else: body.unsafeAddr

proc len*(l: Layout): int {.inline, raises: [].} =
  ## Returns the length of `nodes`.

  distinctBase(l).nodes.len

proc clear*(l: var Layout) {.inline, raises: [].} =
  ## Clears all of the nodes in a `Layout`. Use this when
  ## you want to re-declare your layout starting from the root node. This does not
  ## free any memory or perform allocations. It's safe to use the `Layout` again
  ## after calling this.

  distinctBase(l).nodes.setLen(0)

proc firstChild*(l: Layout, nodeID: LayoutNodeID): LayoutNodeID {.inline, raises: [].} =
  ## Get the id of first child of an node, if any. Returns `LayoutNodeID.NIL` if there
  ## is no child.

  let
    l = distinctBase(l).getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.firstChild
  return NIL

proc lastChild*(l: Layout, nodeID: LayoutNodeID): LayoutNodeID {.inline, raises: [].} =
  ## Get the id of last child of an node, if any. Returns `LayoutNodeID.NIL` if there
  ## is no child.

  let
    l = distinctBase(l).getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.lastChild
  return NIL

proc nextSibling*(
    l: Layout, nodeID: LayoutNodeID
): LayoutNodeID {.inline, raises: [].} =
  ## Get the id of the next sibling of an node, if any. Returns `LayoutNodeID.NIL` if
  ## there is no next sibling.

  let
    l = distinctBase(l).getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.nextSibling
  return NIL

iterator children*(
    l: Layout, nodeID: LayoutNodeID
): LayoutNodeID {.inline, raises: [].} =
  ## Iterates over all direct children of an node.

  let l = distinctBase(l).getAddr

  if not nodeID.isNil:
    var
      n = l.node(nodeID)
      id = n.firstChild

    while not id.isNil:
      n = l.node(id)
      yield id

      id = n.nextSibling

proc node*(l: var Layout): LayoutNodeID {.inline, raises: [].} =
  ## Create a new node, which can just be thought of as a rectangle. Returns the
  ## id used to identify the node.

  let
    l = distinctBase(l).getAddr
    len = l.nodes.len

  l.nodes.setLen(len + 1)

  let id = cast[LayoutNodeID](l.nodes.len)

  when defined(js):
    l.nodes[len].id = id

  id

proc setBoxFlags*(
    l: var Layout, nodeID: LayoutNodeID, boxFlags: int
) {.inline, raises: [].} =
  ## Set the flags on an node which determines how it behaves as a parent.
  ## For example, setting `LayoutBoxColumn` will make an node behave as if it were a column,
  ## it will layout its children vertically.

  let
    l = distinctBase(l).getAddr
    n = l.node(nodeID)

  n.boxFlags = uint8(boxFlags)

proc setLayoutFlags*(
    l: var Layout, nodeID: LayoutNodeID, layoutFlags: int
) {.inline, raises: [].} =
  ## Set the flags on an node which determines how it behaves as a child inside of
  ## a parent node. For example, setting `LayoutVerticalFill` will make an node try to fill
  ## up all available vertical space inside of its parent.

  let
    l = distinctBase(l).getAddr
    n = l.node(nodeID)

  n.anchorFlags = uint8(layoutFlags)

proc setSize*(l: var Layout, nodeID: LayoutNodeID, size: Vec2) {.inline, raises: [].} =
  ## Sets the size of an node. 
  ## The components of the vector are:
  ## 0: width, 1: height.

  let
    l = distinctBase(l).getAddr
    n = l.node(nodeID)

  n.size = size

proc setMargin*(
    l: var Layout, nodeID: LayoutNodeID, margin: Vec4
) {.inline, raises: [].} =
  ## Set the margins on an node. 
  ## The components of the vector are:
  ## 0: left, 1: top, 2: right, 3: bottom.

  let
    l = distinctBase(l).getAddr
    n = l.node(nodeID)

  n.margin = margin

proc insertChild*(
    l: var Layout, parentID, childID: LayoutNodeID
) {.inline, raises: [].} =
  ## Inserts an node into another node, forming a parent - child relationship. An
  ## node can contain any number of child nodes. Items inserted into a parent are
  ## put at the end of the ordering, after any existing siblings.

  let
    l = distinctBase(l).getAddr
    p = l.node(parentID)

  if not p.lastChild.isNil:
    let lastChild = l.lastChild(p)
    lastChild.nextSibling = childID

    let node = l.node(childID)
    node.prevSibling = p.lastChild
    p.lastChild = childID
  else:
    p.firstChild = childID
    p.lastChild = childID

proc removeChild*(
    l: var Layout, parentID, childID: LayoutNodeID
) {.inline, raises: [].} =
  ## Removing an node from another, will untie the parent-child relationship between them.

  let
    l = distinctBase(l).getAddr
    c = l.node(childID)
    p = l.node(parentID)

  let
    p2 = c.prevSibling
    n2 = c.nextSibling

  if n2 == p2:
    if not n2.isNil:
      c.prevSibling = NIL
      c.nextSibling = NIL

      let n = l.node(n2)
      n.prevSibling = NIL
      n.nextSibling = NIL

    p.lastChild = NIL
    p.firstChild = NIL
    return

  if p.firstChild == childID:
    p.firstChild = n2

  if p.lastChild == childID:
    p.lastChild = p2

  if not n2.isNil:
    let n = l.node(n2)
    n.prevSibling = p2
    c.nextSibling = NIL

  if not p2.isNil:
    let n = l.node(p2)
    n.nextSibling = n2
    c.prevSibling = NIL

proc compute*(l: var Layout, nodeID: LayoutNodeID) {.inline, raises: [].} =
  ## Running the layout calculations from a specific node is useful if you want
  ## need to iteratively re-run parts of your layout hierarchy, or if you are only
  ## interested in updating certain subsets of it. Be careful when using this,
  ## it's easy to generated bad output if the parent nodes haven't yet had their
  ## output rectangles calculated, or if they've been invalidated (e.g. due to
  ## re-allocation).
  ##
  ## After calling this, you can use `computed` to query for an node's calculated
  ## rectangle. If you use procedures such as `insertChild` or `removeChild` after
  ## calling this, your calculated data may become invalid if a reallocation
  ## occurs.
  ##
  ## You should prefer to recreate your nodes starting from the root instead of
  ## doing fine-grained updates to the existing `Layout`.
  ##
  ## However, it's safe to use `setSize` on an node, and then re-run
  ## `compute`. This might be useful if you are doing a resizing animation
  ## on nodes in a layout without any contents changing.

  let
    l = distinctBase(l).getAddr
    n = l.node(nodeID)

  l.compute(n)

proc computed*(l: Layout, nodeID: LayoutNodeID): Vec4 {.inline, raises: [].} =
  ## Returns the calculated rectangle of an node. This is only valid after calling
  ## `compute` and before any other reallocation occurs. Otherwise, the
  ## result will be undefined. 
  ## The components of the vector are:
  ## 0: x starting position, 1: y starting position, 2: width, 3: height.

  let
    l = distinctBase(l).getAddr
    n = l.node(nodeID)

  n.computed
