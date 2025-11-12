import std/json
import std/tables

import ./core
import ../buju

template getAddr(body): auto =
  when NimMajor > 1: body.addr else: body.unsafeAddr

type
  NodeAttr = object
    wrap: Wrap
    layout: Layout
    mainAxisAlign: MainAxisAlign
    crossAxisAlign: CrossAxisAlign
    crossAxisLineAlign: CrossAxisLineAlign
    align: set[Align]
    size: array[2, float32]
    gap: array[2, float32]
    margin: array[4, float32]

  NodeItem = object
    id: int32
    parentID: int32
    attr: NodeAttr

proc `%`(align: set[Align]): JsonNode =
  result = newJArray()
  for a in [AlignLeft, AlignTop, AlignRight, AlignBottom]:
    if a in align:
      result.add(%a)

proc initFromJson(dst: var set[Align], jsonNode: JsonNode,
    jsonPath: var string) =
  for j in jsonNode:
    dst.incl(j.to(Align))

proc dump(l: ptr Context, id, parentID: NodeID, nodes: var seq[NodeItem]) =
  let n = l.node(id)

  block:
    nodes.add(NodeItem(
      id: int32(id),
      parentID: int32(parentID),
      attr: NodeAttr(
        layout: n.layout,
        wrap: n.wrap,
        mainAxisAlign: n.mainAxisAlign,
        crossAxisAlign: n.crossAxisAlign,
        crossAxisLineAlign: n.crossAxisLineAlign,
        align: n.align,
        size: n.size,
        gap: n.gap,
        margin: n.margin,
      )
    ))

  var childID = n.firstChild
  while not childID.isNil:
    l.dump(childID, id, nodes)

    let child = l.node(childID)
    childID = child.nextSibling

proc dumpJson*(l: Context, id: NodeID): string =
  let l = l.getAddr

  var nodes = newSeqOfCap[NodeItem](l.nodes.len)
  l.dump(id, NIL, nodes)
  pretty(%*nodes)

proc loadJson*(l: var Context, json: string): NodeID =
  let nodes = parseJson(json)

  var mapping = initTable[int32, int32]()
  for j in nodes:
    let
      id = j["id"].getInt()
      parentID = j["parentID"].getInt()
      attr = j["attr"].to(NodeAttr)

    let n = l.node()
    l.setLayout(n, attr.layout)
    l.setMainAxisAlign(n, attr.mainAxisAlign)
    l.setCrossAxisAlign(n, attr.crossAxisAlign)
    l.setCrossAxisLineAlign(n, attr.crossAxisLineAlign)
    l.setWrap(n, attr.wrap)
    l.setAlign(n, attr.align)
    l.setSize(n, attr.size)
    l.setGap(n, attr.gap)
    l.setMargin(n, attr.margin)

    if len(mapping) <= 0:
      result = n

    mapping[int32(id)] = int32(n)
    mapping.withValue(int32(parentID), p):
      l.insertChild(cast[NodeID](p[]), n)
