import buju
import unittest

import ./utils

# Locks the engine invariant "size is a HARD MINIMUM" (Family D): a node may only
# be grown by stretch, never shrunk below its explicit size or its own padding
# box. Each scenario is written three ways (Column, Row, Free) as isomorphic
# trees differing only in axis/direction, so an axis-specific fix would fail one.

# Invariant A: cross-axis stretch keeps explicit size when it overflows the
# parent, and fills the parent when smaller.
test2 "floor_cross_col_keeps_size_when_larger_than_parent":
  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setSize(col, [float32(400), 600])
  l.setCrossAxisAlign(col, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignLeft, AlignRight})   # cross stretch (horizontal)
  l.setSize(child, [float32(500), 50])         # explicit cross size > parent
  l.insertChild(col, child)
  l.compute(col)
  check l.computed(col) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 275, 500, 50]

test2 "floor_cross_row_keeps_size_when_larger_than_parent":
  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setSize(row, [float32(600), 400])          # wide, short: cross = vertical
  l.setCrossAxisAlign(row, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignTop, AlignBottom})   # cross stretch (vertical)
  l.setSize(child, [float32(100), 500])        # explicit cross size > parent
  l.insertChild(row, child)
  l.compute(row)
  check l.computed(row) == [float32(0), 0, 600, 400]
  check l.computed(child) == [float32(250), 0, 100, 500]

test2 "floor_cross_free_keeps_size_when_larger_than_parent":
  let free = l.node()
  l.setLayout(free, LayoutFree)
  l.setSize(free, [float32(400), 600])
  l.setAlign(free, {AlignTop, AlignBottom})

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignLeft, AlignRight})   # stretch on horizontal edges
  l.setSize(child, [float32(500), 50])
  l.insertChild(free, child)
  l.compute(free)
  check l.computed(free) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 275, 500, 50]

# Invariant A2: cross-axis stretch fills the parent when the child is smaller.
test2 "floor_cross_col_fills_parent_when_size_smaller":
  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setSize(col, [float32(400), 600])
  l.setCrossAxisAlign(col, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignLeft, AlignRight})
  l.setSize(child, [float32(100), 50])
  l.insertChild(col, child)
  l.compute(col)
  check l.computed(col) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 275, 400, 50]

test2 "floor_cross_row_fills_parent_when_size_smaller":
  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setSize(row, [float32(600), 400])
  l.setCrossAxisAlign(row, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignTop, AlignBottom})
  l.setSize(child, [float32(100), 50])
  l.insertChild(row, child)
  l.compute(row)
  check l.computed(row) == [float32(0), 0, 600, 400]
  check l.computed(child) == [float32(250), 0, 100, 400]

# Invariant B: padding stretch keeps the node's OWN padding minimum (Family D
# fix). When the padding box exceeds the stretched size the node overflows
# rather than shrinking below it. Cross-axis stretch honors the padding box
# exactly like the Free case, matching CSS border-box.
test2 "floor_padding_free_keeps_own_minimum":
  let root = l.node()
  l.setLayout(root, LayoutFree)
  l.setAlign(root, {AlignLeft, AlignRight})
  l.setSize(root, [float32(399), 728])

  let n2 = l.node()
  l.setLayout(n2, LayoutFree)
  l.setAlign(n2, {AlignLeft, AlignTop, AlignRight, AlignBottom})
  l.setPadding(n2, [float32(216), 800, 512, 24])   # horiz 728, vert 824 > parent
  l.insertChild(root, n2)
  l.compute(root)
  check l.computed(root) == [float32(0), 0, 399, 728]
  check l.computed(n2) == [float32(0), 0, 728, 824]

test2 "floor_padding_col_keeps_own_minimum":
  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setSize(col, [float32(400), 600])
  l.setCrossAxisAlign(col, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignLeft, AlignRight})        # cross stretch (horizontal)
  l.setPadding(child, [float32(216), 0, 512, 0])    # horiz padding 728 > 400
  l.insertChild(col, child)
  l.compute(col)
  check l.computed(col) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 300, 728, 0]   # padding box is the floor

test2 "floor_padding_row_keeps_own_minimum":
  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setSize(row, [float32(600), 400])
  l.setCrossAxisAlign(row, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignTop, AlignBottom})        # cross stretch (vertical)
  l.setPadding(child, [float32(0), 216, 0, 512])    # vert padding 728 > 400
  l.insertChild(row, child)
  l.compute(row)
  check l.computed(row) == [float32(0), 0, 600, 400]
  check l.computed(child) == [float32(300), 0, 0, 728]   # padding box is the floor

# Invariant B2: padding stretch still FILLS the parent when the padding box is
# smaller than the stretched size (the non-overflow branch of Family D).
test2 "floor_padding_free_below_minimum_still_fills":
  let root = l.node()
  l.setLayout(root, LayoutFree)
  l.setAlign(root, {AlignLeft, AlignRight})
  l.setSize(root, [float32(399), 728])

  let n2 = l.node()
  l.setLayout(n2, LayoutFree)
  l.setAlign(n2, {AlignLeft, AlignTop, AlignRight, AlignBottom})
  l.setPadding(n2, [float32(10), 20, 30, 40])       # horiz 40, vert 60 < parent
  l.insertChild(root, n2)
  l.compute(root)
  check l.computed(root) == [float32(0), 0, 399, 728]
  check l.computed(n2) == [float32(0), 0, 399, 728]

test2 "floor_padding_col_below_minimum_still_fills":
  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setSize(col, [float32(400), 600])
  l.setCrossAxisAlign(col, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignLeft, AlignRight})
  l.setPadding(child, [float32(10), 0, 30, 0])      # horiz padding 40 < 400
  l.insertChild(col, child)
  l.compute(col)
  check l.computed(col) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 300, 400, 0]

test2 "floor_padding_row_below_minimum_still_fills":
  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setSize(row, [float32(600), 400])
  l.setCrossAxisAlign(row, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignTop, AlignBottom})
  l.setPadding(child, [float32(0), 10, 0, 30])      # vert padding 40 < 400
  l.insertChild(row, child)
  l.compute(row)
  check l.computed(row) == [float32(0), 0, 600, 400]
  check l.computed(child) == [float32(300), 0, 0, 400]

# Invariant A3: cross-axis NON-stretch keeps a DEFINITE size (the "no stretch"
# branch of A) — the child is aligned, not stretched, so explicit size is
# preserved exactly.
test2 "floor_cross_nostretch_keeps_definite_size":
  let col = l.node()
  l.setLayout(col, LayoutColumn)
  l.setSize(col, [float32(400), 600])
  l.setCrossAxisAlign(col, CrossAxisAlignStart)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setAlign(child, {AlignLeft})             # cross start, definite width
  l.setSize(child, [float32(100), 50])
  l.insertChild(col, child)
  l.compute(col)
  check l.computed(col) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(0), 275, 100, 50]

# Invariant C: the MAIN axis is never laid out below size either (the floor is
# axis-independent. This covers what A does not exercise).
test2 "floor_main_axis_never_below_size":
  let row = l.node()
  l.setLayout(row, LayoutRow)
  l.setSize(row, [float32(400), 600])

  let child = l.node()
  l.setLayout(child, LayoutFree)
  l.setSize(child, [float32(500), 50])
  l.insertChild(row, child)
  l.compute(row)
  check l.computed(row) == [float32(0), 0, 400, 600]
  check l.computed(child) == [float32(-50), 275, 500, 50]
