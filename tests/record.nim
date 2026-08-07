import std/enumutils

import buju

export Context, NodeID, isNil, `$`
export Align, MainAxisAlign, CrossAxisAlign, CrossAxisLineAlign, Layout, Wrap

type
  Action = enum
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

  RecordContext* = object
    ctx*: Context
    buffer: seq[byte]

proc index[T: enum](val: T): int32 =
  for data in items(T):
    if val == data:
      break

    inc result, 1

proc int32ToBytes(val: int32, buffer: var array[4, byte]) =
  buffer[0] = byte(0xFF and (val shr 24))
  buffer[1] = byte(0xFF and (val shr 16))
  buffer[2] = byte(0xFF and (val shr 8))
  buffer[3] = byte(0xFF and (val shr 0))

proc writeInt32(l: var RecordContext, val: int32) =
  var
    buffer: array[4, byte]
  int32ToBytes(val, buffer)
  l.buffer.add(buffer)

proc writeEnum[T](l: var RecordContext, val: T) =
  var
    buffer: array[4, byte]
  int32ToBytes(index(val), buffer)
  l.buffer.add(buffer.toOpenArray(4 - sizeof(T), 3))

proc writeRecord*(l: var RecordContext, file: string) =
  writeFile(file, l.buffer)
  l.buffer.setLen(0)

proc len*(l: RecordContext): int {.inline, raises: [].} =
  l.ctx.len

proc clear*(l: var RecordContext) {.inline, raises: [].} =
  l.ctx.clear()

  l.buffer.setLen(0)

proc firstChild*(l: RecordContext, nodeId: NodeID): NodeID {.inline, raises: [].} =
  l.ctx.firstChild(nodeId)

proc lastChild*(l: RecordContext, nodeId: NodeID): NodeID {.inline, raises: [].} =
  l.ctx.lastChild(nodeId)

proc nextSibling*(l: RecordContext, nodeId: NodeID): NodeID {.inline, raises: [].} =
  l.ctx.nextSibling(nodeId)

iterator children*(l: RecordContext, nodeId: NodeID): NodeID {.inline, raises: [].} =
  for n in l.ctx.children(nodeId):
    yield n

proc node*(l: var RecordContext): NodeID {.inline, raises: [].} =
  l.writeEnum(NEW)

  l.ctx.node()

proc setLayout*(l: var RecordContext, nodeId: NodeID, layout: Layout) {.inline,
    raises: [].} =
  l.writeEnum(SET_LAYOUT)
  l.writeInt32(int32(nodeId))
  l.writeEnum(layout)

  l.ctx.setLayout(nodeId, layout)

proc setAlign*(l: var RecordContext, nodeId: NodeID, align: set[
    Align]) {.inline, raises: [].} =
  l.writeEnum(SET_ALIGN)
  l.writeInt32(int32(nodeId))
  l.writeInt32(int32(align.len))

  for a in align:
    l.writeEnum(a)

  l.ctx.setAlign(nodeId, align)

proc setMainAxisAlign*(l: var RecordContext, nodeId: NodeID,
    mainAxisAlign: MainAxisAlign) {.inline, raises: [].} =
  l.writeEnum(SET_MAIN_AXIS_ALIGN)
  l.writeInt32(int32(nodeId))
  l.writeEnum(mainAxisAlign)

  l.ctx.setMainAxisAlign(nodeId, mainAxisAlign)

proc setCrossAxisAlign*(l: var RecordContext, nodeId: NodeID,
    crossAxisAlign: CrossAxisAlign) {.inline, raises: [].} =
  l.writeEnum(SET_CROSS_AXIS_ALIGN)
  l.writeInt32(int32(nodeId))
  l.writeEnum(crossAxisAlign)

  l.ctx.setCrossAxisAlign(nodeId, crossAxisAlign)

proc setCrossAxisLineAlign*(l: var RecordContext, nodeId: NodeID,
    crossAxisLineAlign: CrossAxisLineAlign) {.inline, raises: [].} =
  l.writeEnum(SET_CROSS_AXIS_LINE_ALIGN)
  l.writeInt32(int32(nodeId))
  l.writeEnum(crossAxisLineAlign)

  l.ctx.setCrossAxisLineAlign(nodeId, crossAxisLineAlign)

proc setWrap*(l: var RecordContext, nodeId: NodeID, wrap: Wrap) {.inline,
    raises: [].} =
  l.writeEnum(SET_WRAP)
  l.writeInt32(int32(nodeId))
  l.writeEnum(wrap)

  l.ctx.setWrap(nodeId, wrap)

proc setSize*(l: var RecordContext, nodeId: NodeID, size: array[2,
    float32]) {.inline, raises: [].} =
  l.writeEnum(SET_SIZE)
  l.writeInt32(int32(nodeId))
  for val in size:
    l.writeInt32(int32(val * 100))

  l.ctx.setSize(nodeId, size)

proc setGap*(l: var RecordContext, nodeId: NodeID, gap: array[2,
    float32]) {.inline, raises: [].} =
  l.writeEnum(SET_GAP)
  l.writeInt32(int32(nodeId))
  for val in gap:
    l.writeInt32(int32(val * 100))

  l.ctx.setGap(nodeId, gap)

proc setMargin*(l: var RecordContext, nodeId: NodeID, margin: array[4,
    float32]) {.inline, raises: [].} =
  l.writeEnum(SET_MARGIN)
  l.writeInt32(int32(nodeId))
  for val in margin:
    l.writeInt32(int32(val * 100))

  l.ctx.setMargin(nodeId, margin)

proc setPadding*(l: var RecordContext, nodeId: NodeID, padding: array[4,
    float32]) {.inline, raises: [].} =
  l.writeEnum(SET_PADDING)
  l.writeInt32(int32(nodeId))
  for val in padding:
    l.writeInt32(int32(val * 100))

  l.ctx.setPadding(nodeId, padding)

proc insertChild*(l: var RecordContext, parentId, childId: NodeID) {.inline,
    raises: [].} =
  l.writeEnum(INSERT_CHILD)
  l.writeInt32(int32(parentId))
  l.writeInt32(int32(childId))

  l.ctx.insertChild(parentId, childId)

proc removeChild*(l: var RecordContext, parentId, childId: NodeID) {.inline,
    raises: [].} =
  l.writeEnum(REMOVE_CHILD)
  l.writeInt32(int32(parentId))
  l.writeInt32(int32(childId))

  l.ctx.removeChild(parentId, childId)

proc compute*(l: var RecordContext, nodeId: NodeID) {.inline, raises: [].} =
  l.writeEnum(COMPUTE)
  l.writeInt32(int32(nodeId))

  l.ctx.compute(nodeId)

proc computed*(l: RecordContext, nodeId: NodeID): array[4, float32] {.inline,
    raises: [].} =
  l.ctx.computed(nodeId)

when defined(bujuUserData):
  proc setUserData*(l: var RecordContext, nodeId: NodeID,
      userData: RootRef) {.inline, raises: [].} =
    l.ctx.setUserData(nodeId, userData)

  proc userData*(l: var RecordContext, nodeId: NodeID): RootRef {.inline,
      raises: [].} =
    l.ctx.userData(nodeId)
