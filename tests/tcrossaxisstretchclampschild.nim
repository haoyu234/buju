import buju
import unittest

import ./utils

# A size-less container stretched on the cross axis by its parent is clamped to
# the parent's available content space, not grown to its own (overflowing)
# content. Isomorphic Row/Column mirror: Column cross axis is horizontal, Row cross axis is vertical.

test2 "cross_axis_stretch_clamps_child_to_parent_column":
  let outer = l.node()
  l.setLayout(outer, LayoutColumn)
  l.setSize(outer, [float32(360), 600])
  l.setCrossAxisAlign(outer, CrossAxisAlignStretch)
  l.setAlign(outer, {})

  let inner = l.node()
  l.setLayout(inner, LayoutColumn)
  l.setAlign(inner, {AlignTop, AlignBottom})

  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setAlign(row, {AlignLeft, AlignRight})

  let leafA = l.node()
  l.setLayout(leafA, LayoutRow)
  l.setSize(leafA, [float32(360), 0])

  let leafB = l.node()
  l.setLayout(leafB, LayoutRow)
  l.setSize(leafB, [float32(360), 0])

  l.insertChild(outer, inner)
  l.insertChild(inner, row)
  l.insertChild(row, leafA)
  l.insertChild(row, leafB)

  l.compute(outer)

  # outer keeps its explicit size
  check l.computed(outer) == [float32(0), 0, 360, 600]
  # inner clamped to outer width (360), not its content (720)
  check l.computed(inner) == [float32(0), 0, 360, 600]
  # row stretched to inner width (360)
  check l.computed(row) == [float32(0), 300, 360, 0]
  # leaves keep explicit width. X overflows (no clipping) so only width matters
  check l.computed(leafA) == [float32(-180), 300, 360, 0]
  check l.computed(leafB) == [float32(180), 300, 360, 0]

test2 "cross_axis_stretch_clamps_child_to_parent_row":
  let outer = l.node()
  l.setLayout(outer, LayoutRow)
  l.setSize(outer, [float32(600), 360])
  l.setCrossAxisAlign(outer, CrossAxisAlignStretch)
  l.setAlign(outer, {})

  let inner = l.node()
  l.setLayout(inner, LayoutRow)
  l.setAlign(inner, {AlignLeft, AlignRight})

  let row = l.node()
  l.setLayout(row, LayoutColumn)
  l.setAlign(row, {AlignTop, AlignBottom})

  let leafA = l.node()
  l.setLayout(leafA, LayoutColumn)
  l.setSize(leafA, [float32(0), 360])

  let leafB = l.node()
  l.setLayout(leafB, LayoutColumn)
  l.setSize(leafB, [float32(0), 360])

  l.insertChild(outer, inner)
  l.insertChild(inner, row)
  l.insertChild(row, leafA)
  l.insertChild(row, leafB)

  l.compute(outer)

  check l.computed(outer) == [float32(0), 0, 600, 360]
  check l.computed(inner) == [float32(0), 0, 600, 360]
  check l.computed(row) == [float32(300), 0, 0, 360]
  check l.computed(leafA) == [float32(300), -180, 0, 360]
  check l.computed(leafB) == [float32(300), 180, 0, 360]
