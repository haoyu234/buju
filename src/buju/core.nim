import std/strformat

type
  NodeID* {.size: 4.} = enum
    ## Unique node identifier used instead of raw pointers for safety and simplicity.

    NIL

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

  Dirty* = enum
    ## Marks for nodes to trigger layout updates.

    DirtyPos
    DirtySize
    DirtySibling
    DirtyContentPos
    DirtyContentSize
    DirtyRoot

  Node* = object
    ## Layout node (conceptually a 2D rectangle with layout properties and hierarchy).

    when defined(js) or defined(debug):
      id*: NodeID

    when defined(debug):
      parent*: NodeID

    firstChild*: NodeID
    lastChild*: NodeID
    prevSibling*: NodeID
    nextSibling*: NodeID

    dirty: set[Dirty]

    wrap*: Wrap
    layout*: Layout
    mainAxisAlign*: MainAxisAlign
    crossAxisAlign*: CrossAxisAlign
    crossAxisLineAlign*: CrossAxisLineAlign
    align*: set[Align]

    size*: array[2, float32] ## Explicit node size (order: width -> height).
    gap*: array[2, float32]  ## Node grid gap (order: column gap -> row gap).
    margin*: array[4, float32] ## Node margin (order: left -> top -> right -> bottom).
    padding*: array[4, float32] ## Node padding (order: left -> top -> right -> bottom).

    computed*: array[4, float32]
    computed2: array[4, float32]
      ## Temporary rectangle used during the layout pass.
      ## Index 0: X position (relative to parent’s content area).
      ## Index 1: Y position (relative to parent’s content area).
      ## Index 2: Computed width.
      ## Index 3: Computed height.

    when defined(bujuUserData):
      userData*: RootRef

  NodeCache = object
    ## Cache for breadth-first traversal results (optimizes child node access).

    node: ptr Node
    parentNodeCache: ptr NodeCache
    childOffset: int32 ## Starting index of the node's children in the cache.
    childCount: int32  ## Count of direct children of the cached node.

    isBreak: bool      ## Whether an node's children have already been wrapped.
    isDelay: bool      ## Whether to delay axis calculation (for wrapped layouts).
                    ## When wrapping is enabled, main axis calculation depends on cross axis results (e.g., vertical layout needs y-axis first to calculate x-axis wrapping).

    isPosDirty: bool
    isSizeDirty: bool
    isSiblingDirty: bool
    isContentPosDirty: bool
    isContentSizeDirty: bool
    isTreeDirty: bool

    isSizeChanged: array[2, bool]
    isContentSizeChanged: array[2, bool]

  Context* = object
    ## The global layout context holding all nodes and the traversal cache.

    nodes*: seq[Node] ## All nodes managed by this context.
    caches: seq[NodeCache] ## Breadth‑first traversal cache; built during `buildCache`,
                      ## used by `calcSize` and `arrange`, then cleared.

proc combine(layout: Layout, wrap: Wrap): uint32 {.inline.} =
  uint32(ord(layout) + (ord(wrap) shl 8))

proc isSameAxis(layout: Layout, dim: int32): bool {.inline.} =
  ord(layout) == (dim + 1)

proc toAxisAlign(align: set[Align], dim: int32): AxisAlign {.inline.} =
  ## Extract the alignment flags relevant to axis `dim` and convert to an `AxisAlign` value.

  var bits = uint32(0)
  for a in [AlignLeft, AlignTop, AlignRight, AlignBottom]:
    if a in align:
      bits = bits or uint32(a)

  cast[AxisAlign]((bits shr dim) and ord(AxisAlignStretch))

proc toAxisAlign(layout: Layout, crossAxisAlign: CrossAxisAlign,
    dim: int32): AxisAlign {.inline.} =
  ## Map the cross‑axis alignment to an `AxisAlign`, returning `Middle` when `dim` is the main axis.

  if isSameAxis(layout, dim):
    AxisAlignMiddle
  else:
    cast[AxisAlign](crossAxisAlign)

    # case crossAxisAlign
    # of CrossAxisAlignMiddle: AxisAlignMiddle
    # of CrossAxisAlignStart: AxisAlignStart
    # of CrossAxisAlignEnd: AxisAlignEnd
    # of CrossAxisAlignStretch: AxisAlignStretch

