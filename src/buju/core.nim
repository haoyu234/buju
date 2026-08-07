import std/strformat

type
  NodeID* {.size: 4.} = enum
    NIL

  Align* = enum
    ## Axis-agnostic, combinable alignment for a single node, resolved per axis by toAxisAlign.
    ## AlignMiddle centers the cross axis (and both axes under the Free overlay model). A pair of opposite anchors (Left+Right or Top+Bottom) stretches that axis. A single anchor aligns to start or end. The empty set inherits the parent cross-axis alignment (align-items) with no main-axis inheritance. On a flex main axis only the same-axis opposing pair stretches, so AlignMiddle has no stretching effect there.
    AlignMiddle = 0x00
    AlignLeft = 0x01
    AlignTop = 0x02
    AlignRight = 0x04
    AlignBottom = 0x08

  AxisAlign = enum
    AxisAlignMiddle = 0x00
    AxisAlignStart = 0x01
    AxisAlignEnd = 0x04
    AxisAlignStretch = 0x05

  MainAxisAlign* = enum
    ## Mirrors Flex `justify-content`: alignment of all nodes on the main axis.
    MainAxisAlignMiddle = AxisAlignMiddle
    MainAxisAlignStart = AxisAlignStart
    MainAxisAlignEnd = AxisAlignEnd
    MainAxisAlignSpaceBetween = 0x08
    MainAxisAlignSpaceAround = 0x10
    MainAxisAlignSpaceEvenly = 0x18

  CrossAxisAlign* = enum
    ## Mirrors Flex `align-items`: alignment of all nodes on the cross axis.
    CrossAxisAlignMiddle = AxisAlignMiddle
    CrossAxisAlignStart = AxisAlignStart
    CrossAxisAlignEnd = AxisAlignEnd
    CrossAxisAlignStretch = AxisAlignStretch

  CrossAxisLineAlign* = enum
    ## Mirrors Flex `align-content`: alignment and spacing of flex lines along the cross axis (only effective in multi-line layouts).
    CrossAxisLineAlignMiddle = AxisAlignMiddle
    CrossAxisLineAlignStart = AxisAlignStart
    CrossAxisLineAlignEnd = AxisAlignEnd
    CrossAxisLineAlignStretch = AxisAlignStretch
    CrossAxisLineAlignSpaceBetween = 0x08
    CrossAxisLineAlignSpaceAround = 0x10
    CrossAxisLineAlignSpaceEvenly = 0x18

  Layout* = enum
    ## Child node arrangement direction.
    LayoutFree = 0x00
    LayoutRow = 0x01
    LayoutColumn = 0x02

  Wrap* = enum
    ## Child node wrapping behavior (only effective in Flex layout).
    WrapNoWrap = 0x00
    WrapWrap = 0x01

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

    isBreak: bool
      ## True at the first node of each wrapped line, marking a wrap-line boundary.
    isWrapped: bool
      ## True once the wrap break pass has written this container's child main-axis geometry.
    isMainSized: bool
      ## True once this wrap container's main-axis size has been computed.

    wrap*: Wrap
    layout*: Layout
    mainAxisAlign*: MainAxisAlign
    crossAxisAlign*: CrossAxisAlign
    crossAxisLineAlign*: CrossAxisLineAlign
    align*: set[Align]

    size*: array[2, float32] ## Explicit node size (order: width -> height).
    gap*: array[2, float32]
      ## Spacing between child nodes (order: column gap -> row gap).
    margin*: array[4, float32] ## Node margin (order: left -> top -> right -> bottom).
    padding*: array[4, float32] ## Node padding (order: left -> top -> right -> bottom).

    computed*: array[4, float32]
      ## Computed rectangle (x, y, width, height). Positions (indices 0-1) are
      ## written PARENT-relative during calcSize/arrange and converted to
      ## ROOT-relative by rebaseToRoot before compute returns.

    when defined(bujuUserData):
      userData*: RootRef

  NodeCache = object
    node: ptr Node
    childOffset: int32 ## Start index of this node's children in the cache.
    childCount: int32  ## Number of direct children of this node.

  Context* = object
    nodes*: seq[Node]
    caches: seq[NodeCache]
      ## Breadth-first traversal cache for indexed child access during compute.

