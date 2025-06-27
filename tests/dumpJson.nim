import std/json
import std/typetraits

import buju
import buju/core

template getAddr(body): auto =
  when NimMajor > 1: body.addr else: body.unsafeAddr

type
  NodeAttr = object
    boxFlags*: uint8
    anchorFlags*: uint8
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
    l: ptr LayoutObj, id, parent: LayoutNodeID, nodes: var seq[NodeItem]
) =
  let n = l.node(id)

  block:
    var item = default(NodeItem)
    item.id = int(id)
    item.parent = int(parent)

    item.state.boxFlags = uint8(n.boxFlags)
    item.state.anchorFlags = uint8(n.anchorFlags)
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

proc dumpJson*(l: Layout, id: LayoutNodeID): string =
  let l = distinctBase(l).getAddr

  var nodes = newSeqOfCap[NodeItem](l.nodes.len)
  l.recursionDump(id, NIL, nodes)
  pretty(%*nodes)
