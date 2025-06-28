import std/json

import buju
import buju/core

template getAddr(body): auto =
  when NimMajor > 1: body.addr else: body.unsafeAddr

type
  NodeAttr = object
    layout*: uint32
    wrap*: uint32
    mainAxisAlign*: uint32
    crossAxisAlign*: uint32
    align*: uint32
    width*: float32
    height*: float32
    marginLeft*: float32
    marginTop*: float32
    marginRight*: float32
    marginBottom*: float32

  NodeItem = object
    id*: int
    parent*: int
    state*: NodeAttr

proc recursionDump(
    l: ptr Context, id, parent: NodeID, nodes: var seq[NodeItem]
) =
  let n = l.node(id)

  block:
    var item = default(NodeItem)
    item.id = int(id)
    item.parent = int(parent)

    item.state.layout = uint32(n.layout)
    item.state.wrap = uint32(n.wrap)
    item.state.mainAxisAlign = uint32(n.mainAxisAlign)
    item.state.crossAxisAlign = uint32(n.crossAxisAlign)

    for a in n.align:
      item.state.align = item.state.align or uint32(a)

    item.state.width = n.size[0]
    item.state.height = n.size[1]
    item.state.marginLeft = n.margin[0]
    item.state.marginTop = n.margin[1]
    item.state.marginRight = n.margin[2]
    item.state.marginBottom = n.margin[3]

    nodes.add(item)

  var childID = n.firstChild
  while not childID.isNil:
    l.recursionDump(childID, id, nodes)

    let child = l.node(childID)
    childID = child.nextSibling

proc dumpJson*(l: Context, id: NodeID): string =
  let l = l.getAddr

  var nodes = newSeqOfCap[NodeItem](l.nodes.len)
  l.recursionDump(id, NIL, nodes)
  pretty(%*nodes)
