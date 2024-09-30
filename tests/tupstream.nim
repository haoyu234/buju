import unittest

import buju
import ./debug

test "upstream_issue15":
  var l: Layout
  defer:
    l.dump("dumps/upstream_issue15.png")

  let root = l.node()
  l.setSize(root, vec2(1, 100))

  let row = l.node()
  l.setBoxFlags(row, LayoutBoxRow)
  l.insertChild(root, row)

  let child = l.node()
  l.setSize(child, vec2(1, 50))
  l.setMargin(child, vec4(0, 0, 0, 10))
  l.insertChild(row, child)

  l.compute()

  check l.computed(root) == vec4(0, 0, 1, 100)
  check l.computed(row) == vec4(0, 20, 1, 60)
  check l.computed(child) == vec4(0, 20, 1, 50)