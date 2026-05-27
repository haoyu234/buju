import buju
import buju/dumps

import std/asyncdispatch
import std/strutils

import ./action
import ./diff
import ./nodes
import ./utils
import ./webdriverops
import ./writer

proc layout*(b: Browser, ctx: Context, n: NodeID): seq[byte] =
  let
    bujuJsonString = ctx.dumpJson(n)
    layoutResult = waitFor b.layoutJsonString(bujuJsonString)

  var
    writer = Writer()

  for r in layoutResult:
    writer.next(int32(r.id))
    writer.writeRect(r.jsBuju)
    writer.writeRect(r.jsHtml)

  writer.buffer

proc doDiff*(b: Browser, ctx: Context, root: NodeID,
    actionIdx: int32): DiffReport =
  let
    result1 = dumpResultBinary(ctx, root)
    result2 = layout(b, ctx, root)

  result = doDiff(actionIdx, root, result1, result2)

proc doDiff*(b: Browser, actions: openArray[ActionParam]): DiffReport =
  var
    ctx: Context

  for idx in 0 ..< int32(actions.len):
    let
      param = actions[idx]

    if param.action == NEW:
      doAction(ctx, param)
      continue

    var
      copied = ctx

    doAction(copied, param)

    let
      n = copied.node1(param)
    if not copied.contains(n):
      assert false

    var
      root = n
    if param.action != COMPUTE:
      root = copied.getRoot(n)
    copied.compute(root)

    result = doDiff(b, copied, root, idx)
    if result.code != NoError:
      break

    ctx = move copied
