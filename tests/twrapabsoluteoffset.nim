import buju
import unittest

import ./utils

# Regression for crash-86: a WrapWrap container nested >= 2 levels deep, at a
# non-zero absolute offset, used to leak that offset into its children's
# main-axis coordinate (stored local instead of absolute, cross axis was fine).
# Pre-fix: childC.y == 275.0 (local). Fixed: 525.0 (= 250 + 275). Isomorphic Row/Column mirror: Column main axis is y, Row main axis is x.

test2 "wrap_nested_container_child_absolute_main_axis_offset_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setSize(root, [float32(1000), 1000])
  l.setAlign(root, {})

  # Preceding sized sibling pushes the wrap container to a non-zero y offset.
  let spacer = l.node()
  l.setLayout(spacer, LayoutFree)
  l.setAlign(spacer, {AlignTop, AlignLeft})
  l.setSize(spacer, [float32(10), 100])
  l.insertChild(root, spacer)

  let wrapC = l.node()
  l.setLayout(wrapC, LayoutColumn)
  l.setWrap(wrapC, WrapWrap)
  l.setAlign(wrapC, {AlignTop, AlignLeft})
  l.setSize(wrapC, [float32(500), 600])
  l.insertChild(root, wrapC)

  let childC = l.node()
  l.setLayout(childC, LayoutFree)
  l.setAlign(childC, {AlignTop, AlignLeft})
  l.setSize(childC, [float32(50), 50])
  l.insertChild(wrapC, childC)

  l.compute(root)

  # Precondition: the wrap container must sit at a non-zero absolute offset,
  # otherwise local == absolute and the bug is invisible.
  check l.computed(wrapC) == [float32(0), 250, 500, 600]

  # Child main-axis (y) must include the wrap container's absolute offset.
  # Pre-fix value was [225, 275, 50, 50] (local y, bug).
  check l.computed(childC) == [float32(225), 525, 50, 50]

test2 "wrap_nested_container_child_absolute_main_axis_offset_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setSize(root, [float32(1000), 1000])
  l.setAlign(root, {})

  let spacer = l.node()
  l.setLayout(spacer, LayoutFree)
  l.setAlign(spacer, {AlignTop, AlignLeft})
  l.setSize(spacer, [float32(100), 10])
  l.insertChild(root, spacer)

  let wrapC = l.node()
  l.setLayout(wrapC, LayoutRow)
  l.setWrap(wrapC, WrapWrap)
  l.setAlign(wrapC, {AlignTop, AlignLeft})
  l.setSize(wrapC, [float32(600), 500])
  l.insertChild(root, wrapC)

  let childC = l.node()
  l.setLayout(childC, LayoutFree)
  l.setAlign(childC, {AlignTop, AlignLeft})
  l.setSize(childC, [float32(50), 50])
  l.insertChild(wrapC, childC)

  l.compute(root)

  check l.computed(wrapC) == [float32(250), 0, 600, 500]

  # Child main-axis (x) must include the wrap container's absolute offset.
  check l.computed(childC) == [float32(525), 225, 50, 50]
