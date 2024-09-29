import std/strformat

import pixie

import buju
import buju/core

proc dump(l: ptr LayoutObj, n: LayoutNodeID, ctx: Context) =
  let node = l.node(n)

  ctx.strokeRect(rect(
    40 + node.computed[0] * 10,
    40 + node.computed[1] * 10,
    node.computed[2] * 10,
    node.computed[3] * 10))

  let pos = vec2(
      44 + node.computed[0] * 10,
      44 + ctx.fontSize + node.computed[1] * 10)

  if node.label.len > 0:
    ctx.fillText(node.label, pos)
  else:
    ctx.fillText(fmt"{int(n)}", pos)

proc recursionDump(l: ptr LayoutObj, n: LayoutNodeID, ctx: Context) =
  var id = block:
    let node = l.node(n)
    node.firstChild

  while id != NIL:
    l.dump(id, ctx)
    l.recursionDump(id, ctx)

    let node = l.node(id)
    id = node.nextSibling

proc dump*(l: var Layout, path: string) =
  let l = LayoutObj(l).addr

  if l.nodes.len <= 0:
    return

  let id = ROOT

  let root = l.node(id)
  if root.isNil:
    return

  let w = int(root.computed[2] * 10) + 80
  let h = int(root.computed[3] * 10) + 80

  let image = newImage(w, h)
  let ctx = newContext(image)
  ctx.lineWidth = 1
  ctx.fontSize = 14
  ctx.font = "assets/font.ttf"
  ctx.strokeStyle = "#FF5C00"
  ctx.fillStyle = "#FF5C00"

  l.dump(id, ctx)
  l.recursionDump(id, ctx)

  image.writeFile(path)