proc `$`*(id: NodeID): string =
  if id != NIL:
    return fmt"NODE{int32(id)}"
  return "NIL"

proc isNil*(id: NodeID): bool {.inline.} =
  id == NIL

proc node*(l: ptr Context, id: NodeID): ptr Node {.inline.} =
  let idx = int32(id) - 1
  if idx >= 0 and idx < len(l.nodes):
    return l.nodes[idx].addr

proc mark*(l: ptr Context, n: ptr Node, dirty: Dirty) {.inline.} =
  n.dirty.incl(dirty)

  when defined(debug) and defined(bujuDumpDirtyFlag):
    echo "mark ", n.id, " ", dirty

proc unmark*(l: ptr Context, n: ptr Node, dirty: Dirty) {.inline.} =
  n.dirty.excl(dirty)

proc isDirty*(l: ptr Context, n: ptr Node, dirty: Dirty): bool {.inline.} =
  n.dirty.contains(dirty)

proc updateResult(l: ptr Context, n: ptr Node, idx: int32, val: float32,
    name: string) {.inline.} =
  n.computed2[idx] = val

  when defined(debug) and defined(bujuDumpUpdateResult):
    echo name, " set ", n.id, ".computed2[", idx, "] to ", val

iterator children*(l: ptr Context, n: ptr Node): ptr Node =
  var n = l.node(n.firstChild)
  while not n.isNil:
    yield n
    n = l.node(n.nextSibling)

proc calcStackedSize(l: ptr Context, c: ptr NodeCache, dim: int32): float32 =
  let wDim = dim + 2

  var needSize = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    let size = child.margin[dim] + child.computed2[wDim] + child.margin[wDim]
    needSize = needSize + size

  result = needSize

proc calcOverlayedSize(l: ptr Context, c: ptr NodeCache, dim: int32): float32 =
  let wDim = dim + 2

  var needSize = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    let size = child.margin[dim] + child.computed2[wDim] + child.margin[wDim]
    needSize = max(size, needSize)

  result = needSize

proc calcWrappedOverlayedSize(l: ptr Context, c: ptr NodeCache,
    dim: int32): float32 =
  let wDim = dim + 2

  var needSize = 0f
  var needSize2 = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    if cc.isBreak:
      needSize2 = needSize2 + needSize
      needSize = 0

    let size = child.margin[dim] + child.computed2[wDim] + child.margin[wDim]
    needSize = max(needSize, size)

  result = needSize2 + needSize

proc calcWrappedStackedSize(l: ptr Context, c: ptr NodeCache,
    dim: int32): float32 =
  let wDim = dim + 2

  var needSize = 0f
  var needSize2 = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    if cc.isBreak:
      needSize2 = max(needSize2, needSize)
      needSize = 0

    let size = child.margin[dim] + child.computed2[wDim] + child.margin[wDim]
    needSize = needSize + size

  result = max(needSize2, needSize)

proc calcSize(l: ptr Context, c, pc: ptr NodeCache, dim: int32) =
  let wDim = dim + 2

  let
    n = c.node

  # Start with the margin offset.
  n.computed2[dim] = n.margin[dim]

  let
    padding = n.padding[dim] + n.padding[wDim]

  # If we have an explicit input size, just set our output size (which other
  # calcXxxSize and arrange procedures will use) to it.
  if n.size[dim] > 0:
    let
      w = max(n.size[dim], padding)

    if w != n.computed2[wDim]:
      l.updateResult(n, wDim, w, "calcSize")
      c.isSizeChanged[dim] = true
      pc.isContentSizeChanged[dim] = true
      return

    when defined(debug) and defined(bujuDumpSkip):
      echo "calcSize ", n.id, " dim: ", dim, " size unchanged"
    return

  # Compute required size based on layout mode and wrap behaviour.
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
  let
    w = needSize + padding
  if w != n.computed2[wDim]:
    l.updateResult(n, wDim, w, "calcSize2")
    c.isSizeChanged[dim] = true
    pc.isContentSizeChanged[dim] = true
    return

  when defined(debug) and defined(bujuDumpSkip):
    echo "calcSize2 ", n.id, " dim: ", dim, " size unchanged"
  return

