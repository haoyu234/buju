import std/strformat

type
  NodeID* {.size: 4.} = enum ## Node id, avoid using pointers and references
    NIL

  NodeCache = object
    node: ptr Node
    childOffset: uint32
    childCount: uint32

  Align* = enum
    AlignLeft = 0x01
    AlignTop = 0x02
    AlignRight = 0x04
    AlignBottom = 0x08

  MainAxisAlign* = enum
    MainAxisAlignMiddle = 0x00
    MainAxisAlignStart = 0x01
    MainAxisAlignEnd = 0x02
    MainAxisAlignSpaceBetween = 0x03
    MainAxisAlignSpaceAround = 0x05
    MainAxisAlignSpaceEvenly = 0x07

  AxisAlign = enum
    AxisAlignMiddle = 0x00
    AxisAlignStart = 0x01
    AxisAlignEnd = 0x04
    AxisAlignStretch = 0x05

  CrossAxisAlign* = enum
    CrossAxisAlignMiddle = AxisAlignMiddle
    CrossAxisAlignStart = AxisAlignStart
    CrossAxisAlignEnd = AxisAlignEnd
    CrossAxisAlignStretch = AxisAlignStretch

  Layout* = enum
    LayoutFree = 0x00
    LayoutRow = 0x01
    LayoutColumn = 0x02

  Wrap* = enum
    WrapNoWrap = 0x00
    WrapWrap = 0x01

  Node* = object  ## Layout node type
    id*: NodeID

    isBreak: bool ## whether an node's children have already been wrapped.
    isSkipXAxis: bool
      ## whether or not to delay the calculation of the X-axis coordinates

    wrap*: Wrap
    layout*: Layout
    mainAxisAlign*: MainAxisAlign
    crossAxisAlign*: CrossAxisAlign
    align*: set[Align]

    firstChild*: NodeID
    lastChild*: NodeID
    prevSibling*: NodeID
    nextSibling*: NodeID

    margin*: array[4, float32]
    size*: array[2, float32]

    computed*: array[4, float32]
      ## the calculated rectangle of an node.
      ## The components of the vector are:
      ## 0: x starting position, 1: y starting position, 2: width, 3: height.

  Context* = object
    nodes*: seq[Node]
    caches: seq[NodeCache] ## Cache the results of breadth-first traversals

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

proc calcStackedSize(l: ptr Context, c: ptr NodeCache, dim: static[
    int]): float32 =
  const wDim = dim + 2

  var needSize = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = needSize + size
  needSize

proc calcOverlayedSize(l: ptr Context, c: ptr NodeCache, dim: static[
    int]): float32 =
  const wDim = dim + 2

  var needSize = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(size, needSize)
  needSize

proc calcWrappedOverlayedSize(l: ptr Context, c: ptr NodeCache, dim: static[
    int]): float32 =
  const wDim = dim + 2

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

proc calcWrappedStackedSize(l: ptr Context, c: ptr NodeCache, dim: static[
    int]): float32 =
  const wDim = dim + 2

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

template isSameAxis(layout: Layout, dim: static[int]): bool =
  ord(layout) == (dim + 1)

template toAxisAlign(align: set[Align], dim: static[int]): AxisAlign =
  var bits = uint32(0)
  for a in align:
    bits = bits or uint32(a)

  cast[AxisAlign]((bits shr dim) and ord(AxisAlignStretch))

template toAxisAlign(layout: Layout, crossAxisAlign: CrossAxisAlign,
    dim: static[int]): AxisAlign =
  if isSameAxis(layout, dim):
    AxisAlignMiddle
  else:
    cast[AxisAlign](crossAxisAlign)

    # case crossAxisAlign
    # of CrossAxisAlignMiddle: AxisAlignMiddle
    # of CrossAxisAlignStart: AxisAlignStart
    # of CrossAxisAlignEnd: AxisAlignEnd
    # of CrossAxisAlignStretch: AxisAlignStretch

