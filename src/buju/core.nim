import std/strformat

type
  NodeID* {.size: 4.} = enum
    ## Node identifier (avoids using pointers/references for safety and simplicity).

    NIL

  NodeCache = object
    ## Cache for breadth-first traversal results (optimizes child node access).

    node: ptr Node
    childOffset: uint32 ## Starting index of the node's children in the cache.
    childCount: uint32  ## Count of direct children of the cached node.

  Align* = enum
    ## Absolute directional alignment for a single node (axis-agnostic, supports combination).
    ## Purpose: Aligns node by fixed directions (left/top/right/bottom) within parent container, independent of main/cross axis.

    AlignLeft = 0x01
    AlignTop = 0x02
    AlignRight = 0x04
    AlignBottom = 0x08

  AxisAlign = enum
    ## Axis-dependent alignment.

    AxisAlignMiddle = 0x00
    AxisAlignStart = 0x01
    AxisAlignEnd = 0x04
    AxisAlignStretch = 0x05

  MainAxisAlign* = enum
    ## Corresponding to Flex layout's `justify-content`.
    ## Controls the alignment of all nodes on the main axis.

    MainAxisAlignMiddle = AxisAlignMiddle
    MainAxisAlignStart = AxisAlignStart
    MainAxisAlignEnd = AxisAlignEnd
    MainAxisAlignSpaceBetween = 0x08
    MainAxisAlignSpaceAround = 0x10
    MainAxisAlignSpaceEvenly = 0x18

  CrossAxisAlign* = enum
    ## Corresponding to Flex layout's `align-items`.
    ## Controls the alignment of all nodes on the cross axis.

    CrossAxisAlignMiddle = AxisAlignMiddle
    CrossAxisAlignStart = AxisAlignStart
    CrossAxisAlignEnd = AxisAlignEnd
    CrossAxisAlignStretch = AxisAlignStretch

  CrossAxisLineAlign* = enum
    ## Corresponding to Flex layout's `align-content`.
    ## Controls alignment and spacing of multiple flex lines along the cross axis (only effective in multi-line layouts).

    CrossAxisLineAlignMiddle = AxisAlignMiddle
    CrossAxisLineAlignStart = AxisAlignStart
    CrossAxisLineAlignEnd = AxisAlignEnd
    CrossAxisLineAlignStretch = AxisAlignStretch
    CrossAxisLineAlignSpaceBetween = 0x08
    CrossAxisLineAlignSpaceAround = 0x10
    CrossAxisLineAlignSpaceEvenly = 0x18

  Layout* = enum
    ## Layout mode (controls child node arrangement direction).

    LayoutFree = 0x00
    LayoutRow = 0x01
    LayoutColumn = 0x02

  Wrap* = enum
    ## Child node wrapping behavior (only effective in Flex layout).

    WrapNoWrap = 0x00
    WrapWrap = 0x01

  Node* = object
    ## Layout node (conceptually a 2D rectangle with layout properties and hierarchy).

    id*: NodeID

    isBreak: bool            ## Whether an node's children have already been wrapped.
    isDelay: bool
      ## Whether to delay axis calculation (for wrapped layouts).
      ## When wrapping is enabled, main axis calculation depends on cross axis results (e.g., vertical layout needs y-axis first to calculate x-axis wrapping).

    wrap*: Wrap
    layout*: Layout
    mainAxisAlign*: MainAxisAlign
    crossAxisAlign*: CrossAxisAlign
    crossAxisLineAlign*: CrossAxisLineAlign
    align*: set[Align]

    firstChild*: NodeID
    lastChild*: NodeID
    prevSibling*: NodeID
    nextSibling*: NodeID

    size*: array[2, float32] ## Explicit node size (order: width -> height).
    gap*: array[2, float32] ## Node grid gap (order: column gap -> row gap).
    margin*: array[4, float32] ## Node margin (order: left -> top -> right -> bottom).

    computed*: array[4, float32]
      ## Computed absolute rectangle.
      ## Array components (order: x -> y -> width -> height):
      ## - Index 0: Absolute X position (relative to root node, top-left corner).
      ## - Index 1: Absolute Y position (relative to root node, top-left corner).
      ## - Index 2: Computed width.
      ## - Index 3: Computed height.

  Context* = object
    nodes*: seq[Node]
    caches: seq[NodeCache] ## Cache for breadth-first traversal results (speeds up child node indexing).

