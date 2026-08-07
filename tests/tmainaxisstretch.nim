import buju
import unittest

import ./utils

# Main-axis stretch (opposing-anchor pair) fills free space. With no free space
# the child keeps its size. Isomorphic Row/Column mirror: Column main axis is y, Row main axis is x.

test2 "child_main_axis_stretch_fills_when_free_space_column":
  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setSize(col, [float32(400), 600])
  l.setCrossAxisAlign(col, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(200), 0])   # width 200, auto height
  l.setAlign(child, {AlignTop, AlignBottom})

  l.insertChild(col, child)
  l.compute(col)

  check l.computed(col) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 0, 400, 600]

test2 "child_main_axis_stretch_fills_when_free_space_row":
  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setSize(row, [float32(600), 400])
  l.setCrossAxisAlign(row, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(0), 200])   # auto width, height 200
  l.setAlign(child, {AlignLeft, AlignRight})

  l.insertChild(row, child)
  l.compute(row)

  check l.computed(row) == [float32(0), 0, 600, 400]
  check l.computed(child) == [float32(0), 0, 600, 400]

test2 "child_main_axis_stretch_noop_without_free_space_column":
  # No explicit height: no free space, child keeps its size.
  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setCrossAxisAlign(col, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(200), 100])   # width/height 200/100
  l.setAlign(child, {AlignTop, AlignBottom})

  l.insertChild(col, child)
  l.compute(col)

  check l.computed(col) == [float32(0), 0, 200, 100]
  check l.computed(child) == [float32(0), 0, 200, 100]

test2 "child_main_axis_stretch_noop_without_free_space_row":
  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setCrossAxisAlign(row, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(100), 200])
  l.setAlign(child, {AlignLeft, AlignRight})

  l.insertChild(row, child)
  l.compute(row)

  check l.computed(row) == [float32(0), 0, 100, 200]
  check l.computed(child) == [float32(0), 0, 100, 200]

test2 "child_cross_axis_stretch_fills_column":
  # Cross-axis stretch fills regardless of free space.
  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setSize(col, [float32(400), 600])
  l.setCrossAxisAlign(col, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(0), 150])   # auto width, height 150
  l.setAlign(child, {AlignLeft, AlignRight})

  l.insertChild(col, child)
  l.compute(col)

  check l.computed(col) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 225, 400, 150]

test2 "child_cross_axis_stretch_fills_row":
  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setSize(row, [float32(600), 400])
  l.setCrossAxisAlign(row, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(150), 0])   # width 150, auto height
  l.setAlign(child, {AlignTop, AlignBottom})

  l.insertChild(row, child)
  l.compute(row)

  check l.computed(row) == [float32(0), 0, 600, 400]
  check l.computed(child) == [float32(225), 0, 150, 400]

test2 "stretched_by_parent_main_axis_stretch_grandchild_fills_column":
  # Stretched by Free parent: column gets a definite height, grandchild fills it.
  let free = l.node()
  l.setLayout(free, LayoutFree)
  l.setSize(free, [float32(400), 600])

  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setAlign(col, {AlignTop, AlignBottom})   # stretch to fill Free parent

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(0), 150])   # auto width, height 150
  l.setAlign(child, {AlignLeft, AlignRight})   # horizontal stretch (cross)

  let grand = l.node()
  l.setLayout(grand, LayoutRow)
  l.setSize(grand, [float32(200), 0])   # auto height
  l.setAlign(grand, {AlignTop, AlignBottom})   # vertical stretch (main axis)

  l.insertChild(free, col)
  l.insertChild(col, child)
  l.insertChild(col, grand)
  l.compute(free)

  check l.computed(free) == [float32(0), 0, 400, 600]
  check l.computed(col) == [float32(100), 0, 200, 600]
  check l.computed(child) == [float32(100), 0, 200, 150]
  check l.computed(grand) == [float32(100), 150, 200, 450]

test2 "stretched_by_parent_main_axis_stretch_grandchild_fills_row":
  let free = l.node()
  l.setLayout(free, LayoutFree)
  l.setSize(free, [float32(600), 400])

  let col = l.node()
  l.setLayout(col, LayoutRow)
  l.setAlign(col, {AlignLeft, AlignRight})   # stretch to fill Free parent

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(150), 0])   # width 150, auto height
  l.setAlign(child, {AlignTop, AlignBottom})   # vertical stretch (cross)

  let grand = l.node()
  l.setLayout(grand, LayoutRow)
  l.setSize(grand, [float32(0), 200])   # auto width
  l.setAlign(grand, {AlignLeft, AlignRight})   # horizontal stretch (main axis)

  l.insertChild(free, col)
  l.insertChild(col, child)
  l.insertChild(col, grand)
  l.compute(free)

  check l.computed(free) == [float32(0), 0, 600, 400]
  check l.computed(col) == [float32(0), 100, 600, 200]
  check l.computed(child) == [float32(0), 100, 150, 200]
  check l.computed(grand) == [float32(150), 100, 450, 200]
