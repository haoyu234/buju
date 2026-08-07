import buju
import unittest

import ./utils

# Child stretched on both axes (AlignLeft+Right cross, AlignTop+Bottom main)
# fills the parent. The size floor only grows it when padding demands. Mirrored
# for Column (main = y) and Row (main = x).

test2 "explicit_size_child_both_axes_stretch_column":
  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setSize(col, [float32(400), 600])

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignLeft, AlignRight, AlignTop, AlignBottom})  # both axes stretch
  l.setSize(child, [float32(0), 0])    # auto w/h

  l.insertChild(col, child)
  l.compute(col)
  check l.computed(col) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 0, 400, 600]

test2 "explicit_size_child_both_axes_stretch_row":
  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setSize(row, [float32(600), 400])

  let child = l.node()
  l.setLayout(child, LayoutColumn)
  l.setAlign(child, {AlignLeft, AlignRight, AlignTop, AlignBottom})
  l.setSize(child, [float32(0), 0])

  l.insertChild(row, child)
  l.compute(row)
  check l.computed(row) == [float32(0), 0, 600, 400]
  check l.computed(child) == [float32(0), 0, 600, 400]

test2 "stretched_by_free_parent_child_both_axes_stretch_column":
  let free = l.node()
  l.setLayout(free, LayoutFree)
  l.setSize(free, [float32(400), 600])

  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setAlign(col, {AlignTop, AlignBottom})   # stretch in main axis

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignLeft, AlignRight, AlignTop, AlignBottom})
  l.setSize(child, [float32(0), 0])

  l.insertChild(free, col)
  l.insertChild(col, child)
  l.compute(free)
  check l.computed(free) == [float32(0), 0, 400, 600]
  check l.computed(col) == [float32(200), 0, 0, 600]
  check l.computed(child) == [float32(200), 0, 0, 600]

test2 "stretched_by_free_parent_child_both_axes_stretch_row":
  let free = l.node()
  l.setLayout(free, LayoutFree)
  l.setSize(free, [float32(600), 400])

  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setAlign(row, {AlignLeft, AlignRight})   # stretch in main axis

  let child = l.node()
  l.setLayout(child, LayoutColumn)
  l.setAlign(child, {AlignLeft, AlignRight, AlignTop, AlignBottom})
  l.setSize(child, [float32(0), 0])

  l.insertChild(free, row)
  l.insertChild(row, child)
  l.compute(free)
  check l.computed(free) == [float32(0), 0, 600, 400]
  check l.computed(row) == [float32(0), 200, 600, 0]
  check l.computed(child) == [float32(0), 200, 600, 0]

test2 "parent_child_both_axes_stretch_column":
  let outer = l.node()
  l.setLayout(outer, LayoutColumn)
  l.setSize(outer, [float32(400), 600])

  let inner = l.node()
  l.setLayout(inner, LayoutColumn)
  l.setAlign(inner, {AlignLeft, AlignRight, AlignTop, AlignBottom})

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignLeft, AlignRight, AlignTop, AlignBottom})
  l.setSize(child, [float32(0), 0])

  l.insertChild(outer, inner)
  l.insertChild(inner, child)
  l.compute(outer)
  check l.computed(outer) == [float32(0), 0, 400, 600]
  check l.computed(inner) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 0, 400, 600]

test2 "parent_child_both_axes_stretch_row":
  let outer = l.node()
  l.setLayout(outer, LayoutRow)
  l.setSize(outer, [float32(600), 400])

  let inner = l.node()
  l.setLayout(inner, LayoutRow)
  l.setAlign(inner, {AlignLeft, AlignRight, AlignTop, AlignBottom})

  let child = l.node()
  l.setLayout(child, LayoutColumn)
  l.setAlign(child, {AlignLeft, AlignRight, AlignTop, AlignBottom})
  l.setSize(child, [float32(0), 0])

  l.insertChild(outer, inner)
  l.insertChild(inner, child)
  l.compute(outer)
  check l.computed(outer) == [float32(0), 0, 600, 400]
  check l.computed(inner) == [float32(0), 0, 600, 400]
  check l.computed(child) == [float32(0), 0, 600, 400]