proc combine(layout: Layout, wrap: Wrap): uint32 {.inline.} =
  uint32(ord(layout) + (ord(wrap) shl 8))

proc isSameAxis(layout: Layout, dim: int32): bool {.inline.} =
  ord(layout) == (dim + 1)

proc toAxisAlign(align: set[Align], dim: int32): AxisAlign {.inline.} =
  if AlignMiddle in align:
    result = AxisAlignMiddle
    return

  var bits = uint32(0)
  for a in [AlignLeft, AlignTop, AlignRight, AlignBottom]:
    if a in align:
      bits = bits or uint32(a)

  cast[AxisAlign]((bits shr dim) and ord(AxisAlignStretch))

proc toAxisAlign(layout: Layout, crossAxisAlign: CrossAxisAlign,
    dim: int32): AxisAlign {.inline.} =
  if isSameAxis(layout, dim):
    AxisAlignMiddle
  else:
    cast[AxisAlign](crossAxisAlign)

proc toAxisAlign(align: set[Align], dim: int32,
    inheritedAxisAlign: AxisAlign): AxisAlign {.inline.} =
  ## Resolves a child's cross-axis alignment: AlignMiddle takes highest priority, an explicit anchor overrides the parent's align-items, and an unset child inherits `inheritedAxisAlign`.

  if AlignMiddle in align:
    result = AxisAlignMiddle
    return

  const
    verticalAligns = {AlignTop, AlignBottom}
    horizontalAligns = {AlignLeft, AlignRight}

  let aligns = if dim == 0: horizontalAligns else: verticalAligns

  if align * aligns != {}:
    toAxisAlign(align, dim)
  else:
    inheritedAxisAlign

proc `$`*(id: NodeID): string =
  if id != NIL:
    result = fmt"NODE{int32(id)}"
    return
  result = "NIL"

proc isNil*(id: NodeID): bool {.inline.} =
  id == NIL

proc node*(l: ptr Context, id: NodeID): ptr Node {.inline.} =
  let idx = int32(id) - 1
  if idx >= 0 and idx < len(l.nodes):
    result = l.nodes[idx].addr

proc updateResult(l: ptr Context, n: ptr Node, idx: int32, val: float32,
    name: string) {.inline.} =
  ## Pure writer: assigns one computed coordinate. Layout size semantics are decided by the caller, not here.
  n.computed[idx] = val

  when defined(debug) and defined(bujuDumpUpdateResult):
    echo name, " set ", n.id, ".computed[", idx, "] to ", val

iterator children*(l: ptr Context, n: ptr Node): ptr Node =
  var n = l.node(n.firstChild)
  while not n.isNil:
    yield n
    n = l.node(n.nextSibling)

