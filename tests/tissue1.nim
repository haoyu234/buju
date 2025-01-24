import unittest

import buju
import ./utils

test2 "issue_1":
  let root = l.node()
  l.setSize(root, vec2(200, 200))
  l.setMargin(root, vec4(50, 50, 50, 50))
  l.setBoxFlags(root, LayoutBoxWrap or LayoutBoxColumn)

  let node2 = l.node()
  l.setSize(node2, vec2(50, 50))
  l.setMargin(node2, vec4(5, 5, 5, 5))
  l.insertChild(root, node2)

  let node3 = l.node()
  l.setSize(node3, vec2(50, 50))
  l.setMargin(node3, vec4(5, 5, 5, 5))
  l.insertChild(node2, node3)

  l.compute(root)

  check l.computed(root) == vec4(50, 50, 60, 200)
  check l.computed(node2) == vec4(55, 125, 50, 50)
  check l.computed(node3) == vec4(60, 130, 50, 50)