proc calcSize(l: ptr Context, dim: int32) =
  ## First layout pass: compute the base size (width/height) for every node.
  ## Operates in reverse cache order so children are processed before parents.

  var idx = int32(l.caches.len)
  while idx > 0:
    dec idx, 1

    let
      c = l.caches[idx].addr
      n = c.node
      pc = c.parentNodeCache

    if c.isSizeDirty or pc.isSizeDirty or pc.isContentSizeDirty or
        c.isTreeDirty or (n.size[dim] <= 0 and c.isContentSizeDirty):
      l.calcSize(c, pc, dim)
    else:
      when defined(debug) and defined(bujuDumpSkip):
        let
          n = c.node
        echo "skip calcSize ", n.id, " dim: ", dim

  when defined(debug) and defined(bujuDumpDirtyFlag):
    for idx in 0 ..< l.caches.len:
      let
        c = l.caches[idx].addr
        n = c.node

      echo "n.id ", n.id, " isSizeChanged[", dim, "]: ", c.isSizeChanged[dim],
          " isContentSizeChanged[", dim, "]: ", c.isContentSizeChanged[dim]

proc arrangeStacked(l: ptr Context, c: ptr NodeCache, dim: int32, wrap: bool) =
  ## Calculate line wrapping, stretching, and gap filling of all child nodes of the node on the main axis.

  let wDim = dim + 2

  let n = c.node

  let offset = n.padding[dim]
  let space = n.computed2[wDim] - (n.padding[dim] + n.padding[wDim])

  var arrangeRangeBegin = c.childOffset
  let arrangeRangeEnd = c.childOffset + c.childCount

  while arrangeRangeBegin != arrangeRangeEnd:
    var used = 0f

    # count of fillers
    var count = int32(0)

    var total = int32(0)

    var expandRangeEnd = arrangeRangeEnd

    # first pass: count nodes that need to be expanded, and the space that is used.
    for idx in arrangeRangeBegin ..< arrangeRangeEnd:
      let
        cc = l.caches[idx].addr
        child = cc.node

      var extend = used + child.margin[dim] + child.margin[wDim] +
          child.computed2[wDim]

      if idx != arrangeRangeBegin:
        extend = extend + n.gap[dim]

      if wrap:
        # wrap on end of line
        if total > 0 and extend > space:
          expandRangeEnd = idx

          # Mark this node as the start of a new line.
          cc.isBreak = true
          break

      if toAxisAlign(child.align, dim) == AxisAlignStretch:
        inc count, 1

      inc total, 1
      used = extend

    let extraSpace = space - used
    var filler = 0f
    var spacer = 0f
    var extraMargin = 0f

    # Compute extra space distribution based on main‑axis alignment.
    if extraSpace > 0 and count > 0:
      filler = extraSpace / float32(count)
    else:
      case n.mainAxisAlign
      of MainAxisAlignStart:
        discard
      of MainAxisAlignMiddle:
        extraMargin = extraSpace / 2
      of MainAxisAlignEnd:
        extraMargin = extraSpace
      of MainAxisAlignSpaceBetween:
        if extraSpace > 0 and total > 1:
          spacer = extraSpace / float32(total - 1)
      of MainAxisAlignSpaceAround:
        if extraSpace > 0 and total > 0:
          spacer = extraSpace / float32(total)
          extraMargin = spacer / 2
      of MainAxisAlignSpaceEvenly:
        if extraSpace > 0:
          spacer = extraSpace / float32(total + 1)
          extraMargin = spacer

    var x = offset

    # Second pass: assign positions and stretched sizes.
    for idx in arrangeRangeBegin ..< expandRangeEnd:
      let
        cc = l.caches[idx].addr
        child = cc.node

      x = x + child.margin[dim] + extraMargin
      if idx != arrangeRangeBegin:
        x = x + n.gap[dim]

      var
        w = child.computed2[wDim]

      if toAxisAlign(child.align, dim) == AxisAlignStretch:
        # grow
        w = w + filler

      l.updateResult(child, dim, x, "arrangeStacked")
      l.updateResult(child, wDim, w, "arrangeStacked")

      x = x + w + child.margin[wDim]
      extraMargin = spacer

    arrangeRangeBegin = expandRangeEnd

