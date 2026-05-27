import buju
import buju/core

import ./nodes
import ./reader

const
  MAX_NODES_COUNT = high(int32) - 1
  MAX_NODE_SIZE = int32(1000)

type
  Action* = enum
    NEW
    SET_LAYOUT
    SET_ALIGN
    SET_MAIN_AXIS_ALIGN
    SET_CROSS_AXIS_ALIGN
    SET_CROSS_AXIS_LINE_ALIGN
    SET_WRAP
    SET_SIZE
    SET_GAP
    SET_MARGIN
    SET_PADDING
    INSERT_CHILD
    REMOVE_CHILD
    COMPUTE

  ActionParam* = object
    action*: Action
    nodeId1*: int32 # SET_LAYOUT, SET_ALIGN, SET_MAIN_AXIS_ALIGN, SET_CROSS_AXIS_ALIGN, SET_CROSS_AXIS_LINE_ALIGN,
                      # SET_WRAP, SET_SIZE, SET_GAP, SET_MARGIN, SET_PADDING, INSERT_CHILD, REMOVE_CHILD, COMPUTE,
    nodeId2*: int32                         # INSERT_CHILD, REMOVE_CHILD
    layout*: Layout                         # SET_LAYOUT
    aligns*: set[Align]                     # SET_ALIGN
    mainAxisAlign*: MainAxisAlign           # SET_MAIN_AXIS_ALIGN
    crossAxisAlign*: CrossAxisAlign         # SET_CROSS_AXIS_ALIGN
    crossAxisLineAlign*: CrossAxisLineAlign # SET_CROSS_AXIS_LINE_ALIGN
    wrap*: Wrap                             # SET_WRAP
    size*: array[2, float32]                # SET_SIZE
    gap*: array[2, float32]                 # SET_GAP
    margin*: array[4, float32]              # SET_MARGIN
    padding*: array[4, float32]             # SET_PADDING

proc s(args: varargs[string, `$`]): string {.inline.} =
  for a in args:
    result.add(a)

proc `$`*(param: ActionParam): string =
  case param.action:
  of NEW:
    "NEW"

  of SET_LAYOUT:
    let
      n = cast[NodeID](param.nodeId1)
      layout = param.layout

    s "SET_LAYOUT: ", n, " ", layout

  of SET_ALIGN:
    let
      n = cast[NodeID](param.nodeId1)
      aligns = param.aligns

    s "SET_ALIGN: ", n, " ", aligns

  of SET_MAIN_AXIS_ALIGN:
    let
      n = cast[NodeID](param.nodeId1)
      mainAxisAlign = param.mainAxisAlign

    s "SET_MAIN_AXIS_ALIGN: ", n, " ", mainAxisAlign

  of SET_CROSS_AXIS_ALIGN:
    let
      n = cast[NodeID](param.nodeId1)
      crossAxisAlign = param.crossAxisAlign

    s "SET_CROSS_AXIS_ALIGN: ", n, " ", crossAxisAlign

  of SET_CROSS_AXIS_LINE_ALIGN:
    let
      n = cast[NodeID](param.nodeId1)
      crossAxisLineAlign = param.crossAxisLineAlign

    s "SET_CROSS_AXIS_LINE_ALIGN: ", n, " ", crossAxisLineAlign

  of SET_WRAP:
    let
      n = cast[NodeID](param.nodeId1)
      wrap = param.wrap

    s "SET_WRAP: ", n, " ", wrap

  of SET_SIZE:
    let
      n = cast[NodeID](param.nodeId1)
      size = param.size

    s "SET_SIZE: ", n, " ", size

  of SET_GAP:
    let
      n = cast[NodeID](param.nodeId1)
      gap = param.gap

    s "SET_GAP: ", n, " ", gap

  of SET_MARGIN:
    let
      n = cast[NodeID](param.nodeId1)
      margin = param.margin

    s "SET_MARGIN: ", n, " ", margin

  of SET_PADDING:
    let
      n = cast[NodeID](param.nodeId1)
      padding = param.padding

    s "SET_PADDING: ", n, " ", padding

  of INSERT_CHILD:
    let
      n1 = cast[NodeID](param.nodeId1)
      n2 = cast[NodeID](param.nodeId2)

    s "INSERT_CHILD: ", n1, " ", n2

  of REMOVE_CHILD:
    let
      n1 = cast[NodeID](param.nodeId1)
      n2 = cast[NodeID](param.nodeId2)

    s "REMOVE_CHILD: ", n1, " ", n2

  of COMPUTE:
    let
      n = cast[NodeID](param.nodeId1)

    s "COMPUTE: ", n

