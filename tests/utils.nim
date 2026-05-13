import buju

template test2*(name: static[string], body: untyped) =
  when defined(bujuDumpRecord):
    import ./record

  when defined(bujuDumpJson):
    import buju/dumps

  test name:
    when defined(bujuDumpRecord):
      var l {.inject.}: RecordContext
    else:
      var l {.inject.}: Context

    when defined(bujuDumpJson):
      defer:
        when defined(bujuDumpRecord):
          let jsonStr = l.ctx.dumpJson(cast[NodeID](1))
        else:
          let jsonStr = l.dumpJson(cast[NodeID](1))

        let path = "dumps/" & name & ".json"
        writeFile(path, jsonStr)

    when defined(bujuDumpRecord):
      defer:
        let path = "dumps/" & name & ".record"
        l.writeRecord(path)

    body
