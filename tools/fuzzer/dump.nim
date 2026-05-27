import buju
import buju/core
import buju/dumps

import std/asyncdispatch
import std/os
import std/strformat
import std/strutils
import std/tables

import ./action
import ./browserdiff
import ./diff
import ./nodes
import ./utils
import ./webdriverops

type
  DumpContext = object
    g: int32
    layout: Context
    idMap: Table[NodeID, DumpNodeID]

  DumpNodeID = object
    id: int32
    oldId: NodeID

proc `$`(id: DumpNodeID): string =
  if id.id == 1:
    "root"
  else:
    fmt"n{id.id}"

proc nextId(ctx: var DumpContext, id: NodeID): DumpNodeID =
  inc ctx.g, 1
  result.id = ctx.g
  result.oldId = id
  ctx.idMap[id] = result

proc getId(ctx: var DumpContext, id: NodeID): DumpNodeID =
  ctx.idMap[id]

proc isInt(f: float32): bool =
  float32(int32(f)) == f

proc fmtFloat32(f: float32, first: bool): string =
  if isInt(f):
    if first:
      fmt"float32({int32(f)})"
    else:
      fmt"{int32(f)}"
  else:
    fmt"float32({f})"

proc fmtFloat32Array(data: openArray[float32]): string =
  result = "["
  if data.len > 0:
    result.add(fmtFloat32(data[0], true))
    for i in 1 ..< data.len:
      result.add(", ")
      result.add(fmtFloat32(data[i], false))
  result.add("]")

proc emitNimNode(ctx: var DumpContext, id: DumpNodeID, n: ptr Node) =
  echo fmt"let {id} = l.node()"

  if n.wrap != default(Wrap):
    echo fmt"l.setWrap({id}, {n.wrap})"
  if n.layout != default(Layout):
    echo fmt"l.setLayout({id}, {n.layout})"
  if n.mainAxisAlign != default(MainAxisAlign):
    echo fmt"l.setMainAxisAlign({id}, {n.mainAxisAlign})"
  if n.crossAxisAlign != default(CrossAxisAlign):
    echo fmt"l.setCrossAxisAlign({id}, {n.crossAxisAlign})"
  if n.crossAxisLineAlign != default(CrossAxisLineAlign):
    echo fmt"l.setCrossAxisLineAlign({id}, {n.crossAxisLineAlign})"
  if n.align != default(set[Align]):
    echo fmt"l.setAlign({id}, {n.align})"
  if n.size != default(array[2, float32]):
    echo fmt"l.setSize({id}, {fmtFloat32Array(n.size)})"
  if n.gap != default(array[2, float32]):
    echo fmt"l.setGap({id}, {fmtFloat32Array(n.gap)})"
  if n.margin != default(array[4, float32]):
    echo fmt"l.setMargin({id}, {fmtFloat32Array(n.margin)})"
  if n.padding != default(array[4, float32]):
    echo fmt"l.setPadding({id}, {fmtFloat32Array(n.padding)})"

  if n.prevSibling != default(NodeID) or n.nextSibling != default(NodeID) or
      not ctx.layout.getParent(id.oldId).isNil:
    let
      parentOldId = ctx.layout.getParent(id.oldId)
      parentId = getId(ctx, parentOldId)
    echo fmt"l.insertChild({parentId}, {id})"

proc emitNimWalk(ctx: var DumpContext, root: NodeID) =
  let
    n = ctx.layout.addr.node(root)
    id = ctx.nextId(root)
  emitNimNode(ctx, id, n)

  for child in ctx.layout.children(root):
    emitNimWalk(ctx, child)

proc emitCheckResultRectWalk(ctx: var DumpContext, root: NodeID) =
  let
    computed = ctx.layout.computed(root)
    id = ctx.getId(root)

  echo fmt"check l.computed({id}) == {fmtFloat32Array(computed)}"

  for child in ctx.layout.children(root):
    emitCheckResultRectWalk(ctx, child)

proc dumpModeNim(ctx: var DumpContext, roots: seq[NodeID], node: NodeID) =
  for root in roots:
    emitNimWalk(ctx, root)
    echo fmt"l.compute({ctx.getId(root)})"
    emitCheckResultRectWalk(ctx, root)

proc emitResultRectWalk(ctx: var DumpContext, id: NodeID, node: NodeID) =
  if node.isNil or id == node:
    let
      c = ctx.layout.computed(id)
    echo fmt"id={int32(id)} {fmtRect(c)}"

  for child in ctx.layout.children(id):
    emitResultRectWalk(ctx, child, node)

