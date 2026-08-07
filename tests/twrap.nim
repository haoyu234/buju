import buju
import unittest

import ./utils

test2 "wrap_cross_auto_column":
  # Auto cross width = sum of wrapped column widths, not a single column.
  let root = l.node()

  l.setSize(root, [float32(0), 120])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)

  let node1 = l.node()
  l.setSize(node1, [float32(50), 50])
  l.insertChild(root, node1)

  let node2 = l.node()
  l.setSize(node2, [float32(50), 60])
  l.insertChild(root, node2)

  let node3 = l.node()
  l.setSize(node3, [float32(50), 50])
  l.insertChild(root, node3)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 120]
  check l.computed(node1) == [float32(0), 5, 50, 50]
  check l.computed(node2) == [float32(0), 55, 50, 60]
  check l.computed(node3) == [float32(50), 35, 50, 50]

test2 "wrap_cross_auto_row":
  let root = l.node()

  l.setSize(root, [float32(120), 0])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)

  let node1 = l.node()
  l.setSize(node1, [float32(50), 50])
  l.insertChild(root, node1)

  let node2 = l.node()
  l.setSize(node2, [float32(60), 50])
  l.insertChild(root, node2)

  let node3 = l.node()
  l.setSize(node3, [float32(50), 50])
  l.insertChild(root, node3)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 120, 100]
  check l.computed(node1) == [float32(5), 0, 50, 50]
  check l.computed(node2) == [float32(55), 0, 60, 50]
  check l.computed(node3) == [float32(35), 50, 50, 50]

test2 "wrap_expend_fill_column":
  let root = l.node()

  l.setSize(root, [float32(100), 100])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)

  let node1 = l.node()
  l.setSize(node1, [float32(50), 50])
  l.insertChild(root, node1)

  let node2 = l.node()
  l.setSize(node2, [float32(50), 60])
  l.setAlign(node2, {AlignTop, AlignBottom})
  l.insertChild(root, node2)

  let node3 = l.node()
  l.setSize(node3, [float32(50), 50])
  l.insertChild(root, node3)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 100]
  check l.computed(node1) == [float32(-25), 25, 50, 50]
  check l.computed(node2) == [float32(25), 0, 50, 100]
  check l.computed(node3) == [float32(75), 25, 50, 50]

test2 "wrap_expend_fill_row":
  let root = l.node()

  l.setSize(root, [float32(100), 100])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)

  let node1 = l.node()
  l.setSize(node1, [float32(50), 50])
  l.insertChild(root, node1)

  let node2 = l.node()
  l.setSize(node2, [float32(60), 50])
  l.setAlign(node2, {AlignLeft, AlignRight})
  l.insertChild(root, node2)

  let node3 = l.node()
  l.setSize(node3, [float32(50), 50])
  l.insertChild(root, node3)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 100]
  check l.computed(node1) == [float32(25), -25, 50, 50]
  check l.computed(node2) == [float32(0), 25, 100, 50]
  check l.computed(node3) == [float32(25), 75, 50, 50]

test2 "wrap_overflow_column":
  let root = l.node()

  l.setSize(root, [float32(100), 100])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)

  let node1 = l.node()
  l.setSize(node1, [float32(50), 50])
  l.insertChild(root, node1)

  let node2 = l.node()
  l.setSize(node2, [float32(50), 150]) # overflow
  l.insertChild(root, node2)

  let node3 = l.node()
  l.setSize(node3, [float32(50), 50])
  l.insertChild(root, node3)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 100]
  check l.computed(node1) == [float32(-25), 25, 50, 50]
  check l.computed(node2) == [float32(25), -25, 50, 150]
  check l.computed(node3) == [float32(75), 25, 50, 50]

test2 "wrap_overflow_row":
  let root = l.node()

  l.setSize(root, [float32(100), 100])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)

  let node1 = l.node()
  l.setSize(node1, [float32(50), 50])
  l.insertChild(root, node1)

  let node2 = l.node()
  l.setSize(node2, [float32(150), 50]) # overflow
  l.insertChild(root, node2)

  let node3 = l.node()
  l.setSize(node3, [float32(50), 50])
  l.insertChild(root, node3)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 100]
  check l.computed(node1) == [float32(25), -25, 50, 50]
  check l.computed(node2) == [float32(-25), 25, 150, 50]
  check l.computed(node3) == [float32(25), 75, 50, 50]