proc calcSize(l: ptr Context, dim: static[int]) =
  const wDim = dim + 2

  # Note that we are doing a reverse-order loop here,
  # so the child nodes are always calculated before the parent nodes.
  var idx = l.caches.len
  while idx > 0:
    dec idx, 1

    let c = l.caches[idx].addr
    let n = c.node

    # Set the mutable rect output data to the starting input data
    n.computed[dim] = n.margin[dim]

    # If we have an explicit input size, just set our output size (which other
    # calcXxxSize and arrange procedures will use) to it.
    if n.size[dim] > 0:
      n.computed[wDim] = n.size[dim]
      continue

    let needSize =
      case combine(n.layout, n.wrap)
      of combine(LayoutColumn, WrapWrap):
        when dim > 0:
          l.calcStackedSize(c, dim)
        else:
          l.calcOverlayedSize(c, dim)
      of combine(LayoutRow, WrapWrap):
        when dim > 0:
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

proc arrangeStacked(l: ptr Context, c: ptr NodeCache, dim: static[int],
    wrap: static[bool]) =
  const wDim = dim + 2

  let n = c.node

  let computed = n.computed
  let space = computed[wDim]

  var arrangeRangeBegin = c.childOffset
  let arrangeRangeEnd = c.childOffset + c.childCount

  when wrap:
    let maxX2 = computed[dim] + space

  while arrangeRangeBegin != arrangeRangeEnd:
    var used = 0f

    # count of fillers
    var count = 0

    # count of squeezable elements
    var squeezedCount = 0
    var total = 0
    var itemCount = 0

    var expandRangeEnd = arrangeRangeEnd

    # first pass: count items that need to be expanded, and the space that is used
    for idx in arrangeRangeBegin ..< arrangeRangeEnd:
      let child = l.caches[idx].node

      inc itemCount, 1
      var extend = used + child.computed[dim] + child.margin[wDim]

      if toAxisAlign(child.align, dim) == AxisAlignStretch:
        inc count
      else:
        if child.size[dim] <= 0:
          inc squeezedCount
        extend = extend + child.computed[wDim]

      when wrap:
        # wrap on end of line
        if total > 0 and extend > space:
          expandRangeEnd = idx

          # add marker for subsequent queries
          child.isBreak = true
          itemCount = 0
          break

      inc total
      used = extend

    let extraSpace = space - used
    var filler = 0f
    var spacer = 0f
    var extraMargin = 0f
    var eater = 0f

    if extraSpace > 0:
      if count > 0:
        filler = extraSpace / float32(count)
      elif total > 0:
        case n.mainAxisAlign
        of MainAxisAlignSpaceBetween:
          if not wrap or (itemCount > 0 or expandRangeEnd != arrangeRangeEnd):
            spacer = extraSpace / float32(total - 1)
        of MainAxisAlignSpaceAround:
          if not wrap or (itemCount > 0 or expandRangeEnd != arrangeRangeEnd):
            spacer = extraSpace / float32(total)
            extraMargin = spacer / 2
        of MainAxisAlignSpaceEvenly:
          if not wrap or (itemCount > 0 or expandRangeEnd != arrangeRangeEnd):
            spacer = extraSpace / float32(total + 1)
            extraMargin = spacer
        of MainAxisAlignStart:
          discard
        of MainAxisAlignEnd:
          extraMargin = extraSpace
        of MainAxisAlignMiddle:
          extraMargin = extraSpace / 2
    else:
      when not wrap:
        if extraSpace < 0 and squeezedCount > 0:
          eater = extraSpace / float32(squeezedCount)

    # distribute width among items
    var x = computed[dim]
    var x1 = 0f

    # second pass: distribute and rescale
    for idx in arrangeRangeBegin ..< expandRangeEnd:
      let child = l.caches[idx].node

      x += child.computed[dim] + extraMargin
      if toAxisAlign(child.align, dim) == AxisAlignStretch:
        # grow
        x1 = x + filler
      elif child.size[dim] > 0:
        x1 = x + child.computed[wDim]
      else:
        # squeeze
        x1 = x + max(0f, child.computed[wDim] + eater)

      let ix0 = x
      let ix1 =
        when wrap:
          min(maxX2 - child.margin[wDim], x1)
        else:
          x1

      child.computed[dim] = ix0 # pos
      child.computed[wDim] = ix1 - ix0 # size

      extraMargin = spacer
      x = x1 + child.margin[wDim]

    arrangeRangeBegin = expandRangeEnd

