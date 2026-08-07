import buju
import unittest

import ./utils

test2 "padding_free_empty_container":
  let root = l.node()
  l.setLayout(root, LayoutFree)
  l.setPadding(root, [float32(5), 5, 5, 5])

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 10, 10]

test2 "padding_free_child_offset":
  let root = l.node()
  l.setLayout(root, LayoutFree)
  l.setPadding(root, [float32(5), 5, 5, 5])

  let n2 = l.node()
  l.setSize(n2, [float32(100), 100])
  l.insertChild(root, n2)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 110, 110]
  check l.computed(n2) == [float32(5), 5, 100, 100]

test2 "padding_asymmetric_horizontal_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setPadding(root, [float32(20), 0, 220, 0])

  let n2 = l.node()
  l.insertChild(root, n2)

  let n3 = l.node()
  l.setSize(n3, [float32(1000), 1000])
  l.insertChild(root, n3)

  let n4 = l.node()
  l.setSize(n4, [float32(1000), 1000])
  l.insertChild(root, n4)

  let n5 = l.node()
  l.setSize(n5, [float32(829), 896])
  l.insertChild(n4, n5)

  let n6 = l.node()
  l.setSize(n6, [float32(1000), 1000])
  l.insertChild(root, n6)

  let n7 = l.node()
  l.setSize(n7, [float32(1000), 1000])
  l.insertChild(n6, n7)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 1240, 3000]
  check l.computed(n2) == [float32(520), 0, 0, 0]
  check l.computed(n3) == [float32(20), 0, 1000, 1000]
  check l.computed(n4) == [float32(20), 1000, 1000, 1000]
  check l.computed(n5) == [float32(105.5), 1052, 829, 896]
  check l.computed(n6) == [float32(20), 2000, 1000, 1000]
  check l.computed(n7) == [float32(20), 2000, 1000, 1000]

test2 "padding_asymmetric_horizontal_row":
  # Isomorphic Row mirror: the padding box is transposed so the asymmetric insets swap horizontal to vertical.
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setPadding(root, [float32(0), 20, 0, 220])

  let n2 = l.node()
  l.insertChild(root, n2)

  let n3 = l.node()
  l.setSize(n3, [float32(1000), 1000])
  l.insertChild(root, n3)

  let n4 = l.node()
  l.setSize(n4, [float32(1000), 1000])
  l.insertChild(root, n4)

  let n5 = l.node()
  l.setSize(n5, [float32(896), 829])
  l.insertChild(n4, n5)

  let n6 = l.node()
  l.setSize(n6, [float32(1000), 1000])
  l.insertChild(root, n6)

  let n7 = l.node()
  l.setSize(n7, [float32(1000), 1000])
  l.insertChild(n6, n7)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 3000, 1240]
  check l.computed(n2) == [float32(0), 520, 0, 0]
  check l.computed(n3) == [float32(0), 20, 1000, 1000]
  check l.computed(n4) == [float32(1000), 20, 1000, 1000]
  check l.computed(n5) == [float32(1052), 105.5, 896, 829]
  check l.computed(n6) == [float32(2000), 20, 1000, 1000]
  check l.computed(n7) == [float32(2000), 20, 1000, 1000]
