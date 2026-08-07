import buju
import unittest

import ./utils

# Cross-axis overflow must be CENTERED, not clamped: a child wider/taller than
# its parent is centered and may sit at a NEGATIVE offset (overflowing both
# sides equally). This guards the case a naive "clamp to parent" impl would get
# wrong. Each scenario is written for Column (cross = horizontal) and Row
# (cross = vertical) so an axis-specific regression fails one of the pair.

test2 "cross_overflow_center_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(288), 0])
  l.setMainAxisAlign(root, MainAxisAlignMiddle)
  l.setCrossAxisAlign(root, CrossAxisAlignMiddle)

  let child = l.node()
  l.setLayout(child, LayoutColumn)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(1000), 100])
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 288, 100]
  check l.computed(child) == [float32(-356), 0, 1000, 100]

test2 "cross_overflow_center_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(0), 288])
  l.setMainAxisAlign(root, MainAxisAlignMiddle)
  l.setCrossAxisAlign(root, CrossAxisAlignMiddle)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(100), 1000])
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 288]
  check l.computed(child) == [float32(0), -356, 100, 1000]

test2 "cross_fits_center_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(288), 0])
  l.setMainAxisAlign(root, MainAxisAlignMiddle)
  l.setCrossAxisAlign(root, CrossAxisAlignMiddle)

  let child = l.node()
  l.setLayout(child, LayoutColumn)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(200), 100])
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 288, 100]
  check l.computed(child) == [float32(44), 0, 200, 100]

test2 "cross_fits_center_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(0), 288])
  l.setMainAxisAlign(root, MainAxisAlignMiddle)
  l.setCrossAxisAlign(root, CrossAxisAlignMiddle)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(100), 200])
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 288]
  check l.computed(child) == [float32(0), 44, 100, 200]
