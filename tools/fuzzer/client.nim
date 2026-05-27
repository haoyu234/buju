import std/asyncdispatch
import std/asyncnet

when defined(windows):
  import std/winlean
else:
  import std/posix

type
  TcpClient* = ref TcpClientObj
  TcpClientObj = object
    tcp: AsyncSocket
    isClosed*: bool

  ServeError* = object of CatchableError

const
  isBuffered = true

proc `=destroy`*(c: var TcpClientObj) =
  if c.isClosed:
    return

  try:
    c.tcp.close()
  except Exception:
    discard
  c.isClosed = true

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

proc int32ToBytes(val: int32, buffer: var openArray[byte]) =
  buffer[0] = byte(0xFF and (val shr 24))
  buffer[1] = byte(0xFF and (val shr 16))
  buffer[2] = byte(0xFF and (val shr 8))
  buffer[3] = byte(0xFF and (val shr 0))

proc bytesToInt32(buffer: openArray[byte]): int32 =
  result = int32(buffer[0]) shl 24 or int32(buffer[1]) shl 16 or int32(buffer[
      2]) shl 8 or int32(buffer[3])

proc readExactInto(c: TcpClient, buf: var openArray[byte],
    timeout: int32): bool =
  var
    r = 0
    n = 0

  while r < buf.len:
    let
      fut = c.tcp.recvInto(buf[r].addr, buf.len - r)
    if timeout < 0:
      n = waitFor fut
    else:
      if waitFor withTimeout(fut, timeout):
        n = waitFor fut

    if n <= 0:
      c.isClosed = true
      result = false
      return

    r += n
    n = 0

  result = true

proc readExact(c: TcpClient, size: int32, timeout: int32 = 3000): seq[byte] =
  result.setLen(size)

  if not readExactInto(c, result.toOpenArray(0, size - 1), timeout):
    result.setLen(0)

proc writeExact(c: TcpClient, data: openArray[byte]): bool =
  if c.isClosed or data.len <= 0:
    return

  try:
    waitFor c.tcp.send(data[0].addr, data.len)
  except CatchableError:
    c.isClosed = true
    return

  result = true

proc msgToString(buf: seq[byte]): string =
  result = newString(buf.len)
  for i in 0 ..< buf.len:
    result[i] = chr(int(buf[i]))

proc next*(c: TcpClient, timeout: int32 = 60 * 1000): seq[byte] =
  var
    head: array[5, byte]
  if not readExactInto(c, head, timeout):
    return

  let
    size = bytesToInt32(head.toOpenArray(0, 3))
    kind = head[4]
    data = c.readExact(size, timeout)

  if kind == byte(1):
    raise newException(ServeError, "serve: " & msgToString(data))

  data

proc send*(c: TcpClient, data: openArray[byte]) =
  var
    header = [byte(0), 0, 0, 0, 0] # kind: normal
  int32ToBytes(int32(data.len), header.toOpenArray(0, 3))

  discard writeExact(c, header) and writeExact(c, data)

proc sendError*(c: TcpClient, msg: string) =
  var
    header = [byte(0), 0, 0, 0, 1] # kind: system error
  int32ToBytes(int32(msg.len), header.toOpenArray(0, 3))

  if not writeExact(c, header):
    return

  discard writeExact(c, msg.toOpenArrayByte(0, msg.len - 1))

proc close*(c: TcpClient) =
  if not c.isNil and not c.isClosed:
    c.tcp.close()
    c.isClosed = true
