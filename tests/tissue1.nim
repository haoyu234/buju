import unittest

import buju
import ./utils

test2 "issue_1":
  let root = l.node()
  l.setSize(root, [float32(200), 200])
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