proc dumpModeResult(ctx: var DumpContext, roots: seq[NodeID],
    node: NodeID) =
  echo fmt"# result: {ctx.layout.nodes.len} node(s); each row 'id=N [x, y, w, h]' (coords relative to node's compute root)"
  if not node.isNil:
    let
      c = ctx.layout.computed(node)
    echo fmt"id={int32(node)} {fmtRect(c)}"
  else:
    for root in roots:
      emitResultRectWalk(ctx, root, NIL)

proc dumpModeJson(ctx: var DumpContext, roots: seq[NodeID],
    node: NodeID) =
  if not node.isNil:
    echo ctx.layout.dumpJson(node)
  else:
    for root in roots:
      echo ctx.layout.dumpJson(root)

proc dumpModeInspect(ctx: var DumpContext, file: string, roots: seq[NodeID],
    node: NodeID, actionIdx: int32) =
  let
    b = waitFor openBrowserAndPage()
    name = extractFilename(file)

  var
    roots = roots
  if not node.isNil:
    let
      root = ctx.layout.getRoot(node)
    if root.isNil:
      echo fmt"node {node} not found in this input"
      waitFor b.close()
      return

    roots = @[root]

  echo fmt"inspect {name}: {roots.len} tree(s), {ctx.layout.nodes.len} node(s)" &
    (if node.isNil: "" else: fmt", focus node {node}")

  for root in roots:
    let
      report = doDiff(b, ctx.layout, root, actionIdx)
    echo fmtReport(report, name & "_" & $root)

  waitFor b.close()

proc replayBinary(ctx: var Context, data: string, stop: int32 = -1): int32 =
  let
    bytes = cast[seq[byte]](data)

  var
    idx = int32(0)

  for param in bytes.actions():
    if stop >= 0 and idx > stop:
      break

    doAction(ctx, param)

    inc idx, 1
    inc result, 1

proc main =
  if paramCount() < 1:
    echo "usage: dump <file> [--json|--nim|--result|--inspect] [--root <id>] [--node <id>] [--action <idx>]"
    return

  if paramCount() >= 1:
    var
      mode = "json"
      file = ""
      root = default(NodeID)
      node = default(NodeID)
      wantRoot = false
      wantNode = false
      wantAction = false
      actionIdx = int32(-1)
      ctx = default(DumpContext)
      roots: seq[NodeID]

    for i in 1 .. paramCount():
      let arg = paramStr(i)
      if wantRoot:
        root = cast[NodeID](int32(parseInt(arg)))
        wantRoot = false
        continue

      elif wantNode:
        node = cast[NodeID](int32(parseInt(arg)))
        wantNode = false
        continue

      elif wantAction:
        actionIdx = int32(parseInt(arg))
        wantAction = false
        continue

      case arg:
      of "--nim", "nim", "--code", "code":
        mode = "nim"
      of "--json", "json":
        mode = "json"
      of "--result", "result":
        mode = "result"
      of "--inspect", "inspect":
        mode = "inspect"
      of "--action", "action":
        wantAction = true
      of "--root", "root":
        wantRoot = true
      of "--node", "node":
        wantNode = true
      else:
        if file == "":
          file = arg

    if file == "":
      echo "usage: dump <file> [--json|--nim|--result|--inspect] [--root <id>] [--node <id>] [--action <idx>]"
      return

    let
      data = readFile(file)

    if data.len <= 0:
      return

    if data[0] == '[':
      discard ctx.layout.loadJson(data)
    else:
      actionIdx = replayBinary(ctx.layout, data, actionIdx)

    roots = ctx.layout.getRoots()
    if not root.isNil:
      if not ctx.layout.contains(root):
        echo fmt"root {root} is out of range 1..{ctx.layout.nodes.len}"
        return

      roots = @[root]

    for root in roots:
      ctx.layout.compute(root)

    if not node.isNil:
      let
        nodeRoot = ctx.layout.getRoot(node)
      if not roots.contains(nodeRoot):
        echo fmt"node {node} is not under any selected root in this input"
        return

    case mode:
    of "nim":
      dumpModeNim(ctx, roots, node)
    of "result":
      dumpModeResult(ctx, roots, node)
    of "inspect":
      dumpModeInspect(ctx, file, roots, node, actionIdx)
    else:
      dumpModeJson(ctx, roots, node)

main()
