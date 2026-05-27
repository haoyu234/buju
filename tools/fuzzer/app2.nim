import buju

import std/sequtils

import ./action
import ./client
import ./utils

type
  ProcessResult = enum
    Next
    Break
    Exit

proc handleClient(c: TcpClient) =
  while true:
    let
      data = c.next()

    if c.isClosed:
      return

    if data.len <= 0:
      continue

    var
      ctx: Context

    let
      actions = data.actions().toSeq

    for idx in 0 ..< actions.len:
      let
        param = actions[idx]

      echo idx + 1, "/", actions.len, " ", param.action

      doAction(ctx, param)

      if param.action == NEW:
        continue

      let
        n = ctx.node1(param)
      if param.action != COMPUTE:
        ctx.compute(n)

      let
        dump = dumpResultBinary(ctx, n)
      c.send(dump)

      let
        continueRunRsp = c.next()
      if c.isClosed or continueRunRsp.len != 1:
        return

      if continueRunRsp.len == 1:
        case continueRunRsp[0]
        of byte(Next):
          continue
        of byte(Break):
          break
        of byte(Exit):
          return
        else:
          return

proc serve(port: uint16) =
  echo "listen: ", port

  for c in listen(port):
    echo "new client"

    handleClient(c)

    echo ""

proc main =
  serve(2026)

main()
