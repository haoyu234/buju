import vmath

type
  LayoutNodeID* {.size: 4.} = enum
    NIL

  LayoutNodeObj* = object
    isBreak: bool
    boxFlags*: uint8
    layoutFlags*: uint8

    id*: LayoutNodeID
    firstChild*: LayoutNodeID
    lastChild*: LayoutNodeID
    prevSibling*: LayoutNodeID
    nextSibling*: LayoutNodeID

    computed*: Vec4
    margin*: Vec4
    size*: Vec2

  LayoutObj* = object
    nodes*: seq[LayoutNodeObj]

const
  # layout
  LayoutLeft* = 0x01
  LayoutTop* = 0x02
  LayoutRight* = 0x04
  LayoutBottom* = 0x08
  LayoutHorizontalFill* = LayoutLeft or LayoutRight
  LayoutVerticalFill* = LayoutTop or LayoutBottom
  LayoutFill* = LayoutHorizontalFill or LayoutVerticalFill

  # box
  LayoutBoxWrap* = 0x004
  LayoutBoxStart* = 0x008
  LayoutBoxMiddle* = 0x000
  LayoutBoxEnd* = 0x010
  LayoutBoxJustify* = LayoutBoxStart or LayoutBoxMiddle or LayoutBoxEnd

  LayoutBoxRow* = 0x002
  LayoutBoxColumn* = 0x003

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

proc lastChild*(
  l: ptr LayoutObj, n: ptr LayoutNodeObj): ptr LayoutNodeObj {.inline, raises: [].} =
  let id = n.lastChild
  if not id.isNil:
    return l.node(id)

proc nextSibling*(
  l: ptr LayoutObj, n: ptr LayoutNodeObj): ptr LayoutNodeObj {.inline, raises: [].} =
  let id = n.nextSibling
  if not id.isNil:
    return l.node(id)

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

  for child in l.children(n):
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    result = result + size

proc calcOverlayedSize(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]): float {.raises: [].} =
  const wDim = dim + 2

  for child in l.children(n):
    let size = child.computed[dim] + child.computed[wDim] + child.margin[wDim]
    result = max(size, result)

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

proc calcSize(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]) {.raises: [].} =
  const wDim = dim + 2

  when dim <= 0:
    n.isBreak = false

  for child in l.children(n):
    l.calcSize(child, dim)

  n.computed[dim] = n.margin[dim]

  if n.size[dim] > 0:
    n.computed[wDim] = n.size[dim]
    return

  n.computed[wDim] =
    case n.model:
    of LayoutBoxColumn or LayoutBoxWrap:
      if dim > 0:
        l.calcStackedSize(n, 1)
      else:
        l.calcOverlayedSize(n, 0)
    of LayoutBoxRow or LayoutBoxWrap:
      if dim > 0:
        l.calcWrappedOverlayedSize(n, 1)
      else:
        l.calcWrappedStackedSize(n, 0)
    of LayoutBoxColumn, LayoutBoxRow:
      if n.direction() == dim:
        l.calcStackedSize(n, dim)
      else:
        l.calcOverlayedSize(n, dim)
    else:
      l.calcOverlayedSize(n, dim)

