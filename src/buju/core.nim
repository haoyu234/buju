import vmath
import std/strformat

type
  LayoutNodeID* {.size: 4.} = enum ## Node id, avoid using pointers and references
    NIL

  LayoutCacheObj = object
    node: ptr LayoutNodeObj
    childOffset: uint32
    childCount: uint32

  LayoutNodeObj* = object ## Layout node type
    id*: LayoutNodeID

    isBreak: bool ## whether an node's children have already been wrapped.
    isSkipXAxis: bool
      ## whether or not to delay the calculation of the X-axis coordinates
    boxFlags*: uint8 ## determines how it behaves as a parent
    anchorFlags*: uint8 ## determines how it behaves as a child inside of a parent node

    firstChild*: LayoutNodeID
    lastChild*: LayoutNodeID
    prevSibling*: LayoutNodeID
    nextSibling*: LayoutNodeID

    margin*: Vec4
    size*: Vec2

    computed*: Vec4
      ## the calculated rectangle of an node.
      ## The components of the vector are:
      ## 0: x starting position, 1: y starting position, 2: width, 3: height.

  LayoutObj* = object
    nodes*: seq[LayoutNodeObj]
    caches: seq[LayoutCacheObj] ## Cache the results of breadth-first traversals

const
  ## layout, default is center in both directions, with left/top margin as offset.
  LayoutLeft* = 0x01 ## anchor to left node or left side of parent
  LayoutTop* = 0x02 ## anchor to top node or top side of parent
  LayoutRight* = 0x04 ## anchor to right node or right side of parent
  LayoutBottom* = 0x08 ## anchor to bottom node or bottom side of parent
  LayoutHorizontalFill* = LayoutLeft or LayoutRight
    ## anchor to both left and right node or parent borders
  LayoutVerticalFill* = LayoutTop or LayoutBottom
    ## anchor to both top and bottom node or parent borders
  LayoutFill* = LayoutHorizontalFill or LayoutVerticalFill
    ## anchor to all four directions

  ## flex-wrap, the default is single-line.
  LayoutBoxNoWrap* = 0x000
  LayoutBoxWrap* = 0x004 ## multi-line, wrap left to right

  ## justify-content (start, end, center, space-between), the default is center.
  LayoutBoxMiddle* = 0x000 ## at center of row/column
  LayoutBoxStart* = 0x008 ## at start of row/column
  LayoutBoxEnd* = 0x010 ## at end of row/column
  LayoutBoxJustify* = LayoutBoxStart or LayoutBoxEnd
    ## insert spacing to stretch across whole row/column

  ## layout type, default is free layout.
  LayoutBoxFree* = 0x000 ## free layout
  LayoutBoxRow* = 0x002 ## flex layout, left to right
  LayoutBoxColumn* = 0x003 ## flex layout, top to bottom

proc `$`*(id: LayoutNodeID): string =
  if id != NIL:
    return fmt"NODE{int(id)}"
  return "NIL"

proc isNil*(id: LayoutNodeID): bool {.inline, raises: [].} =
  id == NIL

proc node*(
    l: ptr LayoutObj, id: LayoutNodeID
): ptr LayoutNodeObj {.inline, raises: [].} =
  l.nodes[uint(id) - 1].addr

proc model(n: ptr LayoutNodeObj): int {.inline, raises: [].} =
  int(n.boxFlags and 0x7)

proc direction(n: ptr LayoutNodeObj): int {.inline, raises: [].} =
  int(n.boxFlags and 0x1)

proc axisAnchorFlags(
    n: ptr LayoutNodeObj, dim: static[int]
): int {.inline, raises: [].} =
  (int(n.anchorFlags and 0x1F) shr dim) and LayoutHorizontalFill

proc firstChild*(
    l: ptr LayoutObj, n: ptr LayoutNodeObj
): ptr LayoutNodeObj {.inline, raises: [].} =
  let nodeID = n.firstChild
  if not nodeID.isNil:
    return l.node(nodeID)
  return nil

proc lastChild*(
    l: ptr LayoutObj, n: ptr LayoutNodeObj
): ptr LayoutNodeObj {.inline, raises: [].} =
  let nodeID = n.lastChild
  if not nodeID.isNil:
    return l.node(nodeID)
  return nil

