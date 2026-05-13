import buju
import buju/core

import ./reader
import ./writer

proc getParent*(ctx: Context, nodeID: NodeID): NodeID =
  when defined(debug):
    let
      n = ctx.addr.node(nodeID)
    if not n.isNil:
      result = n.parent
  else:
    for idx in 0 ..< ctx.nodes.len:
      let
        parentID = cast[NodeID](idx + 1)

      for child in ctx.children(parentID):
        if child == nodeID:
          result = parentID
          break

proc getRoot*(ctx: Context, nodeID: NodeID): NodeID =
  result = nodeID

  while true:
    let
      n = ctx.getParent(result)
    if n.isNil:
      break

    result = n

proc hasChild*(ctx: Context, parentID, childID: NodeID): bool =
  var
    c = childID
  while not c.isNil:
    let
      pn = ctx.getParent(c)
    if pn == parentID:
      result = true
      break

    c = pn

proc hasDirectChild*(ctx: Context, parentID, childID: NodeID): bool =
  parentID == ctx.getParent(childID)

proc collectChildren(ctx: Context, nodeID: NodeID, nodes: var seq[NodeID]) =
  for child in ctx.children(nodeID):
    nodes.add(child)
    ctx.collectChildren(child, nodes)

proc getChildren*(ctx: Context, nodeID: NodeID): seq[NodeID] =
  collectChildren(ctx, nodeID, result)

proc getTree*(ctx: Context, nodeID: NodeID): seq[NodeID] =
  let
    root = ctx.getRoot(nodeID)
  ctx.collectChildren(root, result)

proc dumpParams*(l: Context) =
  when defined(debug):
    for idx in 0 ..< l.nodes.len:
      let
        n = l.nodes[idx].addr
      echo "n: ", n.id, " parent: ", n.parent, " firstChild: ", n.firstChild,
          " lastChild: ", n.lastChild, " nextSibling: ", n.nextSibling,
          " prevSibling: ", n.prevSibling, " layout:", n.layout, " wrap:",
              n.wrap, " mainAxisAlign:", n.mainAxisAlign, " crossAxisAlign:",
              n.crossAxisAlign, " crossAxisLineAlign:", n.crossAxisLineAlign,
              " align:", n.align, " size:", n.size, " gap:", n.gap, " margin:",
              n.margin, " padding:", n.padding

proc dumpResult*(l: Context, root: NodeID) =
  let
    computed = l.computed(root)

  echo root, ".computed: ", computed

  for child in l.children(root):
    dumpResult(l, child)

proc dumpResultBinary(l: Context, root: NodeID, writer: var Writer) =
  let
    computed = l.computed(root)

  writer.next(int32(root))

  for val in computed:
    writer.next(int32(val * 10))

  for child in l.children(root):
    dumpResultBinary(l, child, writer)

proc dumpResultBinary*(l: Context, root: NodeID): seq[byte] =
  var
    writer = Writer()
  dumpResultBinary(l, root, writer)
  writer.buffer

proc dumpDiffResultBinary*(data1: openArray[byte], data2: openArray[byte]) =
  var
    idx = int32(0)
    reader1 = Reader(
      buffer: cast[ptr UncheckedArray[byte]](data1[0].addr),
      len: int32(data1.len))
    reader2 = Reader(
      buffer: cast[ptr UncheckedArray[byte]](data2[0].addr),
      len: int32(data2.len))

  while not reader1.empty and not reader2.empty:
    inc idx, 1

    let
      id1 = cast[NodeID](reader1.next(int32, 0))
      id2 = cast[NodeID](reader2.next(int32, 0))

    assert id1 == id2

    let
      computed1 = [
        reader1.next(int32),
        reader1.next(int32),
        reader1.next(int32),
        reader1.next(int32),
      ]

      computed2 = [
        reader2.next(int32),
        reader2.next(int32),
        reader2.next(int32),
        reader2.next(int32),
      ]

    if computed1 != computed2:
      echo "id: ", id1, " app1: ", computed1, " app2: ", computed2
    else:
      echo "id: ", id1, " computed: ", computed1