proc arrangeOverlay(l: ptr Context, c: ptr NodeCache, dim: int32) =
  let wDim = dim + 2

  let n = c.node
  let offset = n.padding[dim]
  let space = n.computed2[wDim] - (n.padding[dim] + n.padding[wDim])

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    var
      x = child.margin[dim]
      w = child.computed2[wDim]

    case toAxisAlign(child.align, dim)
    of AxisAlignStretch:
      w = max(0f, space - child.margin[dim] -
          child.margin[wDim])
    of AxisAlignEnd:
      x = x + space - w - child.margin[dim] - child.margin[wDim]
    of AxisAlignStart:
      discard
    of AxisAlignMiddle:
      x = x + max(0f, (space - w - child.margin[dim] - child.margin[wDim]) / 2)

    l.updateResult(child, dim, x + offset, "arrangeOverlay")
    l.updateResult(child, wDim, w, "arrangeOverlay")

proc arrangeOverlaySqueezedRange(l: ptr Context, dim: int32,
    inheritedAxisAlign: AxisAlign, squeezedRangeBegin, arrangeRangeEnd: int32,
    offset, space: float32) =
  let wDim = dim + 2

  for idx in squeezedRangeBegin ..< arrangeRangeEnd:
    let
      c = l.caches[idx].addr
      child = c.node

      minSize = max(0f, space - child.margin[dim] - child.margin[wDim])

    var
      x = child.margin[dim]
      w = child.computed2[wDim]

    let align = toAxisAlign(child.align, dim)
    case cast[AxisAlign](ord(align) or ord(inheritedAxisAlign))
    of AxisAlignStretch:
      w = minSize
    of AxisAlignStart:
      w = max(min(w, minSize), child.size[dim])
    of AxisAlignEnd:
      w = max(min(w, minSize), child.size[dim])
      x = space - w - child.margin[wDim]
    of AxisAlignMiddle:
      w = max(min(w, minSize), child.size[dim])
      x = x + max(0f, (space - w - child.margin[dim] - child.margin[wDim]) / 2)

    l.updateResult(child, dim, x + offset, "arrangeOverlaySqueezedRange")
    l.updateResult(child, wDim, w, "arrangeOverlaySqueezedRange")

proc arrangeWrappedOverlaySqueezed(l: ptr Context, c: ptr NodeCache,
    dim: int32) =
  ## Calculate stretching and gap filling of all child nodes of the node on the cross axis.

  let wDim = dim + 2

  let n = c.node
  let offset = n.padding[dim]
  let space = n.computed2[wDim] - (n.padding[dim] + n.padding[wDim])
  let gap = n.gap[dim]
  let inheritedAxisAlign = toAxisAlign(n.layout, n.crossAxisAlign, dim)

  var needSize = 0f

  var squeezedRangeBegin = c.childOffset

  var lineCount = int32(1)
  var extraSpace = 0f
  var extraMargin = 0f
  var spacer = 0f
  var filler = 0f

  block:
    var used = 0f

    for idx in c.childOffset ..< c.childOffset + c.childCount:
      let
        cc = l.caches[idx].addr
        child = cc.node

      if cc.isBreak:
        inc lineCount, 1
        used = used + needSize
        needSize = 0

      let childSize = child.margin[dim] + child.computed2[wDim] + child.margin[wDim]
      needSize = max(needSize, childSize)
    used = used + needSize

    if lineCount > 1:
      spacer = gap
      used = used + float32(lineCount - 1) * gap

    extraSpace = space - used
    needSize = 0

  # Compute distribution of extra space according to cross‑axis line alignment.
  case n.crossAxisLineAlign
  of CrossAxisLineAlignStart:
    discard
  of CrossAxisLineAlignMiddle:
    extraMargin = extraSpace / 2
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

  # Assign line positions and let each line handle its children.
  var y = offset

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    if cc.isBreak:
      y = y + extraMargin
      l.arrangeOverlaySqueezedRange(
        dim, inheritedAxisAlign, squeezedRangeBegin, idx, y, needSize + filler
      )
      y = y + needSize
      extraMargin = spacer

      squeezedRangeBegin = idx
      needSize = 0

    let childSize = child.margin[dim] + child.computed2[wDim] + child.margin[wDim]
    needSize = max(needSize, childSize)

  # Final line.
  y = y + extraMargin
  l.arrangeOverlaySqueezedRange(
    dim,
    inheritedAxisAlign,
    squeezedRangeBegin,
    c.childOffset + c.childCount,
    y,
    needSize + filler,
  )

