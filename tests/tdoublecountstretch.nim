import buju
import unittest

import ./utils

# Reproduces the historical cross-axis stretch double-count concern: a
# definite-size child with padding + margin, stretched on the cross axis.
# Stretch forces w = space - margins. Padding is inside that border-box,
# margins outside (subtracted once), so footprint == space and the parent is
# not inflated. Isomorphic Row/Column mirror.

test2 "stretch_definite_child_padding_margin_no_double_count_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setSize(root, [float32(400), 600])
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)   # children stretch on width
  l.setAlign(root, {})

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(100), 50])               # definite width 100
  l.setPadding(child, [float32(10), 10, 10, 10])     # 10 each side
  l.setMargin(child, [float32(5), float32(5), float32(5), float32(5)])  # 5 each side
  l.setAlign(child, {AlignLeft, AlignRight})        # cross stretch (force fill)

  l.insertChild(root, child)
  l.compute(root)

  check l.computed(root) == [float32(0), 0, 400, 600]          # root NOT inflated
  check l.computed(child) == [float32(5), 275, 390, 50]        # child fills, no double-count
  check l.computed(child)[2] + float32(5) + float32(5) == float32(400)  # footprint == space

test2 "stretch_definite_child_padding_margin_no_double_count_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setSize(root, [float32(600), 400])
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)   # children stretch on height
  l.setAlign(root, {})

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(50), 100])               # definite height 100
  l.setPadding(child, [float32(10), 10, 10, 10])     # 10 each side
  l.setMargin(child, [float32(5), float32(5), float32(5), float32(5)])  # 5 each side
  l.setAlign(child, {AlignTop, AlignBottom})        # cross stretch (force fill)

  l.insertChild(root, child)
  l.compute(root)

  check l.computed(root) == [float32(0), 0, 600, 400]          # root NOT inflated
  check l.computed(child) == [float32(275), 5, 50, 390]        # child fills, no double-count
  check l.computed(child)[3] + float32(5) + float32(5) == float32(400)  # footprint == space

test2 "stretch_definite_child_no_padding_no_margin_fills_parent_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setSize(root, [float32(400), 600])
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)
  l.setAlign(root, {})

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(100), 50])
  l.setAlign(child, {AlignLeft, AlignRight})

  l.insertChild(root, child)
  l.compute(root)

  check l.computed(root) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 275, 400, 50]        # fills 400 exactly

test2 "stretch_definite_child_no_padding_no_margin_fills_parent_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setSize(root, [float32(600), 400])
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)
  l.setAlign(root, {})

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setSize(child, [float32(50), 100])
  l.setAlign(child, {AlignTop, AlignBottom})

  l.insertChild(root, child)
  l.compute(root)

  check l.computed(root) == [float32(0), 0, 600, 400]
  check l.computed(child) == [float32(275), 0, 50, 400]        # fills 400 exactly