proc nextSibling*(
    l: ptr LayoutObj, n: ptr LayoutNodeObj
): ptr LayoutNodeObj {.inline, raises: [].} =
  let nodeID = n.nextSibling
  if not nodeID.isNil:
    return l.node(nodeID)
  return nil

iterator children*(
    l: ptr LayoutObj, n: ptr LayoutNodeObj
): ptr LayoutNodeObj {.inline, raises: [].} =
  var nodeID = n.firstChild
  while not nodeID.isNil:
    let n = l.node(nodeID)
    nodeID = n.nextSibling
    yield n

proc calcStackedSize(
    l: ptr LayoutObj, c: ptr LayoutCacheObj, dim: static[int]
): float {.inline, raises: [].} =
  const wDim = dim + 2

  var needSize = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = needSize + size
  needSize

proc calcOverlayedSize(
    l: ptr LayoutObj, c: ptr LayoutCacheObj, dim: static[int]
): float {.inline, raises: [].} =
  const wDim = dim + 2

  var needSize = 0f

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(size, needSize)
  needSize

proc calcWrappedOverlayedSize(
    l: ptr LayoutObj, c: ptr LayoutCacheObj, dim: static[int]
): float {.inline, raises: [].} =
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

proc calcWrappedStackedSize(
    l: ptr LayoutObj, c: ptr LayoutCacheObj, dim: static[int]
): float {.inline, raises: [].} =
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

proc calcSize(l: ptr LayoutObj, dim: static[int]) {.inline, raises: [].} =
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

    # Calculate our size based on children items.
    let needSize =
      case n.model
      of LayoutBoxColumn or LayoutBoxWrap:
        # flex model
        when dim > 0:
          l.calcStackedSize(c, 1)
        else:
          l.calcOverlayedSize(c, 0)
      of LayoutBoxRow or LayoutBoxWrap:
        # flex model
        when dim > 0:
          l.calcWrappedOverlayedSize(c, 1)
        else:
          l.calcWrappedStackedSize(c, 0)
      of LayoutBoxColumn, LayoutBoxRow:
        # flex model
        if n.direction() == dim:
          l.calcStackedSize(c, dim)
        else:
          l.calcOverlayedSize(c, dim)
      else:
        # free layout model
        l.calcOverlayedSize(c, dim)

    # Set our output data size. Will be used by parent calcXxxSize procedures,
    # and by arrange procedures.
    n.computed[wDim] = needSize

proc arrangeStacked(
    l: ptr LayoutObj, c: ptr LayoutCacheObj, dim: static[int], wrap: static[bool]
) {.inline, raises: [].} =
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

      if child.axisAnchorFlags(dim) == LayoutHorizontalFill:
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
        filler = extraSpace / float(count)
      elif total > 0:
        case n.boxFlags and LayoutBoxJustify
        of LayoutBoxJustify:
          # justify when not wrapping or at least one remaining element
          if not wrap or (itemCount > 0 or expandRangeEnd != arrangeRangeEnd):
            spacer = extraSpace / float(total - 1)
        of LayoutBoxStart:
          discard
        of LayoutBoxEnd:
          extraMargin = extraSpace
        else:
          extraMargin = extraSpace / 2
    else:
      when not wrap:
        if extraSpace < 0 and squeezedCount > 0:
          eater = extraSpace / float(squeezedCount)

    # distribute width among items
    var x = computed[dim]
    var x1 = 0f

    # second pass: distribute and rescale
    for idx in arrangeRangeBegin ..< expandRangeEnd:
      let child = l.caches[idx].node

      x += child.computed[dim] + extraMargin
      if child.axisAnchorFlags(dim) == LayoutHorizontalFill:
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

proc arrangeOverlay(
    l: ptr LayoutObj, c: ptr LayoutCacheObj, dim: static[int]
) {.inline, raises: [].} =
  const wDim = dim + 2

  let n = c.node
  let offset = n.computed[dim]
  let space = n.computed[wDim]

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    case child.axisAnchorFlags(dim)
    of LayoutHorizontalFill:
      child.computed[wDim] = max(0f, space - child.computed[dim] - child.margin[wDim])
    of LayoutRight:
      child.computed[dim] =
        child.computed[dim] + space - child.computed[wDim] - child.margin[dim] -
        child.margin[wDim]
    of LayoutLeft:
      discard
    else:
      child.computed[dim] =
        child.computed[dim] +
        max(0f, (space - child.computed[wDim]) / 2 - child.margin[wDim])
    child.computed[dim] = child.computed[dim] + offset

