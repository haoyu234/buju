import buju
import unittest

import ./utils

template setup(layout: Layout, wrap: Wrap, size: array[2, float32]): untyped =
  let root {.inject.} = l.node()
  l.setLayout(root, layout)
  l.setWrap(root, wrap)
  l.setMainAxisAlign(root, MainAxisAlignMiddle)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)
  l.setCrossAxisLineAlign(root, CrossAxisLineAlignEnd)
  l.setAlign(root, {})
  l.setSize(root, size)
  l.setGap(root, [float32(793), 1])

  let n2 {.inject.} = l.node()
  l.setLayout(n2, LayoutFree)
  l.setMainAxisAlign(n2, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n2, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n2, CrossAxisLineAlignMiddle)
  l.setAlign(n2, {AlignLeft, AlignTop, AlignRight})
  l.setSize(n2, [float32(1000), 1000])
  l.insertChild(root, n2)

  let n3 {.inject.} = l.node()
  l.setLayout(n3, LayoutFree)
  l.setMainAxisAlign(n3, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n3, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n3, CrossAxisLineAlignMiddle)
  l.setAlign(n3, {})
  l.setSize(n3, [float32(1000), 1000])
  l.insertChild(root, n3)

  let n4 {.inject.} = l.node()
  l.setLayout(n4, LayoutFree)
  l.setMainAxisAlign(n4, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n4, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n4, CrossAxisLineAlignMiddle)
  l.setAlign(n4, {AlignLeft, AlignBottom})
  l.setSize(n4, [float32(288), 0])
  l.insertChild(root, n4)

  let n5 {.inject.} = l.node()
  l.setLayout(n5, LayoutFree)
  l.setMainAxisAlign(n5, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n5, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n5, CrossAxisLineAlignMiddle)
  l.setAlign(n5, {})
  l.setSize(n5, [float32(309), 528])
  l.insertChild(root, n5)

test2 "wrap_cross_auto_nowrap_column":
  # Primary (Column) case: auto cross size derived from content under no-wrap.
  setup(LayoutColumn, WrapNoWrap, [float32(0), 300])

  check int32(root) == 1
  check l.len == 5

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 1000, 300]

  check l.computed(n2) == [float32(0), -1115.5, 1000, 1000]
  check l.computed(n3) == [float32(0), -114.5, 1000, 1000]
  check l.computed(n4) == [float32(0), 886.5, 288, 0]
  check l.computed(n5) == [float32(0), 887.5, 309, 528]

test2 "wrap_cross_auto_nowrap_row":
  let root = l.node()
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapNoWrap)
  l.setMainAxisAlign(root, MainAxisAlignMiddle)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)
  l.setCrossAxisLineAlign(root, CrossAxisLineAlignEnd)
  l.setAlign(root, {})
  l.setSize(root, [float32(300), 0])
  l.setGap(root, [float32(1), 793])

  let n2 = l.node()
  l.setLayout(n2, LayoutFree)
  l.setMainAxisAlign(n2, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n2, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n2, CrossAxisLineAlignMiddle)
  l.setAlign(n2, {AlignTop, AlignLeft, AlignBottom})
  l.setSize(n2, [float32(1000), 1000])
  l.insertChild(root, n2)

  let n3 = l.node()
  l.setLayout(n3, LayoutFree)
  l.setMainAxisAlign(n3, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n3, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n3, CrossAxisLineAlignMiddle)
  l.setAlign(n3, {})
  l.setSize(n3, [float32(1000), 1000])
  l.insertChild(root, n3)

  let n4 = l.node()
  l.setLayout(n4, LayoutFree)
  l.setMainAxisAlign(n4, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n4, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n4, CrossAxisLineAlignMiddle)
  l.setAlign(n4, {AlignTop, AlignRight})
  l.setSize(n4, [float32(0), 288])
  l.insertChild(root, n4)

  let n5 = l.node()
  l.setLayout(n5, LayoutFree)
  l.setMainAxisAlign(n5, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n5, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n5, CrossAxisLineAlignMiddle)
  l.setAlign(n5, {})
  l.setSize(n5, [float32(528), 309])
  l.insertChild(root, n5)

  l.compute(root)

  check int32(root) == 1
  check l.len == 5

  check l.computed(root) == [float32(0), 0, 300, 1000]

  check l.computed(n2) == [float32(-1115.5), 0, 1000, 1000]
  check l.computed(n3) == [float32(-114.5), 0, 1000, 1000]
  check l.computed(n4) == [float32(886.5), 0, 0, 288]
  check l.computed(n5) == [float32(887.5), 0, 528, 309]

test2 "wrap_cross_auto_wrap_column":
  setup(LayoutColumn, WrapWrap, [float32(0), 300])

  l.compute(root)

  check int32(root) == 1
  check l.len == 5

  check l.computed(root) == [float32(0), 0, 4976, 300]

  check l.computed(n2) == [float32(0), -350, 1000, 1000]
  check l.computed(n3) == [float32(1793), -350, 1000, 1000]
  check l.computed(n4) == [float32(3586), 150, 288, 0]
  check l.computed(n5) == [float32(4667), -114, 309, 528]

test2 "wrap_cross_auto_wrap_row":
  # Auto cross size under wrap.
  setup(LayoutRow, WrapWrap, [float32(1200), 0])

  l.compute(root)

  check int32(root) == 1
  check l.len == 5

  check l.computed(root) == [float32(0), 0, 1200, 2531]

  check l.computed(n2) == [float32(0), 0, 1200, 1000]
  check l.computed(n3) == [float32(100), 1001, 1000, 1000]
  check l.computed(n4) == [float32(456), 2002, 288, 0]
  check l.computed(n5) == [float32(445.5), 2003, 309, 528]
