import unittest

import buju
import ./utils

test2 "upstream_issue15":
  let root = l.node()
  l.setSize(root, vec2(1, 100))

  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.insertChild(root, row)

  let child = l.node()
  l.setSize(child, vec2(1, 50))
  l.setMargin(child, vec4(0, 0, 0, 10))
  l.insertChild(row, child)

  l.compute(root)

  check l.computed(root) == vec4(0, 0, 1, 100)
  check l.computed(row) == vec4(0, 20, 1, 60)
  check l.computed(child) == vec4(0, 20, 1, 50)
