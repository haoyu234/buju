import unittest

import buju
import ./utils

test2 "upstream_issue15":
  let root = l.node()
  l.setSize(root, [float32(1), 100])

  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.insertChild(root, row)

  let child = l.node()
  l.setSize(child, [float32(1), 50])
  l.setMargin(child, [float32(0), 0, 0, 10])
  l.insertChild(row, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 1, 100]
  check l.computed(row) == [float32(0), 20, 1, 60]
  check l.computed(child) == [float32(0), 20, 1, 50]
