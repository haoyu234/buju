import buju

const bujuDumpJson {.booldefine.} = false

when bujuDumpJson:
  import ./dumpJson

template test2*(name: static[string], body: untyped) =
  test name:
    var l {.inject.}: Context

    when bujuDumpJson:
      bind dumpJson

      defer:
        let jsonStr = l.dumpJson(cast[NodeID](1))

        let path = "dumps/" & name & ".json"
        writeFile(path, jsonStr)

    body