proc `$`*(id: NodeID): string =
  if id != NIL:
    return fmt"NODE{int(id)}"
  return "NIL"

proc isNil*(id: NodeID): bool {.inline.} =
  id == NIL

proc node*(l: ptr Context, id: NodeID): ptr Node =
  let idx = int32(id) - 1
  if idx >= 0 and idx < len(l.nodes):
    return l.nodes[idx].addr

iterator children*(l: ptr Context, n: ptr Node): ptr Node =
  var n = l.node(n.firstChild)
  while not n.isNil:
    yield n
    n = l.node(n.nextSibling)

proc calcStackedSize(l: ptr Context, c: ptr NodeCache, dim: int32): float32 =
  let wDim = dim + 2

  var needSize = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = needSize + size
  needSize

proc calcOverlayedSize(l: ptr Context, c: ptr NodeCache, dim: int32): float32 =
  let wDim = dim + 2

  var needSize = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(size, needSize)
  needSize

proc calcWrappedOverlayedSize(l: ptr Context, c: ptr NodeCache,
    dim: int32): float32 =
  let wDim = dim + 2

  var needSize = 0f
  var needSize2 = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    if child.isBreak:
      needSize2 = needSize2 + needSize
      needSize = 0
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(needSize, size)
  needSize + needSize2

proc calcWrappedStackedSize(l: ptr Context, c: ptr NodeCache,
    dim: int32): float32 =
  let wDim = dim + 2

  var needSize = 0f
  var needSize2 = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    if child.isBreak:
      needSize2 = max(needSize2, needSize)
      needSize = 0
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = needSize + size
  max(needSize2, needSize)

template combine(layout: Layout, wrap: Wrap): uint32 =
  uint32(ord(layout) + (ord(wrap) shl 8))

template isSameAxis(layout: Layout, dim: int32): bool =
  ord(layout) == (dim + 1)

template toAxisAlign(align: set[Align], dim: int32): AxisAlign =
  var bits = uint32(0)
  for a in [AlignLeft, AlignTop, AlignRight, AlignBottom]:
    if a in align:
      bits = bits or uint32(a)

  cast[AxisAlign]((bits shr dim) and ord(AxisAlignStretch))

template toAxisAlign(layout: Layout, crossAxisAlign: CrossAxisAlign,
    dim: int32): AxisAlign =
  if isSameAxis(layout, dim):
    AxisAlignMiddle
  else:
    cast[AxisAlign](crossAxisAlign)

    # case crossAxisAlign
    # of CrossAxisAlignMiddle: AxisAlignMiddle
    # of CrossAxisAlignStart: AxisAlignStart
    # of CrossAxisAlignEnd: AxisAlignEnd
    # of CrossAxisAlignStretch: AxisAlignStretch

proc calcSize(l: ptr Context, dim: int32) =
  let wDim = dim + 2

  # Note that we are doing a reverse-order loop here,
  # so the child nodes are always calculated before the parent nodes.
  var idx = l.caches.len
  while idx > 0:
    dec idx, 1

    let c = l.caches[idx].addr
    let n = c.node

    # Set the mutable rect output data to the starting input data.
    n.computed[dim] = n.margin[dim]

    # If we have an explicit input size, just set our output size (which other
    # calcXxxSize and arrange procedures will use) to it.
    if n.size[dim] > 0:
      n.computed[wDim] = n.size[dim]
      continue

    let needSize =
      case combine(n.layout, n.wrap)
      of combine(LayoutColumn, WrapWrap):
        if dim > 0:
          l.calcStackedSize(c, dim)
        else:
          l.calcOverlayedSize(c, dim)
      of combine(LayoutRow, WrapWrap):
        if dim > 0:
          l.calcWrappedOverlayedSize(c, dim)
        else:
          l.calcWrappedStackedSize(c, dim)
      of combine(LayoutRow, WrapNoWrap), combine(LayoutColumn, WrapNoWrap):
        if isSameAxis(n.layout, dim):
          l.calcStackedSize(c, dim)
        else:
          l.calcOverlayedSize(c, dim)
      else:
        # free layout model
        l.calcOverlayedSize(c, dim)

    # Set our output data size. Will be used by parent calcXxxSize procedures,
    # and by arrange procedures.
    n.computed[wDim] = needSize

