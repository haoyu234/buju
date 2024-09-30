import buju

when defined(bujuDumpPng):
  import ./dump

template test2*(name: static[string], body: untyped) =
  test name:
    var l {.inject.}: Layout

    when defined(bujuDumpPng):
      defer:
        var path = "dumps/"
        path.add(name)
        path.add(".png")
        l.dump(path)

    body
