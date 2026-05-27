import std/asyncnet
import std/asyncdispatch

when defined(windows):
  import std/winlean
else:
  import std/posix

type
  TcpClient* = ref object
    tcp: AsyncSocket
    isClosed*: bool

const
  isBuffered = true

iterator listen*(port: uint16): TcpClient =
  let
    s = newAsyncSocket(buffered = isBuffered)
  s.setSockOpt(OptReuseAddr, true)
  s.bindAddr(Port(port))
  s.listen()

  defer:
    s.close()

  while true:
    yield TcpClient(
      tcp: waitFor s.accept()
    )

proc connect*(host: string, port: uint16): TcpClient =
  let
    c = newAsyncSocket(buffered = isBuffered)
  waitFor c.connect(host, Port(port))

  TcpClient(
    tcp: c
  )

proc bytesToInt32(buffer: openArray[byte]): int32 =
  for b in buffer:
    result = result shl 8 + int32(b)

proc int32ToBytes(val: int32, buffer: var array[4, byte]) =
  buffer[0] = byte(0xFF and (val shr 24))
  buffer[1] = byte(0xFF and (val shr 16))
  buffer[2] = byte(0xFF and (val shr 8))
  buffer[3] = byte(0xFF and (val shr 0))

proc readExact(c: TcpClient, size: int32): seq[byte] =
  var
    buffer: array[4096, byte]

  while result.len < size:
    let
      n = waitFor c.tcp.recvInto(buffer[0].addr, min(size - result.len, buffer.len))
    if n <= 0:
      c.isClosed = true
      result.setLen(0)
      break

    result.add(buffer.toOpenArray(0, n - 1))

proc writeExact(c: TcpClient, data: openArray[byte]): bool =
  if c.isClosed or data.len <= 0:
    return

  waitFor c.tcp.send(data[0].addr, data.len)
  result = true
  return

proc next*(c: TcpClient): seq[byte] =
  let
    head = c.readExact(4)
  if head.len <= 0:
    return

  let
    size = bytesToInt32(head)
  c.readExact(size)

proc send*(c: TcpClient, data: openArray[byte]) =
  var
    header: array[4, byte]
  int32ToBytes(int32(data.len), header)

  if not writeExact(c, header):
    return

  if not writeExact(c, data):
    return
