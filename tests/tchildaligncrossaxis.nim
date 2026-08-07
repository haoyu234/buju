import buju
import unittest

import ./utils

# Cross-axis align-items:stretch (CSS-aligned): an indefinite child is stretched
# to fill the available content space. A definite child keeps its size. Isomorphic Row/Column mirror.

test2 "indefinite_child_under_stretch_parent_is_stretched_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setSize(root, [float32(300), 100])
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)
  l.setAlign(root, {})

  let child = l.node()
  l.setSize(child, [float32(0), 50])   # auto width
  l.setAlign(child, {})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 300, 100]
  check l.computed(child) == [float32(0), 25, 300, 50]

test2 "indefinite_child_under_stretch_parent_is_stretched_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setSize(root, [float32(100), 300])
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)
  l.setAlign(root, {})

  let child = l.node()
  l.setSize(child, [float32(50), 0])   # auto height
  l.setAlign(child, {})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 300]
  check l.computed(child) == [float32(25), 0, 50, 300]

test2 "definite_child_under_non_stretch_parent_keeps_own_size_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setSize(root, [float32(300), 100])
  l.setCrossAxisAlign(root, CrossAxisAlignStart)
  l.setAlign(root, {})

  let child = l.node()
  l.setSize(child, [float32(50), 50])   # width 50
  l.setAlign(child, {AlignLeft})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 300, 100]
  check l.computed(child) == [float32(0), 25, 50, 50]

test2 "definite_child_under_non_stretch_parent_keeps_own_size_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setSize(root, [float32(100), 300])
  l.setCrossAxisAlign(root, CrossAxisAlignStart)
  l.setAlign(root, {})

  let child = l.node()
  l.setSize(child, [float32(50), 50])   # height 50
  l.setAlign(child, {AlignTop})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 300]
  check l.computed(child) == [float32(25), 0, 50, 50]
