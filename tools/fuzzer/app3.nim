import buju
import buju/core
import buju/dumps

import std/os
import std/sequtils
import std/strutils
import std/strformat
import std/tables

import ./action
import ./utils

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

proc doActions(ctx: var Context, actions: openArray[
    ActionParam]) =
  for idx in 0 ..< actions.len:
    let
      param = actions[idx]

    doAction(ctx, param)

proc prettyFormatFloat32Array(data: openArray[float32]): string =
  proc formatFloat32(f: float32, idx: int32): string =
    proc isInt32(f: float32): bool =
      float32(int32(f)) == f

    if idx <= 0 and isInt32(f):
      fmt"float32({int32(f)})"
    elif isInt32(f):
      fmt"{int32(f)}"
    else:
      fmt"float32({f})"

  result.add("[")

  for idx in 0 ..< int32(data.len):
    let
      s = formatFloat32(data[idx], idx)
    if idx > 0:
      result.add(", ")
    result.add(s)

  result.add("]")

proc dumpNimCode(ctx: var DumpContext, id: DumpNodeID, n: ptr Node) =
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
    echo fmt"l.setSize({id}, {prettyFormatFloat32Array(n.size)})"
  if n.gap != default(array[2, float32]):
    echo fmt"l.setGap({id}, {prettyFormatFloat32Array(n.gap)})"
  if n.margin != default(array[4, float32]):
    echo fmt"l.setMargin({id}, {prettyFormatFloat32Array(n.margin)})"
  if n.padding != default(array[4, float32]):
    echo fmt"l.setPadding({id}, {prettyFormatFloat32Array(n.padding)})"

  if n.prevSibling != default(NodeID) or n.nextSibling != default(NodeID) or
      not ctx.layout.getParent(id.oldId).isNil:
    let
      parentOldId = ctx.layout.getParent(id.oldId)
      parentId = getId(ctx, parentOldId)
    echo fmt"l.insertChild({parentId}, {id})"

proc dumpNimCode(ctx: var DumpContext, param: ActionParam) =
  let
    n1OldId = ctx.layout.node1(param)
    n1 = ctx.getId(n1OldId)
    n2OldId = ctx.layout.node2(param)

  case param.action:
  of NEW:
    discard
  of SET_LAYOUT:
    echo fmt"l.setLayout({n1}, {param.layout})"
  of SET_ALIGN:
    echo fmt"l.setAlign({n1}, {param.aligns})"
  of SET_MAIN_AXIS_ALIGN:
    echo fmt"l.setMainAxisAlign({n1}, {param.mainAxisAlign})"
  of SET_CROSS_AXIS_ALIGN:
    echo fmt"l.setCrossAxisAlign({n1}, {param.crossAxisAlign})"
  of SET_CROSS_AXIS_LINE_ALIGN:
    echo fmt"l.setCrossAxisLineAlign({n1}, {param.crossAxisLineAlign})"
  of SET_WRAP:
    echo fmt"l.setWrap({n1}, {param.wrap})"
  of SET_SIZE:
    echo fmt"l.setSize({n1}, {param.size})"
  of SET_GAP:
    echo fmt"l.setGap({n1}, {param.gap})"
  of SET_MARGIN:
    echo fmt"l.setMargin({n1}, {param.margin})"
  of SET_PADDING:
    echo fmt"l.setPadding({n1}, {param.padding})"
  of INSERT_CHILD:
    let
      n2 = ctx.getId(n2OldId)
    echo fmt"l.insertChild({n1}, {n2})"
  of REMOVE_CHILD:
    let
      n2 = ctx.getId(n2OldId)
    echo fmt"l.removeChild({n1}, {n2})"
  of COMPUTE:
    discard

proc dumpNimCode(ctx: var DumpContext, root: NodeID) =
  let
    n = ctx.layout.addr.node(root)
    id = ctx.nextId(root)
  dumpNimCode(ctx, id, n)

  for child in ctx.layout.children(root):
    dumpNimCode(ctx, child)

proc dumpCheckResult(ctx: var DumpContext, root: NodeID) =
  let
    computed = ctx.layout.computed(root)
    id = ctx.getId(root)

  if id.id == 1:
    echo "l.compute(root)"

  echo fmt"check l.computed({id}) == {prettyFormatFloat32Array(computed)}"

  for child in ctx.layout.children(root):
    dumpCheckResult(ctx, child)

proc main =
  if paramCount() >= 1:
    var
      step: int32 = 0
      ctx: DumpContext
      root: NodeID

    let
      data = readFile(paramStr(1))

    if data.len <= 0:
      return

    if data[0] == '[':
      root = ctx.layout.loadJson(data)

      ctx.layout.compute(root)

      dumpNimCode(ctx, root)
    else:
      let
        actions = cast[seq[byte]](data).actions().toSeq

      if paramCount() >= 2:
        step = int32(parseInt(paramStr(2)))
      else:
        step = int32(actions.len)

      if step <= 0:
        return

      doActions(ctx.layout, actions.toOpenArray(0, step - 1))

      let
        param = actions[step - 1]
        n = ctx.layout.node1(param)
      root = ctx.layout.getRoot(n)

      ctx.layout.compute(root)

      dumpNimCode(ctx, root)

      if param.action != COMPUTE and param.action != NEW:
        dumpNimCode(ctx, param)

    dumpCheckResult(ctx, root)

main()
