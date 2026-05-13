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

proc firstChild*(l: RecordContext, nodeID: NodeID): NodeID {.inline, raises: [].} =
  l.ctx.firstChild(nodeID)

proc lastChild*(l: RecordContext, nodeID: NodeID): NodeID {.inline, raises: [].} =
  l.ctx.lastChild(nodeID)

proc nextSibling*(l: RecordContext, nodeID: NodeID): NodeID {.inline, raises: [].} =
  l.ctx.nextSibling(nodeID)

iterator children*(l: RecordContext, nodeID: NodeID): NodeID {.inline, raises: [].} =
  for n in l.ctx.children(nodeID):
    yield n

proc node*(l: var RecordContext): NodeID {.inline, raises: [].} =
  l.writeEnum(NEW)

  l.ctx.node()

proc setLayout*(l: var RecordContext, nodeID: NodeID, layout: Layout) {.inline,
    raises: [].} =
  l.writeEnum(SET_LAYOUT)
  l.writeInt32(int32(nodeID))
  l.writeEnum(layout)

  l.ctx.setLayout(nodeID, layout)

proc setAlign*(l: var RecordContext, nodeID: NodeID, align: set[
    Align]) {.inline, raises: [].} =
  l.writeEnum(SET_ALIGN)
  l.writeInt32(int32(nodeID))
  l.writeInt32(int32(align.len))

  for a in align:
    l.writeEnum(a)

  l.ctx.setAlign(nodeID, align)

proc setMainAxisAlign*(l: var RecordContext, nodeID: NodeID,
    mainAxisAlign: MainAxisAlign) {.inline, raises: [].} =
  l.writeEnum(SET_MAIN_AXIS_ALIGN)
  l.writeInt32(int32(nodeID))
  l.writeEnum(mainAxisAlign)

  l.ctx.setMainAxisAlign(nodeID, mainAxisAlign)

proc setCrossAxisAlign*(l: var RecordContext, nodeID: NodeID,
    crossAxisAlign: CrossAxisAlign) {.inline, raises: [].} =
  l.writeEnum(SET_CROSS_AXIS_ALIGN)
  l.writeInt32(int32(nodeID))
  l.writeEnum(crossAxisAlign)

  l.ctx.setCrossAxisAlign(nodeID, crossAxisAlign)

proc setCrossAxisLineAlign*(l: var RecordContext, nodeID: NodeID,
    crossAxisLineAlign: CrossAxisLineAlign) {.inline, raises: [].} =
  l.writeEnum(SET_CROSS_AXIS_LINE_ALIGN)
  l.writeInt32(int32(nodeID))
  l.writeEnum(crossAxisLineAlign)

  l.ctx.setCrossAxisLineAlign(nodeID, crossAxisLineAlign)

proc setWrap*(l: var RecordContext, nodeID: NodeID, wrap: Wrap) {.inline,
    raises: [].} =
  l.writeEnum(SET_WRAP)
  l.writeInt32(int32(nodeID))
  l.writeEnum(wrap)

  l.ctx.setWrap(nodeID, wrap)

proc setSize*(l: var RecordContext, nodeID: NodeID, size: array[2,
    float32]) {.inline, raises: [].} =
  l.writeEnum(SET_SIZE)
  l.writeInt32(int32(nodeID))
  for val in size:
    l.writeInt32(int32(val * 100))

  l.ctx.setSize(nodeID, size)

proc setGap*(l: var RecordContext, nodeID: NodeID, gap: array[2,
    float32]) {.inline, raises: [].} =
  l.writeEnum(SET_GAP)
  l.writeInt32(int32(nodeID))
  for val in gap:
    l.writeInt32(int32(val * 100))

  l.ctx.setGap(nodeID, gap)

proc setMargin*(l: var RecordContext, nodeID: NodeID, margin: array[4,
    float32]) {.inline, raises: [].} =
  l.writeEnum(SET_MARGIN)
  l.writeInt32(int32(nodeID))
  for val in margin:
    l.writeInt32(int32(val * 100))

  l.ctx.setMargin(nodeID, margin)

proc setPadding*(l: var RecordContext, nodeID: NodeID, padding: array[4,
    float32]) {.inline, raises: [].} =
  l.writeEnum(SET_PADDING)
  l.writeInt32(int32(nodeID))
  for val in padding:
    l.writeInt32(int32(val * 100))

  l.ctx.setPadding(nodeID, padding)

proc insertChild*(l: var RecordContext, parentID, childID: NodeID) {.inline,
    raises: [].} =
  l.writeEnum(INSERT_CHILD)
  l.writeInt32(int32(parentID))
  l.writeInt32(int32(childID))

  l.ctx.insertChild(parentID, childID)

proc removeChild*(l: var RecordContext, parentID, childID: NodeID) {.inline,
    raises: [].} =
  l.writeEnum(REMOVE_CHILD)
  l.writeInt32(int32(parentID))
  l.writeInt32(int32(childID))

  l.ctx.removeChild(parentID, childID)

proc compute*(l: var RecordContext, nodeID: NodeID) {.inline, raises: [].} =
  l.writeEnum(COMPUTE)
  l.writeInt32(int32(nodeID))

  l.ctx.compute(nodeID)

proc computed*(l: RecordContext, nodeID: NodeID): array[4, float32] {.inline,
    raises: [].} =
  l.ctx.computed(nodeID)

when defined(bujuUserData):
  proc setUserData*(l: var RecordContext, nodeID: NodeID,
      userData: RootRef) {.inline, raises: [].} =
    l.ctx.setUserData(nodeID, userData)

  proc userData*(l: var RecordContext, nodeID: NodeID): RootRef {.inline,
      raises: [].} =
    l.ctx.userData(nodeID)
