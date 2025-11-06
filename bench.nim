import unittest

import std/monotimes
import std/strformat

import src/buju

proc nested(l: var Context) =
  const numRows = 5
  # one of the rows is "fake" and will have 0 units tall height
  const numRowsWithHeight = numRows - 1

  # mainChild is a column that contains rows, and those rows
  # will contain columns.
  let root = l.node()
  let mainChild = l.node()

  l.setSize(
    root,
    [
      float32(70),
      # 10 units extra size above and below for mainChild margin
      float32(numRowsWithHeight * 10 + 2 * 10),
    ],
  )

  l.setMargin(mainChild, [float32(10), 10, 10, 10])
  l.setLayout(mainChild, LayoutColumn)
  l.insertChild(root, mainChild)
  l.setAlign(mainChild, {AlignLeft, AlignTop, AlignRight, AlignBottom})

  var rows = default(array[numRows, NodeID])

  # auto-filling columns-in-row, each one should end up being
  # 10 units wide
  rows[0] = l.node()
  l.setLayout(rows[0], LayoutRow)
  l.setAlign(rows[0], {AlignLeft, AlignTop, AlignRight, AlignBottom})

  var cols1 = default(array[5, NodeID])

  # hmm so both the row and its child columns need to be set to
  # fill? which means mainChild also needs to be set to fill?
  for i in 0 ..< 5:
    let col = l.node()
    # fill empty space
    l.setAlign(col, {AlignLeft, AlignTop, AlignRight, AlignBottom})
    l.insertChild(rows[0], col)
    cols1[i] = col

  rows[1] = l.node()
  l.setLayout(rows[1], LayoutRow)
  l.setAlign(rows[1], {AlignTop, AlignBottom})

  var cols2 = default(array[5, NodeID])
  for i in 0 ..< 5:
    let col = l.node()
    # fixed-size horizontally, fill vertically
    l.setSize(col, [float32(10), 0])
    l.setAlign(col, {AlignTop, AlignBottom})
    l.insertChild(rows[1], col)
    cols2[i] = col

  # these columns have an inner item which sizes them
  rows[2] = l.node()
  l.setLayout(rows[2], LayoutRow)

  var cols3 = default(array[2, NodeID])
  for i in 0 ..< 2:
    let col = l.node()
    let innerSizer = l.node()
    # only the second one will have height
    l.setSize(innerSizer, [float32(25), float32(10 * i)])
    # align to bottom, only should make a difference for first item
    l.setAlign(col, {AlignBottom})
    l.insertChild(col, innerSizer)
    l.insertChild(rows[2], col)
    cols3[i] = col

  # row 4 should end up being 0 units tall after layout
  rows[3] = l.node()
  l.setLayout(rows[3], LayoutRow)
  l.setAlign(rows[3], {AlignLeft, AlignRight})

  var cols4 = default(array[99, NodeID])
  for i in 0 ..< 99:
    let col = l.node()
    l.insertChild(rows[3], col)
    cols4[i] = col

  # row 5 should be 10 pixels tall after layout, and each of
  # its columns should be 1 pixel wide
  rows[4] = l.node()
  l.setLayout(rows[4], LayoutRow)
  l.setAlign(rows[4], {AlignLeft, AlignTop, AlignRight, AlignBottom})

  var cols5 = default(array[50, NodeID])
  for i in 0 ..< 50:
    let col = l.node()
    l.setAlign(col, {AlignLeft, AlignTop, AlignRight, AlignBottom})
    l.insertChild(rows[4], col)
    cols5[i] = col

  for i in 0 ..< numRows:
    l.insertChild(mainChild, rows[i])

  # repeat the run and tests multiple times to make sure we get the expected
  # results each time. 
  for i in 0 ..< 5:
    l.compute(root)

    check l.computed(mainChild) == [float32(10), 10, 50, 40]

    # these rows should all be 10 units in height
    check l.computed(rows[0]) == [float32(10), 10, 50, 10]
    check l.computed(rows[1]) == [float32(10), 20, 50, 10]
    check l.computed(rows[2]) == [float32(10), 30, 50, 10]

    # this row should have 0 height
    check l.computed(rows[3]) == [float32(10), 40, 50, 0]
    check l.computed(rows[4]) == [float32(10), 40, 50, 10]

    for i in 0 ..< 5:
      # each of these should be 10 units wide, and stacked horizontally
      check l.computed(cols1[i]) == [float32(10 + 10 * i), 10, 10, 10]

    # the cols in the second row are similar to first row
    for i in 0 ..< 5:
      check l.computed(cols2[i]) == [float32(10 + 10 * i), 20, 10, 10]

    # leftmost (first of two items), aligned to bottom of row, 0 units tall
    check l.computed(cols3[0]) == [float32(10), 40, 25, 0]

    # rightmost (second of two items), same height as row, which is 10 units tall
    check l.computed(cols3[1]) == [float32(35), 30, 25, 10]

    # these should all have size 0 and be in the middle of the row
    for i in 0 ..< 99:
      check l.computed(cols4[i]) == [float32(25) + 10, 40, 0, 0]

    # these should all be 1 unit wide and 10 units tall
    for i in 0 ..< 50:
      check l.computed(cols5[i]) == [float32(10 + i), 40, 1, 10]

proc main() =
  let numRun = 100000

  var l = default(Context)
  var total = default(MonoTime)

  for i in 0 ..< numRun:
    l.clear()

    let a = getMonoTime()

    nested(l)

    let b = getMonoTime()

    let diff = b - a
    total = total + diff

  let us = int64(total.ticks div 1000)
  echo fmt"nim version: {NimVersion}"
  echo fmt"times: {numRun}"
  echo fmt"total time: {us} usecs"
  echo fmt"average time: {float32(us) / float32(numRun)} usecs"

try:
  main()
except Exception as e:
  echo "bench error, ", e.msg
