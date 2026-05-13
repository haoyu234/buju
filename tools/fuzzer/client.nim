import std/net
import std/oserrors

when defined(windows):
  import std/winlean
else:
  import std/posix

type
  TcpClient* = ref object
    tcp: Socket
    isClosed*: bool

const
  safeDisconn = {SocketFlag.SafeDisconn}

proc listen*(port: uint16): TcpClient =
  let
    s = newSocket(buffered = false)
  s.setSockOpt(OptReuseAddr, true)
  s.bindAddr(Port(port))
  s.listen()

  var c: Socket
  s.accept(c)
  s.close()

  TcpClient(
    tcp: c
  )

proc connect*(host: string, port: uint16): TcpClient =
  let
    c = newSocket(buffered = false)
  c.connect(host, Port(port))

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

proc isDisconnectionError(lastErr: OSErrorCode): bool =
  if safeDisconn.isDisconnectionError(lastErr):
    result = true
    return

  when defined(windows):
    if lastErr.int32 == WSAEWOULDBLOCK:
      return
    else: raiseOSError(lastErr)
  else:
    if lastErr.int32 == EAGAIN or lastErr.int32 == EWOULDBLOCK:
      return

proc readExact(c: TcpClient, size: int32): seq[byte] =
  var
    buffer: array[4096, byte]

  while result.len < size:
    let
      n = c.tcp.recv(buffer[0].addr, min(size - result.len, buffer.len))
    if n < 0:
      let
        lastErr = c.tcp.getSocketError()
      if isDisconnectionError(lastErr):
        c.isClosed = true
        result.setLen(0)
        return
      continue

    if n > 0:
      result.add(buffer.toOpenArray(0, n - 1))

proc writeExact(c: TcpClient, data: openArray[byte]): bool =
  var
    written = 0
  while written < data.len:
    let
      n = c.tcp.send(data[written].addr, data.len - written)
    if n < 0:
      let
        lastErr = c.tcp.getSocketError()
      if isDisconnectionError(lastErr):
        c.isClosed = true
        result = false
        return
      continue

    if n > 0:
      inc written, n

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
