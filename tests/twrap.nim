import unittest

import buju
import ./utils

test2 "wrap_expend_fill":
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

test2 "wrap_overflow":
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