proc arrange(l: ptr Context, c: ptr NodeCache, dim: int32) =
  ## Second layout pass for a single node: position children and finalise sizes.
  ## Dispatches to the appropriate arrangement routine based on layout and wrap mode.

  let wDim = dim + 2

  let n = c.node

  if c.isSizeChanged[dim] or c.isContentSizeChanged[dim] or
      c.isContentPosDirty or c.isTreeDirty:
    case combine(n.layout, n.wrap)
    of combine(LayoutColumn, WrapWrap):
      if dim > 0:
        assert c.isDelay

        # For column wrap, the main axis is vertical. Wrap detection depends on
        # cross‑axis (width) results, so the cross axis is arranged first via delay.

        l.arrangeStacked(c, dim, true)
        l.arrangeWrappedOverlaySqueezed(c, 0)
    of combine(LayoutRow, WrapWrap):
      if dim > 0:
        assert c.isDelay

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
          n.padding[dim],
          n.computed2[wDim] - (n.padding[dim] + n.padding[wDim]),
        )
    else:
      # free layout model
      l.arrangeOverlay(c, dim)

    return

  when defined(debug) and defined(bujuDumpSkip):
    echo "skip arrange ", n.id, " dim: ", dim

proc arrange(l: ptr Context, dim: int32) =
  for idx in 0 ..< l.caches.len:
    let
      c = l.caches[idx].addr

    if dim <= 0:
      if not c.isDelay:
        l.arrange(c, dim)
    else:
      l.arrange(c, dim)

      if c.isDelay:
        l.arrange(c, 0)