proc arrangeStacked(l: ptr Context, c: ptr NodeCache, dim: int32, wrap: bool) =
  ## Calculate line wrapping, stretching, and gap filling of all child nodes of the node on the main axis.

  let wDim = dim + 2

  let n = c.node

  let computed = n.computed
  let space = computed[wDim]
  let gap = n.gap[dim]

  var arrangeRangeBegin = c.childOffset
  let arrangeRangeEnd = c.childOffset + c.childCount

  let maxX2 = computed[dim] + space

  while arrangeRangeBegin != arrangeRangeEnd:
    var used = 0f

    # count of fillers
    var count = 0

    var total = 0
    var nodeCount = 0

    var expandRangeEnd = arrangeRangeEnd

    # first pass: count nodes that need to be expanded, and the space that is used.
    for idx in arrangeRangeBegin ..< arrangeRangeEnd:
      let child = l.caches[idx].node

      inc nodeCount, 1
      var extend = used + child.computed[dim] + child.margin[wDim] +
          child.computed[wDim]

      if idx != arrangeRangeBegin:
        extend = extend + gap

      if toAxisAlign(child.align, dim) == AxisAlignStretch:
        inc count

      if wrap:
        # wrap on end of line
        if total > 0 and extend > space:
          expandRangeEnd = idx

          # add marker for subsequent queries
          child.isBreak = true
          nodeCount = 0
          break

      inc total, 1
      used = extend

    let extraSpace = space - used
    var filler = 0f
    var spacer = 0f
    var extraMargin = 0f

    if extraSpace > 0:
      if count > 0:
        filler = extraSpace / float32(count)
      elif total > 0:
        case n.mainAxisAlign
        of MainAxisAlignSpaceBetween:
          if not wrap or nodeCount > 0 or expandRangeEnd != arrangeRangeEnd:
            spacer = extraSpace / float32(total - 1)
        of MainAxisAlignSpaceAround:
          if not wrap or nodeCount > 0 or expandRangeEnd != arrangeRangeEnd:
            spacer = extraSpace / float32(total)
            extraMargin = spacer / 2
        of MainAxisAlignSpaceEvenly:
          if not wrap or nodeCount > 0 or expandRangeEnd != arrangeRangeEnd:
            spacer = extraSpace / float32(total + 1)
            extraMargin = spacer
        of MainAxisAlignStart:
          discard
        of MainAxisAlignEnd:
          extraMargin = extraSpace
        of MainAxisAlignMiddle:
          extraMargin = extraSpace / 2
    else:
      if not wrap:
        if total > 0:
          case n.mainAxisAlign
          of MainAxisAlignSpaceBetween, MainAxisAlignSpaceAround,
              MainAxisAlignSpaceEvenly, MainAxisAlignStart:
            discard
          of MainAxisAlignEnd:
            extraMargin = extraSpace
          of MainAxisAlignMiddle:
            extraMargin = extraSpace / 2

        # distribute width among nodes
    var x = computed[dim]
    var x1 = 0f

    # second pass: distribute and rescale
    for idx in arrangeRangeBegin ..< expandRangeEnd:
      let child = l.caches[idx].node

      x = x + child.computed[dim] + extraMargin
      if idx != arrangeRangeBegin:
        x = x + gap

      if toAxisAlign(child.align, dim) == AxisAlignStretch:
        # grow
        x1 = x + child.computed[wDim] + filler
      else:
        x1 = x + child.computed[wDim]

      let ix0 = x
      let ix1 =
        if wrap:
          min(maxX2 - child.margin[wDim], x1)
        else:
          x1

      child.computed[dim] = ix0 # pos
      child.computed[wDim] = ix1 - ix0 # size

      extraMargin = spacer
      x = x1 + child.margin[wDim]

    arrangeRangeBegin = expandRangeEnd

