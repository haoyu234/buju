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

  let n6 {.inject.} = l.node()
  l.setLayout(n6, LayoutFree)
  l.setMainAxisAlign(n6, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n6, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n6, CrossAxisLineAlignMiddle)
  l.setAlign(n6, {})
  l.setSize(n6, [float32(0), 0])
  l.setGap(n6, [float32(0), 793])
  l.insertChild(n4, n6)

  let n7 {.inject.} = l.node()
  l.setLayout(n7, LayoutFree)
  l.setMainAxisAlign(n7, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n7, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n7, CrossAxisLineAlignMiddle)
  l.setAlign(n7, {AlignLeft, AlignTop, AlignRight})
  l.setSize(n7, [float32(1000), 1000])
  l.insertChild(n6, n7)

  let n8 {.inject.} = l.node()
  l.setLayout(n8, LayoutFree)
  l.setMainAxisAlign(n8, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n8, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n8, CrossAxisLineAlignMiddle)
  l.setAlign(n8, {})
  l.setSize(n8, [float32(1000), 1000])
  l.insertChild(n6, n8)

  let n9 {.inject.} = l.node()
  l.setLayout(n9, LayoutFree)
  l.setMainAxisAlign(n9, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n9, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n9, CrossAxisLineAlignMiddle)
  l.setAlign(n9, {AlignLeft, AlignBottom})
  l.setSize(n9, [float32(288), 0])
  l.insertChild(n6, n9)

  let n10 {.inject.} = l.node()
  l.setLayout(n10, LayoutFree)
  l.setMainAxisAlign(n10, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n10, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n10, CrossAxisLineAlignMiddle)
  l.setAlign(n10, {})
  l.setSize(n10, [float32(309), 528])
  l.insertChild(n6, n10)

test2 "wrap_nested_subtree_wrap_column":
  setup(LayoutColumn, WrapWrap, [float32(0), 300])

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 4976, 300]
  check l.computed(n2) == [float32(0), -350, 1000, 1000]
  check l.computed(n3) == [float32(1793), -350, 1000, 1000]
  check l.computed(n4) == [float32(3586), -350, 288, 1000]
  check l.computed(n5) == [float32(4667), -114, 309, 528]
  check l.computed(n6) == [float32(3586), -350, 1000, 1000]
  check l.computed(n7) == [float32(3586), -350, 1000, 1000]
  check l.computed(n8) == [float32(3586), -350, 1000, 1000]
  check l.computed(n9) == [float32(3586), 650, 288, 0]
  check l.computed(n10) == [float32(3931.5), -114, 309, 528]

test2 "wrap_nested_subtree_wrap_row":
  setup(LayoutRow, WrapWrap, [float32(1200), 0])

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 1200, 3531]
  check l.computed(n2) == [float32(0), 0, 1200, 1000]
  check l.computed(n3) == [float32(100), 1001, 1000, 1000]
  check l.computed(n4) == [float32(456), 2002, 288, 1000]
  check l.computed(n5) == [float32(445.5), 3003, 309, 528]
  check l.computed(n6) == [float32(456), 2002, 1000, 1000]
  check l.computed(n7) == [float32(456), 2002, 1000, 1000]
  check l.computed(n8) == [float32(456), 2002, 1000, 1000]
  check l.computed(n9) == [float32(456), 3002, 288, 0]
  check l.computed(n10) == [float32(801.5), 2238, 309, 528]

test2 "wrap_nested_subtree_nowrap_column":
  setup(LayoutColumn, WrapNoWrap, [float32(0), 300])

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 1000, 300]
  check l.computed(n2) == [float32(0), -1615.5, 1000, 1000]
  check l.computed(n3) == [float32(0), -614.5, 1000, 1000]
  check l.computed(n4) == [float32(0), 386.5, 288, 1000]
  check l.computed(n5) == [float32(0), 1387.5, 309, 528]
  check l.computed(n6) == [float32(0), 386.5, 1000, 1000]
  check l.computed(n7) == [float32(0), 386.5, 1000, 1000]
  check l.computed(n8) == [float32(0), 386.5, 1000, 1000]
  check l.computed(n9) == [float32(0), 1386.5, 288, 0]
  check l.computed(n10) == [float32(345.5), 622.5, 309, 528]

test2 "wrap_nested_subtree_nowrap_row":
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

  let n6 = l.node()
  l.setLayout(n6, LayoutFree)
  l.setMainAxisAlign(n6, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n6, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n6, CrossAxisLineAlignMiddle)
  l.setAlign(n6, {})
  l.setSize(n6, [float32(0), 0])
  l.setGap(n6, [float32(793), 0])
  l.insertChild(n4, n6)

  let n7 = l.node()
  l.setLayout(n7, LayoutFree)
  l.setMainAxisAlign(n7, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n7, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n7, CrossAxisLineAlignMiddle)
  l.setAlign(n7, {AlignTop, AlignLeft, AlignBottom})
  l.setSize(n7, [float32(1000), 1000])
  l.insertChild(n6, n7)

  let n8 = l.node()
  l.setLayout(n8, LayoutFree)
  l.setMainAxisAlign(n8, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n8, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n8, CrossAxisLineAlignMiddle)
  l.setAlign(n8, {})
  l.setSize(n8, [float32(1000), 1000])
  l.insertChild(n6, n8)

  let n9 = l.node()
  l.setLayout(n9, LayoutFree)
  l.setMainAxisAlign(n9, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n9, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n9, CrossAxisLineAlignMiddle)
  l.setAlign(n9, {AlignTop, AlignRight})
  l.setSize(n9, [float32(0), 288])
  l.insertChild(n6, n9)

  let n10 = l.node()
  l.setLayout(n10, LayoutFree)
  l.setMainAxisAlign(n10, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n10, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n10, CrossAxisLineAlignMiddle)
  l.setAlign(n10, {})
  l.setSize(n10, [float32(528), 309])
  l.insertChild(n6, n10)

  l.compute(root)

  check l.computed(root) == [float32(0), 0, 300, 1000]

  check l.computed(n2) == [float32(-1615.5), 0, 1000, 1000]
  check l.computed(n3) == [float32(-614.5), 0, 1000, 1000]
  check l.computed(n4) == [float32(386.5), 0, 1000, 288]
  check l.computed(n5) == [float32(1387.5), 0, 528, 309]
  check l.computed(n6) == [float32(386.5), 0, 1000, 1000]
  check l.computed(n7) == [float32(386.5), 0, 1000, 1000]
  check l.computed(n8) == [float32(386.5), 0, 1000, 1000]
  check l.computed(n9) == [float32(1386.5), 0, 0, 288]
  check l.computed(n10) == [float32(622.5), 345.5, 528, 309]
