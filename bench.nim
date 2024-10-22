import unittest

import std/monotimes
import std/strformat

import src/buju

proc nested(l: var Layout) =
  const numRows = 5
  const numRowsWithHeight = numRows - 1

  let root = l.node()
  let mainChild = l.node()

  l.setSize(root, vec2(70, float(numRowsWithHeight * 10 + 2 * 10)))
  l.setMargin(mainChild, vec4(10, 10, 10, 10))
  l.setBoxFlags(mainChild, LayoutBoxColumn)
  l.insertChild(root, mainChild)
  l.setLayoutFlags(mainChild, LayoutFill)

  var rows: array[numRows, LayoutNodeID]

  rows[0] = l.node()
  l.setBoxFlags(rows[0], LayoutBoxRow)
  l.setLayoutFlags(rows[0], LayoutFill)

  var cols1: array[5, LayoutNodeID]
  for i in 0..<5:
    let col = l.node()
    l.setLayoutFlags(col, LayoutFill)
    l.insertChild(rows[0], col)
    cols1[i] = col

  rows[1] = l.node()
  l.setBoxFlags(rows[1], LayoutBoxRow)
  l.setLayoutFlags(rows[1], LayoutVerticalFill)

  var cols2: array[5, LayoutNodeID]
  for i in 0..<5:
    let col = l.node()
    l.setSize(col, vec2(10, 0))
    l.setLayoutFlags(col, LayoutVerticalFill)
    l.insertChild(rows[1], col)
    cols2[i] = col

  rows[2] = l.node()
  l.setBoxFlags(rows[2], LayoutBoxRow)

  var cols3: array[2, LayoutNodeID]
  for i in 0..<2:
    let col = l.node()
    let innerSizer = l.node()
    l.setSize(innerSizer, vec2(25, float(10 * i)))
    l.setLayoutFlags(col, LayoutBottom)
    l.insertChild(col, innerSizer)
    l.insertChild(rows[2], col)
    cols3[i] = col

  rows[3] = l.node()
  l.setBoxFlags(rows[3], LayoutBoxRow)
  l.setLayoutFlags(rows[3], LayoutHorizontalFill)

  var cols4: array[99, LayoutNodeID]
  for i in 0..<99:
    let col = l.node()
    l.insertChild(rows[3], col)
    cols4[i] = col

  rows[4] = l.node()
  l.setBoxFlags(rows[4], LayoutBoxRow)
  l.setLayoutFlags(rows[4], LayoutFill)

  var cols5: array[50, LayoutNodeID]
  for i in 0..<50:
    let col = l.node()
    l.setLayoutFlags(col, LayoutFill)
    l.insertChild(rows[4], col)
    cols5[i] = col

  for i in 0..<numRows:
    l.insertChild(mainChild, rows[i])

  for i in 0..<5:
    l.compute(root)

    check l.computed(mainChild) == vec4(10, 10, 50, 40)

    check l.computed(rows[0]) == vec4(10, 10, 50, 10)
    check l.computed(rows[1]) == vec4(10, 20, 50, 10)
    check l.computed(rows[2]) == vec4(10, 30, 50, 10)

    check l.computed(rows[3]) == vec4(10, 40, 50, 0)
    check l.computed(rows[4]) == vec4(10, 40, 50, 10)

    for i in 0..<5:
      check l.computed(cols1[i]) == vec4(float(10 + 10 * i), 10, 10, 10)

    for i in 0..<5:
      check l.computed(cols2[i]) == vec4(float(10 + 10 * i), 20, 10, 10)

    check l.computed(cols3[0]) == vec4(10, 40, 25, 0)
    check l.computed(cols3[1]) == vec4(35, 30, 25, 10)

    for i in 0..<99:
      check l.computed(cols4[i]) == vec4(25 + 10, 40, 0, 0)

    for i in 0..<50:
      check l.computed(cols5[i]) == vec4(float(10 + i), 40, 1, 10)

proc main =
  let numRun = 1000

  var l: Layout
  var total: MonoTime

  for i in 0..<numRun:
    l.clear()

    let a = getMonoTime()

    nested(l)

    let b = getMonoTime()

    let diff = b - a
    total = total + diff

  let us = int64(total.ticks div 1000)
  echo fmt"average time: {float(us) / float(numRun)} usecs"

main()
