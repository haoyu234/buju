import std/strformat

import pixie

import buju
import buju/core

const scaleXY = 2.5
const padding = 20

proc dump(l: ptr LayoutObj, n: LayoutNodeID, ctx: Context) =
  let node = l.node(n)

  ctx.strokeRect(rect(
    padding + node.computed[0] * scaleXY,
    padding + node.computed[1] * scaleXY,
    node.computed[2] * scaleXY,
    node.computed[3] * scaleXY))

  let pos = vec2(
      4 + padding + node.computed[0] * scaleXY,
      4 + padding + ctx.fontSize + node.computed[1] * scaleXY)

  ctx.fillText(fmt"{int(n)}", pos)

proc recursionDump(l: ptr LayoutObj, n: LayoutNodeID, ctx: Context) =
  var id = block:
    let node = l.node(n)
    node.firstChild

  while not id.isNil:
    l.dump(id, ctx)
    l.recursionDump(id, ctx)

    let node = l.node(id)
    id = node.nextSibling

proc dump*(l: Layout, path: string) =
  let l = LayoutObj(l).addr

  if l.nodes.len <= 0:
    return

  let id = cast[LayoutNodeID](1)

  let root = l.node(id)
  if root.isNil:
    return

  let w = int(root.computed[2] * scaleXY) + padding * 2
  let h = int(root.computed[3] * scaleXY) + padding * 2

  let image = newImage(w, h)
  let ctx = newContext(image)
  ctx.lineWidth = 1
  ctx.fontSize = 14
  ctx.font = "assets/font.ttf"
  ctx.strokeStyle.color = parseHtmlColor("#ff461f")
  ctx.strokeStyle.blendMode = OverwriteBlend
  ctx.globalAlpha = 1
  ctx.fillStyle = "#f20c00"
  ctx.setLineDash(@[6f, 3])

  l.dump(id, ctx)

  ctx.strokeStyle.color = parseHtmlColor("#1bd1a5")

  l.recursionDump(id, ctx)

  image.writeFile(path)