iterator actions*(data: openArray[byte]): ActionParam =
  var
    p = default(Reader)

  if data.len > 0:
    p.buffer = cast[ptr UncheckedArray[byte]](data[0].addr)
    p.len = int32(data.len)

  while not p.empty:
    var
      param: ActionParam
    param.action = p.next(Action)

    case param.action:
    of NEW:
      discard

    of SET_LAYOUT:
      param.nodeId1 = p.next(int32, 0)
      param.layout = p.next(Layout)

    of SET_ALIGN:
      param.nodeId1 = p.next(int32, 0)

      let
        count = p.next(int32, 0, 4)
      for idx in 0 ..< count:
        let
          align = p.next(Align)
        param.aligns.incl(align)

    of SET_MAIN_AXIS_ALIGN:
      param.nodeId1 = p.next(int32, 0)
      param.mainAxisAlign = p.next(MainAxisAlign)

    of SET_CROSS_AXIS_ALIGN:
      param.nodeId1 = p.next(int32, 0)
      param.crossAxisAlign = p.next(CrossAxisAlign)

    of SET_CROSS_AXIS_LINE_ALIGN:
      param.nodeId1 = p.next(int32, 0)
      param.crossAxisLineAlign = p.next(CrossAxisLineAlign)

    of SET_WRAP:
      param.nodeId1 = p.next(int32, 0)
      param.wrap = p.next(Wrap)

    of SET_SIZE:
      param.nodeId1 = p.next(int32, 0)

      let
        w = p.next(int32, 0, MAX_NODE_SIZE)
        h = p.next(int32, 0, MAX_NODE_SIZE)

      param.size = [float32(w), float32(h)]

    of SET_GAP:
      param.nodeId1 = p.next(int32, 0)

      let
        w = p.next(int32, 0, MAX_NODE_SIZE)
        h = p.next(int32, 0, MAX_NODE_SIZE)

      param.gap = [float32(w), float32(h)]

    of SET_MARGIN:
      param.nodeId1 = p.next(int32, 0)

      let
        l = p.next(int32, 0, MAX_NODE_SIZE)
        t = p.next(int32, 0, MAX_NODE_SIZE)
        r = p.next(int32, 0, MAX_NODE_SIZE)
        b = p.next(int32, 0, MAX_NODE_SIZE)

      param.margin = [float32(l), float32(t), float32(r), float32(b)]

    of SET_PADDING:
      param.nodeId1 = p.next(int32, 0)

      let
        l = p.next(int32, 0, MAX_NODE_SIZE)
        t = p.next(int32, 0, MAX_NODE_SIZE)
        r = p.next(int32, 0, MAX_NODE_SIZE)
        b = p.next(int32, 0, MAX_NODE_SIZE)

      param.padding = [float32(l), float32(t), float32(r), float32(b)]

    of INSERT_CHILD:
      param.nodeId1 = p.next(int32, 0)
      param.nodeId2 = p.next(int32, 0)

    of REMOVE_CHILD:
      param.nodeId1 = p.next(int32, 0)
      param.nodeId2 = p.next(int32, 0)

    of COMPUTE:
      param.nodeId1 = p.next(int32, 0)

    yield param

proc node1*(ctx: Context, param: ActionParam): NodeID =
  if ctx.nodes.len <= 0:
    return

  let
    idx = param.nodeId1 mod ctx.nodes.len
    n = cast[NodeID](idx + 1)
  n

proc node2*(ctx: Context, param: ActionParam): NodeID =
  if ctx.nodes.len <= 0:
    return

  let
    idx = param.nodeId2 mod ctx.nodes.len
    n = cast[NodeID](idx + 1)
  n

