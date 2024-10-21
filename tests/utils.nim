import buju

const bujuDumpPng {.booldefine.} = true

when bujuDumpPng:
  import ./dump

template test2*(name: static[string], body: untyped) =
  test name:
    var l {.inject.}: Layout

    when bujuDumpPng:
      defer:
        let path = "dumps/" & name & ".png"
        l.dump(path)

    body
