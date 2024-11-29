import vmath

type
  LayoutNodeID* {.size: 4.} = enum ## Node id, avoid using pointers and references
    NIL

  LayoutNodeObj* = object ## Layout node type
    isBreak: bool         ## whether an item's children have already been wrapped
    boxFlags*: uint8      ## determines how it behaves as a parent.
    layoutFlags*: uint8   ## determines how it behaves as a child inside of a parent item.

    firstChild*: LayoutNodeID
    lastChild*: LayoutNodeID
    prevSibling*: LayoutNodeID
    nextSibling*: LayoutNodeID

    computed*: Vec4       ## the calculated rectangle of an item.
    margin*: Vec4
    size*: Vec2

  LayoutObj* = object
    nodes*: seq[LayoutNodeObj]

const
  # layout, default is center in both directions, with left/top margin as offset.
  LayoutLeft* = 0x01       ## anchor to left item or left side of parent
  LayoutTop* = 0x02        ## anchor to top item or top side of parent
  LayoutRight* = 0x04      ## anchor to right item or right side of parent
  LayoutBottom* = 0x08     ## anchor to bottom item or bottom side of parent
  LayoutHorizontalFill* = LayoutLeft or LayoutRight ## anchor to both left and right item or parent borders
  LayoutVerticalFill* = LayoutTop or LayoutBottom ## anchor to both top and bottom item or parent borders
  LayoutFill* = LayoutHorizontalFill or LayoutVerticalFill ## anchor to all four directions

  # flex-wrap, the default is single-line.
  LayoutBoxWrap* = 0x004   ## multi-line, wrap left to right

  # justify-content (start, end, center, space-between), the default is center.
  LayoutBoxStart* = 0x008  ## at start of row/column
  LayoutBoxEnd* = 0x010    ## at end of row/column
  LayoutBoxJustify* = LayoutBoxStart or LayoutBoxEnd ## insert spacing to stretch across whole row/column

  # flex-direction, default is free layout.
  LayoutBoxRow* = 0x002    ## left to right
  LayoutBoxColumn* = 0x003 ## top to bottom

proc isNil*(id: LayoutNodeID): bool {.inline.} =
  id == NIL

template node*(
  l: ptr LayoutObj, id: LayoutNodeID): ptr LayoutNodeObj =
  l.nodes[uint(id) - 1].addr

template model(n: ptr LayoutNodeObj): int =
  int(n.boxFlags and 0x7)

template direction(n: ptr LayoutNodeObj): int =
  int(n.boxFlags and 0x1)

template layoutFlagsDim(
  n: ptr LayoutNodeObj, dim: static[int]): int =
  int(n.layoutFlags and 0x1F) shr dim

proc firstChild*(
  l: ptr LayoutObj, n: ptr LayoutNodeObj): ptr LayoutNodeObj {.inline, raises: [].} =
  let id = n.firstChild
  if not id.isNil:
    return l.node(id)
  return nil

proc lastChild*(
  l: ptr LayoutObj, n: ptr LayoutNodeObj): ptr LayoutNodeObj {.inline, raises: [].} =
  let id = n.lastChild
  if not id.isNil:
    return l.node(id)
  return nil

proc nextSibling*(
  l: ptr LayoutObj, n: ptr LayoutNodeObj): ptr LayoutNodeObj {.inline, raises: [].} =
  let id = n.nextSibling
  if not id.isNil:
    return l.node(id)
  return nil

iterator children*(
  l: ptr LayoutObj, n: ptr LayoutNodeObj): ptr LayoutNodeObj {.inline, raises: [].} =
  var id = n.firstChild
  while not id.isNil:
    let node = l.node(id)
    id = node.nextSibling
    yield node

proc calcStackedSize(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]): float {.raises: [].} =
  const wDim = dim + 2

  var needSize = 0f

  for child in l.children(n):
    # width = start margin + calculated width + end margin
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = needSize + size
  needSize

proc calcOverlayedSize(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]): float {.raises: [].} =
  const wDim = dim + 2

  var needSize = 0f

  for child in l.children(n):
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(size, needSize)
  needSize

proc calcWrappedOverlayedSize(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]): float {.raises: [].} =
  const wDim = dim + 2

  var needSize = 0f
  var needSize2 = 0f
  for child in l.children(n):
    if child.isBreak:
      needSize2 = needSize2 + needSize
      needSize = 0
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(needSize, size)
  needSize + needSize2

proc calcWrappedStackedSize(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]): float {.raises: [].} =
  const wDim = dim + 2

  var needSize = 0f
  var needSize2 = 0f
  for child in l.children(n):
    if child.isBreak:
      needSize2 = max(needSize2, needSize)
      needSize = 0
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = needSize + size
  max(needSize2, needSize)

proc calcSize(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]) {.raises: [].} =
  const wDim = dim + 2

  when dim <= 0:
    n.isBreak = false

  for child in l.children(n):
    # NOTE: this is recursive and will run out of stack space if items are nested too deeply.
    l.calcSize(child, dim)

  # Set the mutable rect output data to the starting input data
  n.computed[dim] = n.margin[dim]

  # If we have an explicit input size, just set our output size (which other
  # calcXxxSize and arrange procedures will use) to it.
  if n.size[dim] > 0:
    n.computed[wDim] = n.size[dim]
    return

  # Calculate our size based on children items. Note that we've already
  # called calcSize on our children at this point.
  let needSize =
    case n.model
    of LayoutBoxColumn or LayoutBoxWrap:
      # flex model
      when dim > 0:
        l.calcStackedSize(n, 1)
      else:
        l.calcOverlayedSize(n, 0)
    of LayoutBoxRow or LayoutBoxWrap:
      # flex model
      when dim > 0:
        l.calcWrappedOverlayedSize(n, 1)
      else:
        l.calcWrappedStackedSize(n, 0)
    of LayoutBoxColumn, LayoutBoxRow:
      # flex model
      if n.direction() == dim:
        l.calcStackedSize(n, dim)
      else:
        l.calcOverlayedSize(n, dim)
    else:
      # layout model
      l.calcOverlayedSize(n, dim)

  # Set our output data size. Will be used by parent calcXxxSize procedures,
  # and by arrange procedures.
  n.computed[wDim] = needSize

