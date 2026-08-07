import buju
import unittest

import ./utils

# Regression tests for upstream issue #15: a single child's margin propagates
# through the parent chain and offsets its siblings, instead of being absorbed
# locally. The Isomorphic Column mirror transposes every size and the one child
# margin so the bottom inset becomes a right inset.

test2 "upstream_issue15_row":
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

test2 "upstream_issue15_column":
  # Isomorphic Column mirror: every size and the single child margin are transposed so the bottom inset becomes a right inset.
  let root = l.node()
  l.setSize(root, [float32(100), 1])

  let column = l.node()
  l.setLayout(column, LayoutColumn)
  l.insertChild(root, column)

  let child = l.node()
  l.setSize(child, [float32(50), 1])
  l.setMargin(child, [float32(0), 0, 10, 0])
  l.insertChild(column, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 1]
  check l.computed(column) == [float32(20), 0, 60, 1]
  check l.computed(child) == [float32(20), 0, 50, 1]