proc doAction*(ctx: var Context, param: ActionParam) =
  if ctx.nodes.len == 0:
    discard ctx.node()

  case param.action:
  of NEW:
    if ctx.nodes.len < MAX_NODES_COUNT:
      let
        n = ctx.node()

      when defined(bujuDumpAction):
        echo "NEW: ", n
      else:
        discard n

  of SET_LAYOUT:
    let
      n = ctx.node1(param)
      layout = param.layout

    when defined(bujuDumpAction):
      echo "SET_LAYOUT: ", n, " ", layout

    ctx.setLayout(n, layout)

  of SET_ALIGN:
    let
      n = ctx.node1(param)
      aligns = param.aligns

    when defined(bujuDumpAction):
      echo "SET_ALIGN: ", n, " ", aligns

    ctx.setAlign(n, aligns)

  of SET_MAIN_AXIS_ALIGN:
    let
      n = ctx.node1(param)
      mainAxisAlign = param.mainAxisAlign

    when defined(bujuDumpAction):
      echo "SET_MAIN_AXIS_ALIGN: ", n, " ", mainAxisAlign

    ctx.setMainAxisAlign(n, mainAxisAlign)

  of SET_CROSS_AXIS_ALIGN:
    let
      n = ctx.node1(param)
      crossAxisAlign = param.crossAxisAlign

    when defined(bujuDumpAction):
      echo "SET_CROSS_AXIS_ALIGN: ", n, " ", crossAxisAlign

    ctx.setCrossAxisAlign(n, crossAxisAlign)

  of SET_CROSS_AXIS_LINE_ALIGN:
    let
      n = ctx.node1(param)
      crossAxisLineAlign = param.crossAxisLineAlign

    when defined(bujuDumpAction):
      echo "SET_CROSS_AXIS_LINE_ALIGN: ", n, " ", crossAxisLineAlign

    ctx.setCrossAxisLineAlign(n, crossAxisLineAlign)

  of SET_WRAP:
    let
      n = ctx.node1(param)
      wrap = param.wrap

    when defined(bujuDumpAction):
      echo "SET_WRAP: ", n, " ", wrap

    ctx.setWrap(n, wrap)

  of SET_SIZE:
    let
      n = ctx.node1(param)
      size = param.size

    when defined(bujuDumpAction):
      echo "SET_SIZE: ", n, " ", size

    ctx.setSize(n, size)

  of SET_GAP:
    let
      n = ctx.node1(param)
      gap = param.gap

    when defined(bujuDumpAction):
      echo "SET_GAP: ", n, " ", gap

    ctx.setGap(n, gap)

  of SET_MARGIN:
    let
      n = ctx.node1(param)
      margin = param.margin

    when defined(bujuDumpAction):
      echo "SET_MARGIN: ", n, " ", margin

    ctx.setMargin(n, margin)

  of SET_PADDING:
    let
      n = ctx.node1(param)
      padding = param.padding

    when defined(bujuDumpAction):
      echo "SET_PADDING: ", n, " ", padding

    ctx.setPadding(n, padding)

  of INSERT_CHILD:
    let
      n1 = ctx.node1(param)
      n2 = ctx.node2(param)

    var
      isSkip = false

    if n1 == n2 or ctx.hasChild(n2, n1):
      isSkip = true

    let
      pn = ctx.getParent(n2)
    if not pn.isNil:
      isSkip = true

    when defined(bujuDumpAction):
      echo "INSERT_CHILD: ", n1, " ", n2, " isSkip: ", isSkip

    if not isSkip:
      ctx.insertChild(n1, n2)

  of REMOVE_CHILD:
    let
      n1 = ctx.node1(param)
      n2 = ctx.node2(param)

    var
      isSkip = false

    if n1 == n2 or not ctx.hasDirectChild(n1, n2):
      isSkip = true

    let
      pn = ctx.getParent(n2)
    if pn.isNil:
      isSkip = true

    when defined(bujuDumpAction):
      echo "REMOVE_CHILD: ", n1, " ", n2, " isSkip: ", isSkip

    if not isSkip:
      ctx.removeChild(n1, n2)

  of COMPUTE:
    let
      n = ctx.node1(param)

    when defined(bujuDumpAction):
      echo "COMPUTE: ", n

    ctx.compute(n)