proc buildCache(l: ptr Context, n: ptr Node, dummyCache: ptr NodeCache) =
  ## Build a breadth‑first cache of the subtree rooted at `n`.
  ## This cache enables efficient reverse‑order traversal so that children are always
  ## processed before parents during size calculation.

  l.caches.setLen(l.nodes.len)

  var
    idx = int32(0)
    count = int32(0)

  template addToCache(n2, parentOffset2, parentNodeCache2,
      isDelay2, isTreeDirty2): ptr NodeCache =
    let
      c2 = l.caches[count].addr
      isDirtyRoot = l.isDirty(n2, DirtyRoot)

    c2.node = n2
    c2.parentNodeCache = parentNodeCache2
    c2.isBreak = false
    c2.isDelay = isDelay2

    c2.isPosDirty = l.isDirty(n2, DirtyPos)
    c2.isSizeDirty = l.isDirty(n2, DirtySize)
    c2.isSiblingDirty = l.isDirty(n2, DirtySibling)
    c2.isContentPosDirty = l.isDirty(n2, DirtyContentPos)
    c2.isContentSizeDirty = l.isDirty(n2, DirtyContentSize)
    c2.isTreeDirty = isTreeDirty2

    # If the node was previously a root and is now a child (or vice versa), force a full recomputation.
    if (parentOffset2 >= 0 and isDirtyRoot) or (parentOffset2 < 0 and
        not isDirtyRoot):
      c2.isTreeDirty = true

    c2.isSizeChanged = [false, false]
    c2.isContentSizeChanged = [false, false]

    inc count, 1

    c2

  discard addToCache(n, -1, dummyCache, false, false)

  # Breadth‑first traversal: enqueue children of each node.
  while idx < count:
    let
      c = l.caches[idx].addr
      n = c.node

    reset(n.dirty)
    reset(n.computed)

    # If wrapping is enabled, delay the cross‑axis calculation.
    if n.wrap == WrapWrap:
      c.isDelay = true

    c.childOffset = count

    for child in l.children(n):
      inc c.childCount, 1

      let
        c2 = addToCache(child, idx, c, c.isDelay, c.isTreeDirty)

      if c2.isPosDirty or c2.isSiblingDirty or c2.isTreeDirty:
        c.isContentPosDirty = true

      if c2.isSizeDirty or c2.isSiblingDirty or c2.isTreeDirty:
        c.isContentSizeDirty = true

    inc idx, 1

  idx = count - 1

  # Propagate size dirty flags upward through the tree so that parents whose
  # children have changed size are also marked dirty.
  while idx >= 0:
    let
      c = l.caches[idx].addr

    if c.isSizeDirty:
      let
        pc = c.parentNodeCache
      pc.isSizeDirty = true

      idx = pc.childOffset

    dec idx, 1

  l.caches.setLen(count)

when defined(debug) and defined(bujuDumpDirtyFlag):
  proc dumpDirty(l: ptr Context) =
    for idx in 0 ..< l.caches.len:
      let
        c = l.caches[idx].addr
        n = c.node

      echo n.id, " isPosDirty: ", c.isPosDirty, " isSizeDirty: ", c.isSizeDirty,
          " isSiblingDirty: ", c.isSiblingDirty, " isContentPosDirty: ",
          c.isContentPosDirty, " isContentSizeDirty: ", c.isContentSizeDirty,
          " isTreeDirty: ", c.isTreeDirty

proc writeAbsoluteResult(l: ptr Context) =
  ## Convert the relative computed positions (computed2) into absolute coordinates
  ## (computed) by adding the parent’s position recursively. The result is stored
  ## in the `computed` field of every node.

  for idx in 0 ..< l.caches.len:
    let
      c = l.caches[idx].addr
      n = c.node

    n.computed[0] = n.computed[0] + n.computed2[0]
    n.computed[1] = n.computed[1] + n.computed2[1]
    n.computed[2] = n.computed2[2]
    n.computed[3] = n.computed2[3]

    for idx2 in c.childOffset ..< c.childOffset + c.childCount:
      let
        cc = l.caches[idx2].addr
        child = cc.node

      child.computed[0] = n.computed[0]
      child.computed[1] = n.computed[1]

proc compute*(l: ptr Context, n: ptr Node) =
  ## Main entry point for layout calculation.
  ## Computes size and absolute position for `n` and its entire subtree.
  ## Steps:
  ##   1. Build breadth‑first cache.
  ##   2. Compute base size for both axes (calcSize).
  ##   3. Arrange positions and stretch as needed (arrange).
  ##   4. Write final absolute coordinates (computed).
  ##   5. Clear the cache.

  var
    dummyCache: NodeCache
  l.buildCache(n, dummyCache.addr)

  when defined(debug) and defined(bujuDumpDirtyFlag):
    l.dumpDirty()

  template computeDim(dim) =
    ## Compute one axis: first size, then position.
    l.calcSize(dim)
    l.arrange(dim)

  # Axis order: horizontal first, then vertical.
  # Wrapped layouts use isDelay to reverse the order when needed.
  computeDim(0)
  computeDim(1)

  l.writeAbsoluteResult()

  # Cache is no longer needed.
  l.caches.setLen(0)

  # Mark this node so that if it is later reparented it will be fully recalculated.
  l.mark(n, DirtyRoot)
