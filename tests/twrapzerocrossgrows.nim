import buju
import unittest

import ./utils

test2 "wrap_zero_cross_grows_column":
  let root = l.node()

  # A wrapping container with a zero cross size (width for a column) is
  # expanded by its children along the cross axis instead of being shrunk.
  l.setSize(root, [float32(0), 200])
  l.setMargin(root, [float32(50), 50, 50, 50])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)

  let node2 = l.node()
  l.setSize(node2, [float32(50), 50])
  l.setMargin(node2, [float32(5), 5, 5, 5])
  l.insertChild(root, node2)

  let node3 = l.node()
  l.setSize(node3, [float32(50), 50])
  l.setMargin(node3, [float32(5), 5, 5, 5])
  l.insertChild(node2, node3)

  l.compute(root)

  check l.computed(root) == [float32(50), 50, 60, 200]
  check l.computed(node2) == [float32(55), 125, 50, 50]
  check l.computed(node3) == [float32(60), 130, 50, 50]

test2 "wrap_zero_cross_grows_row":
  let root = l.node()

  # Isomorphic Row mirror: a wrapping container with a zero cross size (height
  # for a row) is expanded by its children along the cross axis.
  l.setSize(root, [float32(200), 0])
  l.setMargin(root, [float32(50), 50, 50, 50])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)

  let node2 = l.node()
  l.setSize(node2, [float32(50), 50])
  l.setMargin(node2, [float32(5), 5, 5, 5])
  l.insertChild(root, node2)

  let node3 = l.node()
  l.setSize(node3, [float32(50), 50])
  l.setMargin(node3, [float32(5), 5, 5, 5])
  l.insertChild(node2, node3)

  l.compute(root)

  check l.computed(root) == [float32(50), 50, 200, 60]
  check l.computed(node2) == [float32(125), 55, 50, 50]
  check l.computed(node3) == [float32(130), 60, 50, 50]