proc calcStackedSize(l: ptr Context, c: ptr NodeCache, dim: int32): float32 =
  when defined(debug) and defined(bujuDumpCall):
    echo "calcStackedSize ", c.node.id, " ", dim

  let wDim = dim + 2

  let n = c.node

  var needSize = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    let size = child.margin[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = needSize + size

  var gap = 0f
  if c.childCount > 0 and isSameAxis(n.layout, dim):
    gap = gap + n.gap[dim] * float32(c.childCount - 1)

  result = needSize + gap

proc calcOverlayedSize(l: ptr Context, c: ptr NodeCache, dim: int32): float32 =
  when defined(debug) and defined(bujuDumpCall):
    echo "calcOverlayedSize ", c.node.id, " ", dim

  let wDim = dim + 2

  let n = c.node

  var needSize = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    let size = child.margin[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(size, needSize)

  var gap = 0f
  if c.childCount > 0 and isSameAxis(n.layout, dim):
    gap = gap + n.gap[dim] * float32(c.childCount - 1)

  result = needSize + gap

proc calcWrappedOverlayedSize(l: ptr Context, c: ptr NodeCache,
    dim: int32): float32 =
  let wDim = dim + 2

  let n = c.node

  var
    needSize = 0f
    needSize2 = 0f
    lineCount = uint32(1)

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    if child.isBreak:
      inc lineCount, 1
      needSize2 = needSize2 + needSize
      needSize = 0

    let size = child.margin[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(needSize, size)

  var gap = 0f
  if lineCount > 0:
    gap = gap + n.gap[dim] * float32(lineCount - 1)

  result = needSize2 + needSize + gap

proc arrangeStacked(l: ptr Context, c: ptr NodeCache, dim: int32, wrap: bool) =
  when defined(debug) and defined(bujuDumpCall):
    echo "arrangeStacked ", c.node.id, " ", dim

  ## Lays out `c`'s children along their main axis (wrap, align, gap, stretch) and writes PARENT-relative position and size.

  let wDim = dim + 2

  let n = c.node

  let offset = n.padding[dim]
  let space = n.computed[wDim] - (n.padding[dim] + n.padding[wDim])

  var arrangeRangeBegin = c.childOffset
  let arrangeRangeEnd = c.childOffset + c.childCount

  while arrangeRangeBegin != arrangeRangeEnd:
    var used = 0f

    var count = int32(0)

    var total = int32(0)

    var expandRangeEnd = arrangeRangeEnd

    for idx in arrangeRangeBegin ..< arrangeRangeEnd:
      let
        cc = l.caches[idx].addr
        child = cc.node

      var extend = used + child.margin[dim] + child.margin[wDim] +
          child.computed[wDim]

      if idx != arrangeRangeBegin:
        extend = extend + n.gap[dim]

      if wrap:
        if total > 0 and extend > space:
          expandRangeEnd = idx

          child.isBreak = true
          break

      if toAxisAlign(child.align, dim) == AxisAlignStretch:
        inc count, 1

      inc total, 1
      used = extend

    let extraSpace = space - used
    var filler = 0f
    var spacer = 0f
    var extraMargin = 0f

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

    for idx in arrangeRangeBegin ..< expandRangeEnd:
      let
        cc = l.caches[idx].addr
        child = cc.node

      x = x + child.margin[dim] + extraMargin
      if idx != arrangeRangeBegin:
        x = x + n.gap[dim]

      var w = child.computed[wDim]

      if toAxisAlign(child.align, dim) == AxisAlignStretch:
        w = w + filler

      l.updateResult(child, dim, x, "arrangeStacked")
      l.updateResult(child, wDim, w, "arrangeStacked")

      x = x + w + child.margin[wDim]
      extraMargin = spacer

    arrangeRangeBegin = expandRangeEnd

proc arrangeOverlay(l: ptr Context, c: ptr NodeCache, dim: int32) =
  when defined(debug) and defined(bujuDumpCall):
    echo "arrangeOverlay ", c.node.id, " ", dim

  let wDim = dim + 2

  let n = c.node
  let offset = n.padding[dim]
  let space = n.computed[wDim] - (n.padding[dim] + n.padding[wDim])

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    var
      x = child.margin[dim]
      w = child.computed[wDim]

    case toAxisAlign(child.align, dim)
    of AxisAlignStretch:
      # Stretch fills the available content space (the size/padding floor is already baked into `w` by calcSize).
      w = max(w, max(0f, space - child.margin[dim] - child.margin[wDim]))
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
    offset, space: float32, ) =
  let wDim = dim + 2

  for idx in squeezedRangeBegin ..< arrangeRangeEnd:
    let
      cc = l.caches[idx].addr
      child = cc.node

      availSize = max(0f, space - child.margin[dim] - child.margin[wDim])

    var
      x = child.margin[dim]
      w = child.computed[wDim]

    case toAxisAlign(child.align, dim, inheritedAxisAlign)
    of AxisAlignStretch:
      # Stretch fills the available content space, floored at max(size, padding).
      let padding = child.padding[dim] + child.padding[wDim]
      w = max(availSize, max(child.size[dim], padding))
    of AxisAlignStart:
      w = max(w, child.size[dim])
    of AxisAlignEnd:
      w = max(w, child.size[dim])
      x = space - w - child.margin[wDim]
    of AxisAlignMiddle:
      w = max(w, child.size[dim])
      x = x + (space - w - child.margin[dim] - child.margin[wDim]) / 2

    l.updateResult(child, dim, x + offset, "arrangeOverlaySqueezedRange")
    l.updateResult(child, wDim, w, "arrangeOverlaySqueezedRange")

proc arrangeWrappedOverlaySqueezed(l: ptr Context, c: ptr NodeCache, dim: int32) =
  when defined(debug) and defined(bujuDumpCall):
    echo "arrangeWrappedOverlaySqueezed ", c.node.id, " ", dim

  let wDim = dim + 2

  let n = c.node
  let offset = n.padding[dim]
  let space = n.computed[wDim] - (n.padding[dim] + n.padding[wDim])
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

      if child.isBreak:
        inc lineCount, 1
        used = used + needSize
        needSize = 0

      let childSize = child.margin[dim] + child.computed[wDim] + child.margin[wDim]
      needSize = max(needSize, childSize)
    used = used + needSize

    if lineCount > 1:
      spacer = gap
      used = used + float32(lineCount - 1) * gap

    extraSpace = space - used
    needSize = 0

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

  var y = offset

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let
      cc = l.caches[idx].addr
      child = cc.node

    if child.isBreak:
      y = y + extraMargin
      l.arrangeOverlaySqueezedRange(
        dim, inheritedAxisAlign, squeezedRangeBegin, idx, y, needSize + filler
      )
      y = y + needSize
      extraMargin = spacer

      squeezedRangeBegin = idx
      needSize = 0

    let childSize = child.margin[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(needSize, childSize)

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
  when defined(debug) and defined(bujuDumpCall):
    echo "arrange ", c.node.id, " ", dim

  let wDim = dim + 2

  let n = c.node

  case combine(n.layout, n.wrap)
  of combine(LayoutColumn, WrapWrap):
    if dim > 0:
      assert n.wrap == WrapWrap

      # Main axis already laid out by `arrangeStacked` (in calcSize). Only the cross-axis overlay is needed here.
      l.arrangeWrappedOverlaySqueezed(c, 0)
  of combine(LayoutRow, WrapWrap):
    if dim > 0:
      assert n.wrap == WrapWrap

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
        n.computed[wDim] - (n.padding[dim] + n.padding[wDim]),
      )
  else:
    l.arrangeOverlay(c, dim)

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let cc = l.caches[idx].addr

    l.arrange(cc, dim)

  # For a wrapped container, after the main/cross axes are laid out at dim > 0,
  # re-arrange the direct children along dim 0 so grandchildren are positioned
  # relative to the now-finalized child cross positions. This is what makes
  # nested wrap containers (e.g. a wrapped node containing another wrapped node)
  # position their descendants correctly.
  if n.wrap == WrapWrap and dim > 0:
    for idx in c.childOffset ..< c.childOffset + c.childCount:
      let cc = l.caches[idx].addr

      l.arrange(cc, 0)

proc calcSize(l: ptr Context, c: ptr NodeCache, dim: int32) =
  when defined(debug) and defined(bujuDumpCall):
    echo "calcSize ", c.node.id, " ", dim

  let wDim = dim + 2

  let n = c.node

  # Skip the whole subtree pass once the main axis is sized. The guard runs before child recursion so descendants are skipped too.
  if n.wrap == WrapWrap:
    let mainDim =
      if n.layout == LayoutRow:
        int32(0)
      else:
        int32(1)
    if dim == mainDim:
      if n.isMainSized:
        return
      # Mark the main axis as sized up front, before any early return on an explicit size, so later passes skip the redundant recompute.
      n.isMainSized = true

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let cc = l.caches[idx].addr

    l.calcSize(cc, dim)

  let padding = n.padding[dim] + n.padding[wDim]

  # Auto cross-axis size needs the multi-line structure (isBreak) from the main-axis pass, so size/break main first, keeping compute(0)->compute(1) symmetric.
  if n.wrap == WrapWrap:
    let
      mainDim =
        if n.layout == LayoutRow:
          int32(0)
        else:
          int32(1)

      crossDim = int32(1) - mainDim

    if dim == crossDim and not n.isWrapped:
      # Size the main axis if not already sized (the opposite-orientation pass may have done it), then lay it out via `arrangeStacked`.
      if not n.isMainSized:
        l.calcSize(c, mainDim)
      l.arrangeStacked(c, mainDim, true)
      n.isWrapped = true

  l.updateResult(n, dim, n.margin[dim], "calcSize")

  # Explicit input size, floored at the node's own padding box (CSS border-box).
  if n.size[dim] > 0:
    l.updateResult(n, wDim, max(n.size[dim], padding), "calcSize")
    return

  let needSize =
    case combine(n.layout, n.wrap)
    of combine(LayoutColumn, WrapWrap):
      if dim > 0:
        l.calcStackedSize(c, dim)
      else:
        l.calcWrappedOverlayedSize(c, dim)
    of combine(LayoutRow, WrapWrap):
      if dim > 0:
        l.calcWrappedOverlayedSize(c, dim)
      else:
        l.calcStackedSize(c, dim)
    of combine(LayoutRow, WrapNoWrap), combine(LayoutColumn, WrapNoWrap):
      if isSameAxis(n.layout, dim):
        l.calcStackedSize(c, dim)
      else:
        l.calcOverlayedSize(c, dim)
    else:
      l.calcOverlayedSize(c, dim)

  # Auto size floors at the padding box, same as the explicit-size path.
  l.updateResult(n, wDim, needSize + padding, "calcSize")

proc addToCache(l: ptr Context, count: var int32, n: ptr Node): ptr NodeCache =
  let c = l.caches[count].addr
  inc count, 1
  c.node = n
  c

proc rebaseToRoot(l: ptr Context, n: ptr Node) =
  ## Re-bases `n`'s direct children to ROOT-relative by adding `n`'s position, then recurses. Called once after both axes are arranged.
  for child in l.children(n):
    child.computed[0] = child.computed[0] + n.computed[0]
    child.computed[1] = child.computed[1] + n.computed[1]
    l.rebaseToRoot(child)

proc compute*(l: ptr Context, n: ptr Node) =
  ## Core layout entry: computes size and ROOT-relative position for a node and its subtree.

  l.caches.setLen(l.nodes.len)

  var
    idx = int32(0)
    count = int32(0)

  let root = l.addToCache(count, n)

  # Step 1: cache every node via breadth-first traversal for indexed child access during calcSize/arrange.
  while idx < count:
    let
      c = l.caches[idx].addr
      n = c.node

    n.isBreak = false
    n.isWrapped = false
    n.isMainSized = false
    c.childOffset = count

    for child in l.children(n):
      inc c.childCount, 1

      discard l.addToCache(count, child)

    inc idx, 1

  l.caches.setLen(count)

  template compute(idx) =
    l.calcSize(root, idx)
    l.arrange(root, idx)

  # Step 2: compute axis 0 (size and PARENT-relative position for every node).
  compute(0)
  # Step 3: compute axis 1 (repeats the cross-axis wrap pass first if needed, then sizes and arranges).
  compute(1)

  # Step 4: convert all positions to ROOT-relative via rebaseToRoot.
  l.rebaseToRoot(root.node)

  # Step 5: Clear traversal cache (cache is only used during compute).
  l.caches.setLen(0)