proc arrangeOverlay(l: ptr Context, c: ptr NodeCache, dim: static[
    int]) =
  const wDim = dim + 2

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
        max(0f, (space - child.computed[wDim]) / 2 - child.margin[wDim])

    child.computed[dim] = child.computed[dim] + offset

proc arrangeOverlaySqueezedRange(l: ptr Context, dim: static[int],
    inheritedAxisAlign: AxisAlign, squeezedRangeBegin, arrangeRangeEnd: uint32,
    offset, space: float32) =
  const wDim = dim + 2

  for idx in squeezedRangeBegin ..< arrangeRangeEnd:
    let child = l.caches[idx].node
    let minSize = max(0f, space - child.computed[dim] - child.margin[wDim])
    let childAlign = toAxisAlign(child.align, dim)
    let composeAlign = cast[AxisAlign](ord(childAlign) or ord(inheritedAxisAlign))
    case composeAlign
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
        max(0f, (space - child.computed[wDim]) / 2 - child.margin[wDim])

    child.computed[dim] = child.computed[dim] + offset

proc arrangeWrappedOverlaySqueezed(l: ptr Context, c: ptr NodeCache,
    dim: static[int]): float32 =
  const wDim = dim + 2

  let n = c.node
  let inheritedAxisAlign = toAxisAlign(n.layout, n.crossAxisAlign, dim)

  var offset = n.computed[dim]
  var needSize = 0f

  var squeezedRangeBegin = c.childOffset

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    if child.isBreak:
      l.arrangeOverlaySqueezedRange(
        dim, inheritedAxisAlign, squeezedRangeBegin, idx, offset, needSize
      )
      offset = offset + needSize
      squeezedRangeBegin = idx
      needSize = 0

    let childSize = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(needSize, childSize)

  l.arrangeOverlaySqueezedRange(
    dim,
    inheritedAxisAlign,
    squeezedRangeBegin,
    c.childOffset + c.childCount,
    offset,
    needSize,
  )

  offset + needSize

proc arrange(l: ptr Context, c: ptr NodeCache, dim: static[int]) =
  const wDim = dim + 2

  let n = c.node

  case combine(n.layout, n.wrap)
  of combine(LayoutColumn, WrapWrap):
    if dim > 0:
      assert n.isSkipXAxis

      # The X-axis are recalculated here.
      l.arrangeStacked(c, 1, true)
      let offset = l.arrangeWrappedOverlaySqueezed(c, 0)
      n.computed[2] = offset - n.computed[0]
  of combine(LayoutRow, WrapWrap):
    if dim > 0:
      discard l.arrangeWrappedOverlaySqueezed(c, 1)
    else:
      l.arrangeStacked(c, 0, true)
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

proc arrange(l: ptr Context, dim: static[int]) =
  for idx in 0 ..< l.caches.len:
    let c = l.caches[idx].addr
    let n = c.node

    when dim <= 0:
      if not n.isSkipXAxis:
        l.arrange(c, dim)
    else:
      l.arrange(c, dim)

      if n.isSkipXAxis:
        l.arrange(c, 0)

proc compute*(l: ptr Context, n: ptr Node) =
  n.isSkipXAxis = false

  l.caches.add(NodeCache(node: n))

  var idx = 0

  # Cache the results of the breadth-first traversal.
  # For subsequent calculations, you can directly access the child nodes using subscripts.
  while idx < l.caches.len:
    let n = l.caches[idx].node
    let childOffset = uint32(l.caches.len)

    if n.layout == LayoutColumn and n.wrap == WrapWrap:
      # delayed calculations are required
      n.isSkipXAxis = true

    n.isBreak = false

    var count = 0
    let isSkipXAxis = n.isSkipXAxis

    for child in l.children(n):
      inc count, 1

      child.isSkipXAxis = isSkipXAxis
      l.caches.add(NodeCache(node: child))

    let c = l.caches[idx].addr
    c.childOffset = childOffset
    c.childCount = uint32(count)

    inc idx, 1

  template computeDim(dim) =
    l.calcSize(dim)
    l.arrange(dim)

  computeDim(0)
  computeDim(1)

  l.caches.setLen(0)
