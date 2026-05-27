import buju
import buju/core

proc getParent*(ctx: Context, nodeId: NodeID): NodeID =
  when defined(debug):
    let
      n = ctx.addr.node(nodeId)
    if not n.isNil:
      result = n.parent
  else:
    for idx in 0 ..< ctx.nodes.len:
      let
        parentId = cast[NodeID](idx + 1)

      for child in ctx.children(parentId):
        if child == nodeId:
          result = parentId
          break

proc getRoot*(ctx: Context, nodeId: NodeID): NodeID =
  result = nodeId

  while true:
    let
      n = ctx.getParent(result)
    if n.isNil:
      break

    result = n

proc contains*(ctx: Context, nodeId: NodeID): bool =
  if int32(nodeId) <= 0 or int32(nodeId) > ctx.nodes.len:
    return

  result = true

proc hasChild*(ctx: Context, parentId, childId: NodeID): bool =
  var
    c = childId
  while not c.isNil:
    let
      pn = ctx.getParent(c)
    if pn == parentId:
      result = true
      break

    c = pn

proc hasDirectChild*(ctx: Context, parentId, childId: NodeID): bool =
  parentId == ctx.getParent(childId)

proc collectChildren(ctx: Context, nodeId: NodeID, nodes: var seq[NodeID]) =
  for child in ctx.children(nodeId):
    nodes.add(child)
    ctx.collectChildren(child, nodes)

proc getChildren*(ctx: Context, nodeId: NodeID): seq[NodeID] =
  collectChildren(ctx, nodeId, result)

proc getRoots*(ctx: Context): seq[NodeID] =
  ## Every tree the replayed action stream left behind, lowest root id first.
  ##
  ## A fuzzed stream almost always builds several disconnected trees, so a
  ## differential has to check all of them: picking one tree leaves most of the
  ## generated structure untested and turns a "no divergence" result into a false
  ## negative. The order is fixed (ascending id) so the serve and the
  ## inspector (`dump`) all walk the same trees in the same sequence and their
  ## dumps line up.
  for idx in 0 ..< ctx.nodes.len:
    let
      id = cast[NodeID](idx + 1)
    if ctx.getParent(id).isNil:
      result.add(id)
