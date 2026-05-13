import std/enumutils

type
  Writer* = object
    buffer*: seq[byte]

proc index[T: enum](data: T): int32 =
  for val in items(T):
    if val == data:
      break

    inc result, 1

proc next*[T](l: var Writer, data: T) =
  when T is enum:
    var
      temp = uint64(index(data))

  elif T is SomeOrdinal:
    var
      temp = uint64(data)

    when sizeof(T) != sizeof(uint64):
      temp = temp and ((uint64(1) shl (sizeof(T) * 8)) - 1)

  else:
    assert false, "unreachable"

  var
    idx = int32(sizeof(T))
    buffer: array[sizeof(T), byte]

  while temp > 0:
    dec idx, 1
    buffer[idx] = byte(0xFF and temp)
    temp = temp shr 8

  l.buffer.add(buffer)