proc arrangeOverlaySqueezedRange(
    l: ptr LayoutObj,
    dim: static[int],
    squeezedRangeBegin, arrangeRangeEnd: uint32,
    offset, space: float,
) {.inline, raises: [].} =
  const wDim = dim + 2

  for idx in squeezedRangeBegin ..< arrangeRangeEnd:
    let child = l.caches[idx].node
    let minSize = max(0f, space - child.computed[dim] - child.margin[wDim])
    case child.axisAnchorFlags(dim)
    of LayoutHorizontalFill:
      child.computed[wDim] = minSize
    of LayoutLeft:
      child.computed[wDim] = min(child.computed[wDim], minSize)
    of LayoutRight:
      child.computed[wDim] = min(child.computed[wDim], minSize)
      child.computed[dim] = space - child.computed[wDim] - child.margin[wDim]
    else:
      child.computed[wDim] = min(child.computed[wDim], minSize)
      child.computed[dim] =
        child.computed[dim] +
        max(0f, (space - child.computed[wDim]) / 2 - child.margin[wDim])
    child.computed[dim] = child.computed[dim] + offset

proc arrangeWrappedOverlaySqueezed(
    l: ptr LayoutObj, c: ptr LayoutCacheObj, dim: static[int]
): float {.inline, raises: [].} =
  const wDim = dim + 2

  let n = c.node

  var offset = n.computed[dim]
  var needSize = 0f

  var squeezedRangeBegin = c.childOffset

  for idx in c.childOffset ..< c.childOffset + c.childCount:
    let child = l.caches[idx].node
    if child.isBreak:
      l.arrangeOverlaySqueezedRange(dim, squeezedRangeBegin, idx, offset, needSize)
      offset = offset + needSize
      squeezedRangeBegin = idx
      needSize = 0

    let childSize = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(needSize, childSize)

  l.arrangeOverlaySqueezedRange(
    dim, squeezedRangeBegin, c.childOffset + c.childCount, offset, needSize
  )
  offset + needSize

proc arrange(
    l: ptr LayoutObj, c: ptr LayoutCacheObj, dim: static[int]
) {.inline, raises: [].} =
  const wDim = dim + 2

  let n = c.node

  case n.model
  of LayoutBoxColumn or LayoutBoxWrap:
    if dim > 0:
      assert n.isSkipXAxis

      # The X-axis are recalculated here.
      l.arrangeStacked(c, 1, true)
      let offset = l.arrangeWrappedOverlaySqueezed(c, 0)
      n.computed[2] = offset - n.computed[0]
  of LayoutBoxRow or LayoutBoxWrap:
    if dim > 0:
      discard l.arrangeWrappedOverlaySqueezed(c, 1)
    else:
      l.arrangeStacked(c, 0, true)
  of LayoutBoxColumn, LayoutBoxRow:
    if n.direction() == dim:
      l.arrangeStacked(c, dim, false)
    else:
      l.arrangeOverlaySqueezedRange(
        dim,
        c.childOffset,
        c.childOffset + c.childCount,
        n.computed[dim],
        n.computed[wDim],
      )
  else:
    l.arrangeOverlay(c, dim)

proc arrange(l: ptr LayoutObj, dim: static[int]) {.inline, raises: [].} =
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

proc compute*(l: ptr LayoutObj, n: ptr LayoutNodeObj) {.inline, raises: [].} =
  n.isSkipXAxis = false

  l.caches.add(LayoutCacheObj(node: n))

  var idx = 0

  # Cache the results of the breadth-first traversal. 
  # For subsequent calculations, you can directly access the child nodes using subscripts.
  while idx < l.caches.len:
    let n = l.caches[idx].node
    let childOffset = uint32(l.caches.len)

    if n.model == int(LayoutBoxColumn or LayoutBoxWrap):
      # delayed calculations are required
      n.isSkipXAxis = true

    n.isBreak = false

    var count = 0
    let isSkipXAxis = n.isSkipXAxis

    for child in l.children(n):
      inc count, 1

      child.isSkipXAxis = isSkipXAxis
      l.caches.add(LayoutCacheObj(node: child))

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
