import buju
import unittest

import ./utils

# Locks the child-level `AlignMiddle` flag (distinct from the container-level
# MainAxisAlignMiddle / CrossAxisAlignMiddle). Resolved per axis by toAxisAlign:
# Free centers both axes. Flex cross axis centers and overrides parent
# crossAxisAlign (incl. stretch). Flex main axis only the same-axis opposing
# pair (Left+Right / Top+Bottom) stretches, AlignMiddle carries no stretch
# effect. Each flex scenario is mirrored for Column and Row.

test2 "align_middle_overrides_parent_cross_start_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(300), 200])
  l.setMainAxisAlign(root, MainAxisAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(100), 50])
  l.setAlign(child, {AlignMiddle})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 300, 200]
  check l.computed(child) == [float32(0), 75, 100, 50]

test2 "align_middle_overrides_parent_cross_start_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(200), 300])
  l.setMainAxisAlign(root, MainAxisAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)

  let child = l.node()
  l.setLayout(child, LayoutColumn)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(50), 100])
  l.setAlign(child, {AlignMiddle})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 200, 300]
  check l.computed(child) == [float32(75), 0, 50, 100]

test2 "align_middle_overrides_parent_cross_stretch_row":
  # Parent stretch must be overridden, not inherited.
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(300), 200])
  l.setMainAxisAlign(root, MainAxisAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutRow)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(100), 50])
  l.setAlign(child, {AlignMiddle})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 300, 200]
  check l.computed(child) == [float32(0), 75, 100, 50]

test2 "align_middle_overrides_parent_cross_stretch_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(200), 300])
  l.setMainAxisAlign(root, MainAxisAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStretch)

  let child = l.node()
  l.setLayout(child, LayoutColumn)
  l.setWrap(child, WrapNoWrap)
  l.setSize(child, [float32(50), 100])
  l.setAlign(child, {AlignMiddle})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 200, 300]
  check l.computed(child) == [float32(75), 0, 50, 100]

test2 "align_middle_free_centers_both_axes":
  # Free centers both axes, unlike flex.
  let root = l.node()
  l.setLayout(root, LayoutFree)
  l.setSize(root, [float32(300), 200])

  let child = l.node()
  l.setLayout(child, LayoutFree)
  l.setSize(child, [float32(100), 50])
  l.setAlign(child, {AlignMiddle})
  l.insertChild(root, child)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 300, 200]
  check l.computed(child) == [float32(100), 75, 100, 50]

test2 "align_middle_no_main_axis_stretch_row":
  # Definitive regression: only the opposing pair stretches, AlignMiddle does not.
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(300), 200])
  l.setMainAxisAlign(root, MainAxisAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)

  let a = l.node()
  l.setLayout(a, LayoutRow)
  l.setWrap(a, WrapNoWrap)
  l.setSize(a, [float32(0), 50])
  l.setAlign(a, {AlignMiddle})
  l.insertChild(root, a)

  let b = l.node()
  l.setLayout(b, LayoutRow)
  l.setWrap(b, WrapNoWrap)
  l.setSize(b, [float32(0), 50])
  l.setAlign(b, {AlignLeft, AlignRight})
  l.insertChild(root, b)

  l.compute(root)

  check l.computed(a) == [float32(0), 75, 0, 50]
  check l.computed(b) == [float32(0), 0, 300, 50]

test2 "align_middle_no_main_axis_stretch_column":
  let root = l.node()
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapNoWrap)
  l.setSize(root, [float32(200), 300])
  l.setMainAxisAlign(root, MainAxisAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)

  let a = l.node()
  l.setLayout(a, LayoutColumn)
  l.setWrap(a, WrapNoWrap)
  l.setSize(a, [float32(50), 0])
  l.setAlign(a, {AlignMiddle})
  l.insertChild(root, a)

  let b = l.node()
  l.setLayout(b, LayoutColumn)
  l.setWrap(b, WrapNoWrap)
  l.setSize(b, [float32(50), 0])
  l.setAlign(b, {AlignTop, AlignBottom})
  l.insertChild(root, b)

  l.compute(root)

  check l.computed(a) == [float32(75), 0, 50, 0]
  check l.computed(b) == [float32(0), 0, 50, 300]
