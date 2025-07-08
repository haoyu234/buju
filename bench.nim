import unittest

import std/monotimes
import std/strformat

import vmath
import src/buju

proc nested(l: var Context) =
  const numRows = 5
  # one of the rows is "fake" and will have 0 units tall height
  const numRowsWithHeight = numRows - 1

  # mainChild is a column that contains rows, and those rows
  # will contain columns.
  let root = Node()
  let mainChild = Node()

  root.size = vec2(
    70,
    # 10 units extra size above and below for mainChild margin
    float32(numRowsWithHeight * 10 + 2 * 10),
  )

  mainChild.margin = vec4(10, 10, 10, 10)
  mainChild.layout = LayoutColumn
  mainChild.align = {AlignLeft, AlignTop, AlignRight, AlignBottom}

  root.insertChild(mainChild)

  var rows = default(array[numRows, Node])

  # auto-filling columns-in-row, each one should end up being
  # 10 units wide
  rows[0] = Node()
  rows[0].layout = LayoutRow
  rows[0].align = {AlignLeft, AlignTop, AlignRight, AlignBottom}

  var cols1 = default(array[5, Node])

  # hmm so both the row and its child columns need to be set to
  # fill? which means mainChild also needs to be set to fill?
  for i in 0 ..< 5:
    let col = Node()
    # fill empty space
    col.align = {AlignLeft, AlignTop, AlignRight, AlignBottom}
    rows[0].insertChild(col)
    cols1[i] = col

  rows[1] = Node()
  rows[1].layout = LayoutRow
  rows[1].align = {AlignTop, AlignBottom}

  var cols2 = default(array[5, Node])
  for i in 0 ..< 5:
    let col = Node()
    # fixed-size horizontally, fill vertically
    col.size = vec2(10, 0)
    col.align = {AlignTop, AlignBottom}
    rows[1].insertChild(col)
    cols2[i] = col

  # these columns have an inner item which sizes them
  rows[2] = Node()
  rows[2].layout = LayoutRow

  var cols3 = default(array[2, Node])
  for i in 0 ..< 2:
    let col = Node()
    let innerSizer = Node()
    # only the second one will have height
    innerSizer.size = vec2(25, float32(10 * i))
    # align to bottom, only should make a difference for first item
    col.align = {AlignBottom}
    col.insertChild(innerSizer)
    rows[2].insertChild(col)
    cols3[i] = col

  # row 4 should end up being 0 units tall after layout
  rows[3] = Node()
  rows[3].layout = LayoutRow
  rows[3].align = {AlignLeft, AlignRight}

  var cols4 = default(array[99, Node])
  for i in 0 ..< 99:
    let col = Node()
    rows[3].insertChild(col)
    cols4[i] = col

  # row 5 should be 10 pixels tall after layout, and each of
  # its columns should be 1 pixel wide
  rows[4] = Node()
  rows[4].layout = LayoutRow
  rows[4].align = {AlignLeft, AlignTop, AlignRight, AlignBottom}

  var cols5 = default(array[50, Node])
  for i in 0 ..< 50:
    let col = Node()
    col.align = {AlignLeft, AlignTop, AlignRight, AlignBottom}
    rows[4].insertChild(col)
    cols5[i] = col

  for i in 0 ..< numRows:
    mainChild.insertChild(rows[i])

  # repeat the run and tests multiple times to make sure we get the expected
  # results each time. 
  for i in 0 ..< 5:
    l.compute(root)

    check mainChild.computed == vec4(10, 10, 50, 40)

    # these rows should all be 10 units in height
    check rows[0].computed == vec4(10, 10, 50, 10)
    check rows[1].computed == vec4(10, 20, 50, 10)
    check rows[2].computed == vec4(10, 30, 50, 10)

    # this row should have 0 height
    check rows[3].computed == vec4(10, 40, 50, 0)
    check rows[4].computed == vec4(10, 40, 50, 10)

    for i in 0 ..< 5:
      # each of these should be 10 units wide, and stacked horizontally
      check cols1[i].computed == vec4(float32(10 + 10 * i), 10, 10, 10)

    # the cols in the second row are similar to first row
    for i in 0 ..< 5:
      check cols2[i].computed == vec4(float32(10 + 10 * i), 20, 10, 10)

    # leftmost (first of two items), aligned to bottom of row, 0 units tall
    check cols3[0].computed == vec4(10, 40, 25, 0)

    # rightmost (second of two items), same height as row, which is 10 units tall
    check cols3[1].computed == vec4(35, 30, 25, 10)

    # these should all have size 0 and be in the middle of the row
    for i in 0 ..< 99:
      check cols4[i].computed == vec4(25 + 10, 40, 0, 0)

    # these should all be 1 unit wide and 10 units tall
    for i in 0 ..< 50:
      check cols5[i].computed == vec4(float32(10 + i), 40, 1, 10)

proc main() =
  let numRun = 100000

  var
    l = default(Context)
    total = default(MonoTime)

  for i in 0 ..< numRun:
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