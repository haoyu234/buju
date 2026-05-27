import buju

import std/asyncdispatch
import std/sequtils

import ./action
import ./browserdiff
import ./client
import ./nodes
import ./webdriverops

proc serveFuzzDiff*(b: Browser, c: TcpClient) =
  while true:
    let
      modeFrame = c.next()

    if c.isClosed or modeFrame.len <= 0:
      return

    let
      mode = modeFrame[0]
    if mode != 0:
      return

    let
      data = c.next()

    if c.isClosed or data.len <= 0:
      return

    try:
      var
        ctx: Context

      let
        actions = data.actions().toSeq

      for idx in 0 ..< actions.len:
        let
          param = actions[idx]

        echo idx, " ", param.action

        doAction(ctx, param)

        if param.action == NEW:
          continue

        let
          n = ctx.node1(param)
        if not ctx.contains(n):
          assert false

        var
          root = n
        if param.action != COMPUTE:
          root = ctx.getRoot(n)

        let
          dump = layout(b, ctx, root)
        c.send(dump)

        let
          continueRunRsp = c.next()
        if c.isClosed or continueRunRsp.len != 1:
          return

        case continueRunRsp[0]
        of 0:
          continue
        of 1:
          break
        else:
          return

    except Exception as e:
      echo e.msg

      c.sendError(e.msg)
      return

proc serve(port: uint16) =
  echo "listen: ", port

  let
    b = waitFor openBrowserAndPage()
  try:
    for c in listen(port):
      echo "new client"
      serveFuzzDiff(b, c)

  finally:
    waitFor b.close()

proc main =
  serve(2026)

main()
