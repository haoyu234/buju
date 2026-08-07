import buju
import unittest

import ./utils

# With an auto main axis (size[main] == 0) there is no wrap bound, so all
# children stay on one line. Root main extent is the sum of child main extents
# plus (childCount - 1) * mainGap. Isomorphic Row/Column mirror: Column main axis is y, Row main axis is x.

test2 "wrap_main_auto_single_line_gap_column":
  let root = l.node()
  l.setSize(root, [float32(100), 0])       # cross (x) explicit 100, main (y) auto
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)
  l.setGap(root, [float32(0), 10])         # main-axis gap = 10, cross gap = 0
  l.setMainAxisAlign(root, MainAxisAlignStart)

  let
    a = l.node()
    b = l.node()
    c = l.node()

  l.setSize(a, [float32(30), 50])
  l.setSize(b, [float32(30), 60])
  l.setSize(c, [float32(30), 40])
  l.insertChild(root, a)
  l.insertChild(root, b)
  l.insertChild(root, c)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 170]

test2 "wrap_main_auto_single_line_gap_row":
  let root = l.node()
  l.setSize(root, [float32(0), 100])        # main (x) auto, cross (y) explicit 100
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)
  l.setGap(root, [float32(10), 0])          # main-axis gap = 10, cross gap = 0
  l.setMainAxisAlign(root, MainAxisAlignStart)

  let
    a = l.node()
    b = l.node()
    c = l.node()

  l.setSize(a, [float32(50), 30])
  l.setSize(b, [float32(60), 30])
  l.setSize(c, [float32(40), 30])
  l.insertChild(root, a)
  l.insertChild(root, b)
  l.insertChild(root, c)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 170, 100]

test2 "wrap_main_auto_single_line_no_gap_column":
  let root = l.node()
  l.setSize(root, [float32(100), 0])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)
  l.setGap(root, [float32(0), 0])
  l.setMainAxisAlign(root, MainAxisAlignStart)

  let
    a = l.node()
    b = l.node()
    c = l.node()

  l.setSize(a, [float32(30), 50])
  l.setSize(b, [float32(30), 60])
  l.setSize(c, [float32(30), 40])
  l.insertChild(root, a)
  l.insertChild(root, b)
  l.insertChild(root, c)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 150]

test2 "wrap_main_auto_single_line_no_gap_row":
  let root = l.node()
  l.setSize(root, [float32(0), 100])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)
  l.setGap(root, [float32(0), 0])
  l.setMainAxisAlign(root, MainAxisAlignStart)

  let
    a = l.node()
    b = l.node()
    c = l.node()

  l.setSize(a, [float32(50), 30])
  l.setSize(b, [float32(60), 30])
  l.setSize(c, [float32(40), 30])
  l.insertChild(root, a)
  l.insertChild(root, b)
  l.insertChild(root, c)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 150, 100]

test2 "wrap_main_auto_four_children_column":
  # More children -> more intra-line gaps, all counted exactly once.
  let root = l.node()
  l.setSize(root, [float32(100), 0])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)
  l.setGap(root, [float32(0), 10])
  l.setMainAxisAlign(root, MainAxisAlignStart)

  let
    a = l.node()
    b = l.node()
    c = l.node()
    d = l.node()

  l.setSize(a, [float32(30), 50])
  l.setSize(b, [float32(30), 60])
  l.setSize(c, [float32(30), 40])
  l.setSize(d, [float32(30), 30])
  l.insertChild(root, a)
  l.insertChild(root, b)
  l.insertChild(root, c)
  l.insertChild(root, d)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 100, 210]

test2 "wrap_main_auto_four_children_row":
  let root = l.node()
  l.setSize(root, [float32(0), 100])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)
  l.setGap(root, [float32(10), 0])
  l.setMainAxisAlign(root, MainAxisAlignStart)

  let
    a = l.node()
    b = l.node()
    c = l.node()
    d = l.node()

  l.setSize(a, [float32(50), 30])
  l.setSize(b, [float32(60), 30])
  l.setSize(c, [float32(40), 30])
  l.setSize(d, [float32(30), 30])
  l.insertChild(root, a)
  l.insertChild(root, b)
  l.insertChild(root, c)
  l.insertChild(root, d)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 210, 100]

test2 "wrap_main_auto_both_axes_auto_column":
  let root = l.node()
  l.setSize(root, [float32(0), 0])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)
  l.setGap(root, [float32(20), 10])
  l.setMainAxisAlign(root, MainAxisAlignStart)

  let
    a = l.node()
    b = l.node()
    c = l.node()

  l.setSize(a, [float32(30), 50])
  l.setSize(b, [float32(30), 60])
  l.setSize(c, [float32(35), 40])
  l.insertChild(root, a)
  l.insertChild(root, b)
  l.insertChild(root, c)

  l.compute(root)

  # main = 50 + 10 + 60 + 10 + 40 = 170, cross = max(30, 30, 35) = 35
  check l.computed(root) == [float32(0), 0, 35, 170]

test2 "wrap_main_auto_both_axes_auto_row":
  let root = l.node()
  l.setSize(root, [float32(0), 0])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)
  l.setGap(root, [float32(10), 20])
  l.setMainAxisAlign(root, MainAxisAlignStart)

  let
    a = l.node()
    b = l.node()
    c = l.node()

  l.setSize(a, [float32(50), 30])
  l.setSize(b, [float32(60), 30])
  l.setSize(c, [float32(40), 35])
  l.insertChild(root, a)
  l.insertChild(root, b)
  l.insertChild(root, c)

  l.compute(root)

  # main = 50 + 10 + 60 + 10 + 40 = 170, cross = max(30, 30, 35) = 35
  check l.computed(root) == [float32(0), 0, 170, 35]
