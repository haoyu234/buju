import ./buju/core

export Context, NodeID, isNil, `$`
export Align, MainAxisAlign, CrossAxisAlign, CrossAxisLineAlign, Layout, Wrap

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
  ## Note: Previously used `NodeID` values become invalid; recreate nodes if needed.

  l.nodes.setLen(0)

proc firstChild*(l: Context, nodeID: NodeID): NodeID {.inline, raises: [].} =
  ## Get the id of first child of a node, if any. Returns `NodeID.NIL` if there
  ## is no child.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.firstChild

proc lastChild*(l: Context, nodeID: NodeID): NodeID {.inline, raises: [].} =
  ## Get the id of last child of a node, if any. Returns `NodeID.NIL` if there
  ## is no child.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.lastChild

proc nextSibling*(l: Context, nodeID: NodeID): NodeID {.inline, raises: [].} =
  ## Get the id of the next sibling of a node, if any. Returns `NodeID.NIL` if
  ## there is no next sibling.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.nextSibling

iterator children*(l: Context, nodeID: NodeID): NodeID {.inline, raises: [].} =
  ## Iterates over all direct children of a node.

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

  let offset = int32(l.nodes.len)

  l.nodes.setLen(offset + 1)

  let id = cast[NodeID](l.nodes.len)
  when defined(js):
    l.nodes[offset].id = id

  id

proc setLayout*(l: var Context, nodeID: NodeID, layout: Layout) {.inline,
    raises: [].} =
  ## Sets the layout mode of a node.
  ## - `LayoutRow`: Flex layout with horizontal main axis.
  ## - `LayoutColumn`: Flex layout with vertical main axis.
  ## - `LayoutFree`: Free layout (no fixed arrangement rules).

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.layout = layout

proc setAlign*(l: var Context, nodeID: NodeID, align: set[Align]) {.inline,
    raises: [].} =
  ## Sets the node's own absolute directional alignment (axis-agnostic).
  ## Enumeration values are combinable via set syntax:
  ## - `{AlignTop}`: Top alignment in all layout modes.
  ## - `{AlignTop, AlignBottom}`: Vertical stretching (fills parent's vertical space).

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.align = align

proc setMainAxisAlign*(l: var Context, nodeID: NodeID,
    mainAxisAlign: MainAxisAlign) {.inline, raises: [].} =
  ## Sets the alignment of all child nodes along the node's main axis.
  ## Corresponding behavior to Flex layout's `justify-content`.
  ## Behavior depends on the node's layout mode:
  ## - `LayoutRow` (horizontal main axis): Controls horizontal alignment of children.
  ## - `LayoutColumn` (vertical main axis): Controls vertical alignment of children.
  ## - `LayoutFree`: Not effective.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.mainAxisAlign = mainAxisAlign

proc setCrossAxisAlign*(l: var Context, nodeID: NodeID,
    crossAxisAlign: CrossAxisAlign) {.inline, raises: [].} =
  ## Sets the alignment of all child nodes along the node's cross axis.
  ## Corresponding behavior to Flex layout's `align-items`.
  ## Behavior depends on the node's layout mode:
  ## - `LayoutRow` (vertical cross axis): Controls vertical alignment of children.
  ## - `LayoutColumn` (horizontal cross axis): Controls horizontal alignment of children.
  ## - `LayoutFree`: Not effective.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.crossAxisAlign = crossAxisAlign

proc setCrossAxisLineAlign*(l: var Context, nodeID: NodeID,
    crossAxisLineAlign: CrossAxisLineAlign) {.inline, raises: [].} =
  ## Sets the alignment and spacing of multiple flex lines along the cross axis.
  ## Corresponding behavior to Flex layout's `align-content`.
  ## Notes:
  ## - Only effective if `layout` is `LayoutRow`/`LayoutColumn` and `wrap` is `WrapWrap` (multi-line scenario).
  ## - Not effective in `LayoutFree` mode or single-line layouts.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.crossAxisLineAlign = crossAxisLineAlign

proc setWrap*(l: var Context, nodeID: NodeID, wrap: Wrap) {.inline, raises: [].} =
  ## Sets whether child nodes wrap when exceeding the node's main axis bounds.
  ## Options:
  ## - `WrapNoWrap`: No wrapping (children overflow if bounds are exceeded).
  ## - `WrapWrap`: Auto-wrapping (children split into multiple lines/columns).

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.wrap = wrap

