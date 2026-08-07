import buju
import unittest

import ./utils

# A child's explicit cross-axis anchor overrides the parent stretch (align-items).
# an unset child inherits it. Isomorphic Row/Column mirror.

test2 "child_explicit_anchor_overrides_parent_stretch_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(200), 300])
  l.setMainAxisAlign(root, MainAxisAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)

  # Definite cross size (80). An OR engine would grow it, override keeps 80.
  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(80), 50])
  l.setAlign(child, {AlignLeft})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 200, 300]
  check l.computed(child) == [float32(0), 0, 80, 50]

test2 "child_explicit_anchor_overrides_parent_stretch_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(300), 200])
  l.setMainAxisAlign(root, MainAxisAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutColumn)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(50), 80])
  l.setAlign(child, {AlignTop})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 300, 200]
  check l.computed(child) == [float32(0), 0, 50, 80]

test2 "unset_child_inherits_parent_stretch_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(200), 300])
  l.setMainAxisAlign(root, MainAxisAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)

  # No setAlign -> inherits parent stretch.
  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(0), 50]) # indefinite cross size
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 200, 300]
  check l.computed(child) == [float32(0), 0, 200, 50]

test2 "unset_child_inherits_parent_stretch_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(300), 200])
  l.setMainAxisAlign(root, MainAxisAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutColumn)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(50), 0]) # indefinite cross size
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 300, 200]
  check l.computed(child) == [float32(0), 0, 50, 200]