proc arrangeOverlay(l: ptr Context, c: ptr NodeCache, dim: int32) =
  let wDim = dim + 2

  let n = c.node
  let offset = n.computed[dim]
  let space = n.computed[wDim]

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node

    case toAxisAlign(child.align, dim)
    of AxisAlignStretch:
      child.computed[wDim] = max(0f, space - child.computed[dim] - child.margin[wDim])
    of AxisAlignEnd:
      child.computed[dim] =
        child.computed[dim] + space - child.computed[wDim] - child.margin[dim] -
        child.margin[wDim]
    of AxisAlignStart:
      discard
    of AxisAlignMiddle:
      child.computed[dim] =
        child.computed[dim] +
        max(0f, (space - child.computed[wDim] - child.margin[dim] -
            child.margin[wDim]) / 2)

    child.computed[dim] = child.computed[dim] + offset

proc arrangeOverlaySqueezedRange(l: ptr Context, dim: int32,
    inheritedAxisAlign: AxisAlign, squeezedRangeBegin, arrangeRangeEnd: uint32,
    offset, space: float32) =
  let wDim = dim + 2

  for idx in squeezedRangeBegin ..< arrangeRangeEnd:
    let child = l.caches[idx].node
    let minSize = max(0f, space - child.computed[dim] - child.margin[wDim])
    let align = if len(child.align) != 0:
        toAxisAlign(child.align, dim)
      else:
        inheritedAxisAlign

    case align
    of AxisAlignStretch:
      child.computed[wDim] = minSize
    of AxisAlignStart:
      child.computed[wDim] = min(child.computed[wDim], minSize)
    of AxisAlignEnd:
      child.computed[wDim] = min(child.computed[wDim], minSize)
      child.computed[dim] = space - child.computed[wDim] - child.margin[wDim]
    of AxisAlignMiddle:
      child.computed[wDim] = min(child.computed[wDim], minSize)
      child.computed[dim] =
        child.computed[dim] +
        max(0f, (space - child.computed[wDim] - child.margin[dim] -
            child.margin[wDim]) / 2)

    child.computed[dim] = child.computed[dim] + offset

proc arrangeWrappedOverlaySqueezed(l: ptr Context, c: ptr NodeCache,
    dim: int32) =
  ## Calculate stretching and gap filling of all child nodes of the node on the cross axis.

  let wDim = dim + 2

  let n = c.node
  let space = n.computed[wDim]
  let gap = n.gap[dim]
  let inheritedAxisAlign = toAxisAlign(n.layout, n.crossAxisAlign, dim)

  var offset = n.computed[dim]
  var needSize = 0f

  var squeezedRangeBegin = c.childOffset

  var lineCount = 1
  var extraSpace = 0f
  var extraMargin = 0f
  var spacer = 0f
  var filler = 0f

  block:
    var used = 0f

    for idx in c.childOffset ..< c.childOffset + c.childCount:
      let child = l.caches[idx].node
      if child.isBreak:
        inc lineCount, 1
        used = used + needSize
        needSize = 0

      let childSize = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
      needSize = max(needSize, childSize)
    used = used + needSize

    if lineCount > 1:
      spacer = gap
      used = used + float32(lineCount - 1) * gap

    extraSpace = space - used
    needSize = 0

  case n.crossAxisLineAlign
  of CrossAxisLineAlignMiddle:
    extraMargin = extraSpace / 2
  of CrossAxisLineAlignStart:
    discard
  of CrossAxisLineAlignEnd:
    extraMargin = extraSpace
  of CrossAxisLineAlignStretch:
    if extraSpace > 0:
      let space = extraSpace / float32(lineCount)
      spacer = spacer + space
      filler = space
  of CrossAxisLineAlignSpaceBetween:
    if extraSpace > 0 and lineCount > 1:
      let space = extraSpace / float32(lineCount - 1)
      spacer = spacer + space
  of CrossAxisLineAlignSpaceAround:
    if extraSpace > 0:
      let space = extraSpace / float32(lineCount)
      spacer = spacer + space
      extraMargin = space / 2
  of CrossAxisLineAlignSpaceEvenly:
    if extraSpace > 0:
      let space = extraSpace / float32(lineCount + 1)
      spacer = spacer + space
      extraMargin = space

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    if child.isBreak:
      offset = offset + extraMargin
      l.arrangeOverlaySqueezedRange(
        dim, inheritedAxisAlign, squeezedRangeBegin, idx, offset, needSize + filler
      )
      offset = offset + needSize
      extraMargin = spacer

      squeezedRangeBegin = idx
      needSize = 0

    let childSize = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(needSize, childSize)

  offset = offset + extraMargin
  l.arrangeOverlaySqueezedRange(
    dim,
    inheritedAxisAlign,
    squeezedRangeBegin,
    c.childOffset + c.childCount,
    offset,
    needSize + filler,
  )

