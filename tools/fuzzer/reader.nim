import std/enumutils

type
  Reader* = object
    pos: int32
    len*: int32
    buffer*: ptr UncheckedArray[byte]

proc index[T: enum](data: T): int32 =
  for val in items(T):
    if val == data:
      break

    inc result, 1

proc empty*(r: var Reader): bool =
  r.pos >= r.len

proc next*[T](r: var Reader, _: typedesc[T], min: T = low(T), max: T = high(T)): T =
  var
    idx = int32(0)
    temp = uint64(0)

  while r.pos < r.len and idx < sizeof(T):
    let
      b = r.buffer[r.pos]
    r.pos += 1

    temp = temp shl 8 + uint64(b)
    idx += 1

  when T is enum:
    result = low(T)

    idx = int32(temp) mod (index(high(T)) + 1)

    for val in items(T):
      if idx <= 0:
        result = val
        break

      dec idx, 1

  elif T is SomeOrdinal:
    let
      n = uint64(max) - uint64(min)

    result = cast[T](temp)
    if result < min or result > max:
      result = cast[T](uint64(min) + (temp mod n))

  else:
    assert false, "unreachable"
