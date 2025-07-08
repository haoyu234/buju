import unittest

import buju
import vmath

test "issue_1":
  let root = Node()
  root.size = vec2(200, 200)
  root.margin = vec4(50, 50, 50, 50)
  root.wrap = WrapWrap
  root.layout = LayoutColumn

  let node1 = Node()
  node1.size = vec2(50, 50)
  node1.margin = vec4(5, 5, 5, 5)
  root.insertChild(node1)

  let node2 = Node()
  node2.size = vec2(50, 50)
  node2.margin = vec4(5, 5, 5, 5)
  node1.insertChild(node2)

  compute(root)

  check root.computed == vec4(50, 50, 60, 200)
  check node1.computed == vec4(55, 125, 50, 50)
  check node2.computed == vec4(60, 130, 50, 50)