proc arrange(l: ptr Context, c: ptr NodeCache, dim: int32) =
  let wDim = dim + 2

  let n = c.node

  case combine(n.layout, n.wrap)
  of combine(LayoutColumn, WrapWrap):
    if dim > 0:
      assert n.isDelay

      # When the main axis is vertical,
      # line wrapping affects the x-axis calculation results of all child nodes.
      # therefore, calculate the y-axis first.

      l.arrangeStacked(c, dim, true)
      l.arrangeWrappedOverlaySqueezed(c, 0)
  of combine(LayoutRow, WrapWrap):
    if dim > 0:
      assert n.isDelay

      # ditto

      l.arrangeStacked(c, 0, true)
      l.arrangeWrappedOverlaySqueezed(c, dim)
  of combine(LayoutRow, WrapNoWrap), combine(LayoutColumn, WrapNoWrap):
    if isSameAxis(n.layout, dim):
      l.arrangeStacked(c, dim, false)
    else:
      l.arrangeOverlaySqueezedRange(
        dim,
        cast[AxisAlign](ord(n.crossAxisAlign)),
        c.childOffset,
        c.childOffset + c.childCount,
        n.computed[dim],
        n.computed[wDim],
      )
  else:
    # free layout model
    l.arrangeOverlay(c, dim)

proc arrange(l: ptr Context, dim: int32) =
  for idx in 0 ..< l.caches.len:
    let c = l.caches[idx].addr
    let n = c.node

    if dim <= 0:
      if not n.isDelay:
        l.arrange(c, dim)
    else:
      l.arrange(c, dim)

      if n.isDelay:
        l.arrange(c, 0)

proc compute*(l: ptr Context, n: ptr Node) =
  ## Core layout calculation entry: Computes size and absolute position (computed field) for the target node and its subtree.
  ## Process: Breadth-first traversal -> cache nodes -> calculate base size (calcSize) -> arrange positions + stretch (arrange) -> clear cache.

  n.isDelay = false

  l.caches.add(NodeCache(node: n))

  var idx = 0

  # Step 1: Breadth-first traversal of the subtree, cache all nodes.
  # Purpose: 1. Ensure child nodes are calculated before parent nodes (reverse order later); 2. Allow direct subscript access to children via cache (childOffset/childCount).
  while idx < l.caches.len:
    let n = l.caches[idx].node
    let childOffset = uint32(l.caches.len)

    # Enable delay calculation if wrapping is enabled (needs to compute one axis first for line wrapping).
    if n.wrap == WrapWrap:
      n.isDelay = true

    n.isBreak = false

    var count = 0
    let isDelay = n.isDelay

    # Traverse all direct children of current node, add to cache.
    for child in l.children(n):
      inc count, 1

      child.isDelay = isDelay
      l.caches.add(NodeCache(node: child))

    # Update current node's cache info: Child nodes' position and count in cache.
    let c = l.caches[idx].addr
    c.childOffset = childOffset
    c.childCount = uint32(count)

    inc idx, 1

  template computeDim(dim) =
    # Step 2: Calculate base required size (no expansion) -> fills computed[2/3] (width/height).
    l.calcSize(dim)
    # Step 3: Arrange positions + handle space filling/stretching -> updates computed[0/1] (x/y) and adjusts size if needed.
    l.arrange(dim)

  # Calculate x-axis (dim=0) first, then y-axis (dim=1).
  # Order depends on layout mode: Wrapped layouts use `isDelay` to ensure correct dependency order.
  computeDim(0)
  computeDim(1)

  # Step 4: Clear traversal cache (cache is only used during compute).
  l.caches.setLen(0)
