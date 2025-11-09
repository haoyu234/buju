import std/typetraits

import ./buju/core

export Context, NodeID, isNil, `$`
export Align, MainAxisAlign, CrossAxisAlign, AxisAlign, Layout, Wrap

template getAddr(body): auto =
  when NimMajor > 1: body.addr else: body.unsafeAddr

proc len*(l: Context): int {.inline, raises: [].} =
  ## Returns the length of `nodes`.

  l.nodes.len

proc clear*(l: var Context) {.inline, raises: [].} =
  ## Clears all of the nodes in a `Context`. Use this when
  ## you want to re-declare your layout starting from the root node. This does not
  ## free any memory or perform allocations. It's safe to use the `Context` again
  ## after calling this.

  l.nodes.setLen(0)

proc firstChild*(l: Context, nodeID: NodeID): NodeID {.inline, raises: [].} =
  ## Get the id of first child of an node, if any. Returns `NodeID.NIL` if there
  ## is no child.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.firstChild

proc lastChild*(l: Context, nodeID: NodeID): NodeID {.inline, raises: [].} =
  ## Get the id of last child of an node, if any. Returns `NodeID.NIL` if there
  ## is no child.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.lastChild

proc nextSibling*(l: Context, nodeID: NodeID): NodeID {.inline, raises: [].} =
  ## Get the id of the next sibling of an node, if any. Returns `NodeID.NIL` if
  ## there is no next sibling.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.nextSibling

iterator children*(l: Context, nodeID: NodeID): NodeID {.inline, raises: [].} =
  ## Iterates over all direct children of an node.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    var id = n.firstChild
    while not id.isNil:
      yield id

      let n = l.node(id)
      id = n.nextSibling

proc node*(l: var Context): NodeID {.inline, raises: [].} =
  ## Create a new node, which can just be thought of as a rectangle. Returns the
  ## id used to identify the node.

  let offset = l.nodes.len

  l.nodes.setLen(offset + 1)

  let id = cast[NodeID](l.nodes.len)
  l.nodes[offset].id = id

  id

proc setLayout*(l: var Context, nodeID: NodeID, layout: Layout) {.inline,
    raises: [].} =
  ## Set layout mode.
  ## `LayoutRow`: flex layout, main axis is horizontal.
  ## `LayoutColumn`: flex layout, main axis is vertical.
  ## `LayoutFree`: free layout.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.layout = layout

proc setAlign*(l: var Context, nodeID: NodeID, align: set[Align]) {.inline,
    raises: [].} =
  ## Set the node's own alignment direction.
  ## For example, `AlignTop` behaves as top alignment in all layout modes.
  ## setting both `AlignTop` and `AlignBottom` results in vertical stretching.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.align = align

proc setMainAxisAlign*(l: var Context, nodeID: NodeID,
    mainAxisAlign: MainAxisAlign) {.inline, raises: [].} =
  ## Set alignment of all child nodes of the node along the main axis.
  ## For example, `AxisAlignStart` behaves as child nodes' left alignment when the main axis is `LayoutRow`,
  ## and as child nodes' top alignment when the main axis is `LayoutColumn`.
  ## Not take effect in `LayoutFree` mode.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.mainAxisAlign = mainAxisAlign

proc setCrossAxisAlign*(l: var Context, nodeID: NodeID,
    crossAxisAlign: CrossAxisAlign) {.inline, raises: [].} =
  ## Set alignment of all child nodes of the node along the cross axis.
  ## For example, `CrossAxisAlignStart` behaves as child nodes' top alignment when the main axis is `LayoutRow`,
  ## and as child nodes' left alignment when the main axis is `LayoutColumn`.
  ## When a child node has already set its own alignment, the parent node's crossAxisAlign setting will not take effect
  ## Not take effect in `LayoutFree` mode.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.crossAxisAlign = crossAxisAlign

proc setAxisAlign*(l: var Context, nodeID: NodeID,
    axisAlign: AxisAlign) {.inline, raises: [].} =
  ## Set the alignment between multiple main axes.
  ## When wrapping occurs, each line serves as a separate main axis.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.axisAlign = axisAlign

proc setWrap*(l: var Context, nodeID: NodeID, wrap: Wrap) {.inline, raises: [].} =
  ## Set whether the node allows child nodes to wrap.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.wrap = wrap

proc setSize*(l: var Context, nodeID: NodeID, size: array[2, float32]) {.inline,
    raises: [].} =
  ## Sets the size of an node.
  ## The components of the vector are:
  ## 0: width, 1: height.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.size = size

proc setMargin*(l: var Context, nodeID: NodeID, margin: array[4,
    float32]) {.inline, raises: [].} =
  ## Set the margins on an node.
  ## The components of the vector are:
  ## 0: left, 1: top, 2: right, 3: bottom.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.margin = margin

proc insertChild*(l: var Context, parentID, childID: NodeID) {.inline, raises: [].} =
  ## Inserts an node into another node, forming a parent - child relationship. 
  ## An node can contain any number of child nodes. Items inserted into a parent are
  ## put at the end of the ordering, after any existing siblings.

  let
    l = l.getAddr
    p = l.node(parentID)
    c = l.node(childID)

  if not p.isNil and not c.isNil:
    let lastChild = l.node(p.lastChild)
    if not lastChild.isNil:
      lastChild.nextSibling = childID

      c.prevSibling = p.lastChild
    else:
      p.firstChild = childID
    p.lastChild = childID

proc removeChild*(l: var Context, parentID, childID: NodeID) {.inline, raises: [].} =
  ## Removing an node from another, will untie the parent-child relationship between them.

  let
    l = l.getAddr
    p = l.node(parentID)
    c = l.node(childID)

  if not p.isNil and not c.isNil:
    if c.nextSibling == c.prevSibling:
      p.lastChild = NIL
      p.firstChild = NIL
    else:
      if p.lastChild == childID:
        p.lastChild = c.prevSibling

      if p.firstChild == childID:
        p.firstChild = c.nextSibling

      let nextSibling = l.node(c.nextSibling)
      if not nextSibling.isNil:
        nextSibling.prevSibling = c.prevSibling

      let prevSibling = l.node(c.prevSibling)
      if not prevSibling.isNil:
        prevSibling.nextSibling = c.nextSibling

    c.prevSibling = NIL
    c.nextSibling = NIL

proc compute*(l: var Context, nodeID: NodeID) {.inline, raises: [].} =
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
  ## doing fine-grained updates to the existing `Context`.
  ##
  ## However, it's safe to use `setSize` on an node, and then re-run
  ## `compute`. This might be useful if you are doing a resizing animation
  ## on nodes in a layout without any contents changing.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    l.compute(n)

proc computed*(l: Context, nodeID: NodeID): array[4, float32] {.inline,
    raises: [].} =
  ## Returns the calculated rectangle of an node. This is only valid after calling
  ## `compute` and before any other reallocation occurs. Otherwise, the
  ## result will be undefined.
  ## The components of the vector are:
  ## 0: x starting position, 1: y starting position, 2: width, 3: height.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.computed