proc arrangeStacked(
  l: ptr LayoutObj, n: ptr LayoutNodeObj,
  dim: static[int], wrap: static[bool]) {.raises: [].} =
  const wDim = dim + 2

  let computed = n.computed
  let space = computed[wDim]
  let firstChild = l.firstChild(n)

  when wrap:
    let maxX2 = computed[dim] + space

  var startChild = firstChild
  while not startChild.isNil:
    var used = 0f

    # count of fillers
    var count = 0

    # count of squeezable elements
    var squeezedCount = 0
    var total = 0
    var itemCount = 0

    var child = startChild
    var endChild: ptr LayoutNodeObj = nil

    # first pass: count items that need to be expanded, and the space that is used
    while not child.isNil:
      inc itemCount
      var extend = used + child.computed[dim] + child.margin[wDim]

      if (child.layoutFlagsDim(dim) and LayoutHorizontalFill) == LayoutHorizontalFill:
        inc count
      else:
        if child.size[dim] <= 0:
          inc squeezedCount
        extend = extend + child.computed[wDim]

      when wrap:
        # wrap on end of line
        if total > 0 and extend > space:
          endChild = child

          # add marker for subsequent queries
          child.isBreak = true
          itemCount = 0
          break

      inc total
      used = extend
      child = l.nextSibling(child)

    child = startChild
    startChild = endChild

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
          if not wrap or (itemCount > 0 or not endChild.isNil):
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
    while not child.isNil and child != endChild:
      x += child.computed[dim] + extraMargin
      if (child.layoutFlagsDim(dim) and LayoutHorizontalFill) == LayoutHorizontalFill:
        # grow
        x1 = x + filler
      elif child.size[dim] > 0:
        x1 = x + child.computed[wDim]
      else:
        # squeeze
        x1 = x + max(0f, child.computed[wDim] + eater)

      let ix0 = x
      let ix1 = when wrap:
        min(maxX2 - child.margin[wDim], x1)
      else:
        x1

      child.computed[dim] = ix0 # pos
      child.computed[wDim] = ix1 - ix0 # size

      extraMargin = spacer
      x = x1 + child.margin[wDim]

      child = l.nextSibling(child)

proc arrangeOverlay(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]) {.raises: [].} =
  const wDim = dim + 2

  let offset = n.computed[dim]
  let space = n.computed[wDim]

  for child in l.children(n):
    case child.layoutFlagsDim(dim) and LayoutHorizontalFill
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
  l: ptr LayoutObj, dim: static[int],
  startChild, endChild: ptr LayoutNodeObj, offset, space: float) {.raises: [].} =
  const wDim = dim + 2

  var child = startChild
  while not child.isNil and child != endChild:
    let minSize = max(0f, space - child.computed[dim] - child.margin[wDim])
    case child.layoutFlagsDim(dim) and LayoutHorizontalFill
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
    child = l.nextSibling(child)

proc arrangeWrappedOverlaySqueezed(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]): float {.raises: [].} =
  const wDim = dim + 2

  var offset = n.computed[dim]
  var needSize = 0f

  var child = l.firstChild(n)
  var startChild = child

  while not child.isNil:
    if child.isBreak:
      l.arrangeOverlaySqueezedRange(dim, startChild, child, offset, needSize)
      offset = offset + needSize
      startChild = child
      needSize = 0

    let childSize = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    needSize = max(needSize, childSize)
    child = l.nextSibling(child)

  l.arrangeOverlaySqueezedRange(dim, startChild, nil, offset, needSize)
  offset + needSize

proc arrange(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]) {.raises: [].} =
  const wDim = dim + 2

  case n.model
  of LayoutBoxColumn or LayoutBoxWrap:
    if dim > 0:
      # The x-coordinates are recalculated here.
      l.arrangeStacked(n, 1, true)
      let offset = l.arrangeWrappedOverlaySqueezed(n, 0)
      n.computed[2] = offset - n.computed[0]

      # We should recalculate the x-coordinates for all children.
      # NOTE: this is recursive and will run out of stack space if items are
      # nested too deeply.
      for child in l.children(n):
        l.arrange(child, 0)
    else:
      return
  of LayoutBoxRow or LayoutBoxWrap:
    if dim > 0:
      discard l.arrangeWrappedOverlaySqueezed(n, 1)
    else:
      l.arrangeStacked(n, 0, true)
  of LayoutBoxColumn, LayoutBoxRow:
    if n.direction() == dim:
      l.arrangeStacked(n, dim, false)
    else:
      l.arrangeOverlaySqueezedRange(
        dim, l.firstChild(n), nil, n.computed[dim], n.computed[wDim])
  else:
    l.arrangeOverlay(n, dim)

  # NOTE: this is recursive and will run out of stack space if items are
  # nested too deeply.
  for child in l.children(n):
    l.arrange(child, dim)

proc compute*(l: ptr LayoutObj, n: ptr LayoutNodeObj) {.inline, raises: [].} =
  template computeDim(dim) =
    l.calcSize(n, dim)
    l.arrange(n, dim)

  computeDim(0)
  computeDim(1)
