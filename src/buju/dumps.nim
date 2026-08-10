import std/json

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
    padding: array[4, float32]

  NodeItem = object
    id: int32
    parentId: int32
    attr: NodeAttr

proc `%`(align: set[Align]): JsonNode =
  result = newJArray()
  for a in [AlignMiddle, AlignLeft, AlignTop, AlignRight, AlignBottom]:
    if a in align:
      result.add(%a)

proc initFromJson(dst: var set[Align], jsonNode: JsonNode, jsonPath: var string) =
  for j in jsonNode:
    dst.incl(j.to(Align))

proc dump(l: ptr Context, id, parentId: NodeID, nodes: var seq[NodeItem]) =
  let n = l.node(id)

  block:
    nodes.add(
      NodeItem(
        id: int32(id),
        parentId: int32(parentId),
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
          padding: n.padding,
        ),
      )
    )

  var childId = n.firstChild
  while not childId.isNil:
    l.dump(childId, id, nodes)

    let child = l.node(childId)
    childId = child.nextSibling

proc dumpJson*(l: Context, id: NodeID): string =
  let l = l.getAddr

  var nodes = newSeqOfCap[NodeItem](l.nodes.len)
  if id != NIL:
    l.dump(id, NIL, nodes)

  pretty(%*nodes)

proc loadJson*(l: var Context, json: string): NodeID =
  let
    nodes = parseJson(json)
    base = int32(l.nodes.len)

  var
    maxId = int32(0)
  for j in nodes:
    maxId = max(maxId, int32(j["id"].getInt()))

  for _ in 0 ..< maxId:
    discard l.node()

  for j in nodes:
    let
      id = int32(j["id"].getInt())
      parentId = int32(j["parentId"].getInt())

    if id <= 0 or id > maxId:
      continue

    let
      attr = j["attr"].to(NodeAttr)

    let n = cast[NodeID](base + id)
    l.setLayout(n, attr.layout)
    l.setMainAxisAlign(n, attr.mainAxisAlign)
    l.setCrossAxisAlign(n, attr.crossAxisAlign)
    l.setCrossAxisLineAlign(n, attr.crossAxisLineAlign)
    l.setWrap(n, attr.wrap)
    l.setAlign(n, attr.align)
    l.setSize(n, attr.size)
    l.setGap(n, attr.gap)
    l.setMargin(n, attr.margin)
    l.setPadding(n, attr.padding)

    if result.isNil:
      result = n

    if parentId > 0 and parentId <= maxId:
      l.insertChild(cast[NodeID](base + parentId), n)