proc arrangeStacked(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int],
      wrap: bool) {.raises: [].} =
  const wDim = dim + 2

  let computed = n.computed
  let space = computed[wDim]
  let maxX2 = computed[dim] + space
  let firstChild = l.firstChild(n)

  var startChild = firstChild
  while not startChild.isNil:
    var used = 0f
    var count = 0
    var squeezedCount = 0
    var total = 0
    var itemCount = 0

    var child = startChild
    var endChild: ptr LayoutNodeObj = nil

    while not child.isNil:
      inc itemCount
      var extend = used + child.computed[dim] + child.margin[wDim]

      if (child.layoutFlagsDim(dim) and LayoutHorizontalFill) == LayoutHorizontalFill:
        inc count
      else:
        if child.size[dim] <= 0:
          inc squeezedCount
        extend = extend + child.computed[wDim]

      if wrap and total > 0 and extend > space:
        endChild = child
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
        case n.boxFlags and LayoutBoxJustify:
        of LayoutBoxJustify:
          if not wrap or (itemCount > 0 or not endChild.isNil):
            spacer = extraSpace / float(total - 1)
        of LayoutBoxStart:
          discard
        of LayoutBoxEnd:
          extraMargin = extraSpace
        else:
          extraMargin = extraSpace / 2
    elif not wrap and extraSpace < 0:
      eater = extraSpace / float(squeezedCount)

    var x = computed[dim]
    var x1 = 0f

    while not child.isNil and child != endChild:
      x += child.computed[dim] + extraMargin
      if (child.layoutFlagsDim(dim) and LayoutHorizontalFill) == LayoutHorizontalFill:
        x1 = x + filler
      elif child.size[dim] > 0:
        x1 = x + child.computed[wDim]
      else:
        x1 = x + max(0f, child.computed[wDim] + eater)

      let ix0 = x
      let ix1 = if wrap:
        min(maxX2 - child.margin[wDim], x1)
      else:
        x1

      child.computed[dim] = ix0
      child.computed[wDim] = ix1 - ix0

      extraMargin = spacer
      x = x1 + child.margin[wDim]

      child = l.nextSibling(child)

proc arrangeOverlay(
  l: ptr LayoutObj, n: ptr LayoutNodeObj, dim: static[int]) {.raises: [].} =
  const wDim = dim + 2

  let offset = n.computed[dim]
  let space = n.computed[wDim]

  for child in l.children(n):
    case child.layoutFlagsDim(dim) and LayoutHorizontalFill:
    of LayoutHorizontalFill:
      child.computed[wDim] = max(0f, space - child.computed[dim] - child.margin[wDim])
    of LayoutRight:
      child.computed[dim] = child.computed[dim] + space - child.computed[wDim] -
          child.margin[dim] - child.margin[wDim]
    of LayoutLeft:
      discard
    else:
      child.computed[dim] = child.computed[dim] + max(0f, (space -
          child.computed[wDim]) / 2 - child.margin[wDim])
    child.computed[dim] = child.computed[dim] + offset

proc arrangeOverlaySqueezedRange(
  l: ptr LayoutObj, dim: static[int],
  startChild, endChild: ptr LayoutNodeObj, offset, space: float) {.raises: [].} =
  const wDim = dim + 2

  var child = startChild
  while not child.isNil and child != endChild:
    let minSize = max(0f, space - child.computed[dim] - child.margin[wDim])
    case child.layoutFlagsDim(dim) and LayoutHorizontalFill:
    of LayoutHorizontalFill:
      child.computed[wDim] = minSize
    of LayoutLeft:
      child.computed[wDim] = min(child.computed[wDim], minSize)
    of LayoutRight:
      child.computed[wDim] = min(child.computed[wDim], minSize)
      child.computed[dim] = space - child.computed[wDim] - child.margin[wDim]
    else:
      child.computed[wDim] = min(child.computed[wDim], minSize)
      child.computed[dim] = child.computed[dim] + max(0f, (space -
          child.computed[wDim]) / 2 - child.margin[wDim])
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

  case n.model:
  of LayoutBoxColumn or LayoutBoxWrap:
    if dim > 0:
      l.arrangeStacked(n, 1, true)
      let offset = l.arrangeWrappedOverlaySqueezed(n, 0)
      n.computed[2] = offset - n.computed[0]
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

  for child in l.children(n):
    l.arrange(child, dim)

proc compute*(l: ptr LayoutObj, n: ptr LayoutNodeObj) {.inline, raises: [].} =
  template computeDim(dim) =
    l.calcSize(n, dim)
    l.arrange(n, dim)

  computeDim(0)
  computeDim(1)