proc setSize*(l: var Context, nodeID: NodeID, size: array[2, float32]) {.inline,
    raises: [].} =
  ## Sets the size of a node.
  ## Array components (order: width -> height):
  ## - Index 0: Width of the node.
  ## - Index 1: Height of the node.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.size = size

proc setGap*(l: var Context, nodeID: NodeID, gap: array[2, float32]) {.inline,
    raises: [].} =
  ## Sets the spacing between child nodes (gap).
  ## Array components (order: column gap -> row gap):
  ## - Index 0: Column gap (horizontal spacing between adjacent child nodes).
  ## - Index 1: Row gap (vertical spacing between adjacent child nodes).

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.gap = gap

proc setMargin*(l: var Context, nodeID: NodeID, margin: array[4,
    float32]) {.inline, raises: [].} =
  ## Sets the margin of a node (space around the node).
  ## Array components (order: left -> top -> right -> bottom):
  ## - Index 0: Left margin.
  ## - Index 1: Top margin.
  ## - Index 2: Right margin.
  ## - Index 3: Bottom margin.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.margin = margin

proc setPadding*(l: var Context, nodeID: NodeID, padding: array[4,
    float32]) {.inline, raises: [].} =
  ## Sets the padding of a node (space around the node).
  ## Array components (order: left -> top -> right -> bottom):
  ## - Index 0: Left padding.
  ## - Index 1: Top padding.
  ## - Index 2: Right padding.
  ## - Index 3: Bottom padding.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    n.padding = padding

proc insertChild*(l: var Context, parentID, childID: NodeID) {.inline, raises: [].} =
  ## Inserts a node into another node, forming a parent-child relationship. 
  ## A node can contain any number of child nodes. Items inserted into a parent are
  ## put at the end of the ordering, after any existing siblings.
  ## Note: If the child node already has a parent, call `removeChild` first to avoid conflicts.

  let
    l = l.getAddr
    p = l.node(parentID)
    c = l.node(childID)

  if not p.isNil and not c.isNil:
    when defined(debug):
      assert c.parent.isNil
    assert c.prevSibling.isNil
    assert c.nextSibling.isNil

    let lastChild = l.node(p.lastChild)
    if not lastChild.isNil:
      lastChild.nextSibling = childID

      c.prevSibling = p.lastChild
    else:
      p.firstChild = childID
    
    when defined(debug):
      c.parent = parentID
    p.lastChild = childID

proc removeChild*(l: var Context, parentID, childID: NodeID) {.inline, raises: [].} =
  ## Removes a child node from its parent, breaking the parent-child relationship.
  ## Note: Resets the child's `prevSibling` and `nextSibling` to `NodeID.NIL`.

  let
    l = l.getAddr
    p = l.node(parentID)
    c = l.node(childID)

  if not p.isNil and not c.isNil:
    when defined(debug):
      assert not c.parent.isNil
      assert c.parent == parentID

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

    when defined(debug):
      c.parent = NIL
    c.prevSibling = NIL
    c.nextSibling = NIL

proc compute*(l: var Context, nodeID: NodeID) {.inline, raises: [].} =
  ## Running the layout calculations from a specific node is useful if you want
  ## to iteratively re-run parts of your layout hierarchy, or if you are only
  ## interested in updating certain subsets of it. Be careful when using this,
  ## it's easy to generate bad output if the parent nodes haven't yet had their
  ## output rectangles calculated, or if they've been invalidated (e.g., due to
  ## re-allocation).
  ##
  ## After calling this, you can use `computed` to query for a node's calculated
  ## rectangle. If you use procedures such as `insertChild` or `removeChild` after
  ## calling this, your calculated data may become invalid if a reallocation
  ## occurs.
  ##
  ## You should prefer to recreate your nodes starting from the root instead of
  ## doing fine-grained updates to the existing `Context`.
  ##
  ## However, it's safe to use `setSize` on a node, and then re-run
  ## `compute`. This might be useful if you are doing a resizing animation
  ## on nodes in a layout without any contents changing.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    l.compute(n)

proc computed*(l: Context, nodeID: NodeID): array[4, float32] {.inline,
    raises: [].} =
  ## Returns the computed layout rectangle of a node (valid only after `compute`).
  ## Array components (order: x -> y -> width -> height):
  ## - Index 0: Absolute X starting position (relative to the root node's top-left corner).
  ## - Index 1: Absolute Y starting position (relative to the root node's top-left corner).
  ## - Index 2: Computed width.
  ## - Index 3: Computed height.

  let
    l = l.getAddr
    n = l.node(nodeID)

  if not n.isNil:
    return n.computed
