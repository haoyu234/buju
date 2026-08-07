import buju
import unittest

import ./utils

# A wrap / no-wrap container with oversized Free children must GROW to enclose
# its content rather than clamp to its (tiny or zero) explicit cross/main size.
# The setup builds a deep tree of Free nodes far larger than the root. The root
# extent is asserted to expand to fit them. Written for Column and Row, wrap and
# no-wrap.

template setup(layout: Layout, wrap: Wrap): untyped =
  let root {.inject.} = l.node()
  l.setLayout(root, layout)
  l.setWrap(root, wrap)
  l.setMainAxisAlign(root, MainAxisAlignMiddle)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)
  l.setCrossAxisLineAlign(root, CrossAxisLineAlignEnd)
  l.setAlign(root, {})
  if layout == LayoutColumn:
    l.setSize(root, [float32(0), 300])
    l.setGap(root, [float32(793), 1])
  else:
    l.setSize(root, [float32(300), 0])
    l.setGap(root, [float32(1), 793])

  let n2 {.inject.} = l.node()
  l.setLayout(n2, LayoutFree)
  l.setMainAxisAlign(n2, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n2, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n2, CrossAxisLineAlignMiddle)
  if layout == LayoutColumn:
    l.setAlign(n2, {AlignLeft, AlignTop, AlignRight})
  else:
    l.setAlign(n2, {AlignTop, AlignLeft, AlignBottom})
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
  if layout == LayoutColumn:
    l.setLayout(n4, LayoutColumn)
    l.setAlign(n4, {AlignLeft, AlignBottom})
    l.setSize(n4, [float32(288), 0])
  else:
    l.setLayout(n4, LayoutRow)
    l.setAlign(n4, {AlignTop, AlignRight})
    l.setSize(n4, [float32(0), 288])
  l.setMainAxisAlign(n4, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n4, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n4, CrossAxisLineAlignMiddle)
  l.setGap(n4, [float32(0), 0])
  l.insertChild(root, n4)

  let n5 {.inject.} = l.node()
  if layout == LayoutColumn:
    l.setLayout(n5, LayoutColumn)
  else:
    l.setLayout(n5, LayoutRow)
  l.setMainAxisAlign(n5, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n5, CrossAxisAlignStart)
  l.setCrossAxisLineAlign(n5, CrossAxisLineAlignMiddle)
  l.setAlign(n5, {})
  l.setSize(n5, [float32(0), 0])
  if layout == LayoutColumn:
    l.setGap(n5, [float32(0), 793])
  else:
    l.setGap(n5, [float32(793), 0])
  l.insertChild(n4, n5)

  let n6 {.inject.} = l.node()
  l.setLayout(n6, LayoutFree)
  l.setMainAxisAlign(n6, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n6, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n6, CrossAxisLineAlignMiddle)
  if layout == LayoutColumn:
    l.setAlign(n6, {AlignLeft, AlignTop, AlignRight})
  else:
    l.setAlign(n6, {AlignTop, AlignLeft, AlignBottom})
  l.setSize(n6, [float32(1000), 1000])
  l.insertChild(n5, n6)

  let n7 {.inject.} = l.node()
  l.setLayout(n7, LayoutFree)
  l.setMainAxisAlign(n7, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n7, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n7, CrossAxisLineAlignMiddle)
  l.setAlign(n7, {})
  l.setSize(n7, [float32(1000), 1000])
  l.insertChild(n5, n7)

  let n8 {.inject.} = l.node()
  l.setLayout(n8, LayoutFree)
  l.setMainAxisAlign(n8, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n8, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n8, CrossAxisLineAlignMiddle)
  if layout == LayoutColumn:
    l.setAlign(n8, {AlignLeft, AlignBottom})
    l.setSize(n8, [float32(288), 0])
  else:
    l.setAlign(n8, {AlignTop, AlignRight})
    l.setSize(n8, [float32(0), 288])
  l.insertChild(n5, n8)

  let n9 {.inject.} = l.node()
  l.setLayout(n9, LayoutFree)
  l.setMainAxisAlign(n9, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n9, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n9, CrossAxisLineAlignMiddle)
  l.setAlign(n9, {})
  if layout == LayoutColumn:
    l.setSize(n9, [float32(309), 528])
  else:
    l.setSize(n9, [float32(528), 309])
  l.insertChild(n5, n9)

  let n10 {.inject.} = l.node()
  l.setLayout(n10, LayoutFree)
  l.setMainAxisAlign(n10, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n10, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n10, CrossAxisLineAlignMiddle)
  l.setAlign(n10, {})
  if layout == LayoutColumn:
    l.setSize(n10, [float32(309), 528])
  else:
    l.setSize(n10, [float32(528), 309])
  l.insertChild(root, n10)

test2 "container_grow_to_content_wrap_column":
  setup(LayoutColumn, WrapWrap)

  l.compute(root)

  check int32(root) == 1
  check l.len == 10

  check l.computed(root) == [float32(0), 0, 4976, 300]

  check l.computed(n2) == [float32(0), -350, 1000, 1000]
  check l.computed(n3) == [float32(1793), -350, 1000, 1000]
  check l.computed(n4) == [float32(3586), -2303.5, 288, 4907]
  check l.computed(n10) == [float32(4667), -114, 309, 528]

  check l.computed(n5) == [float32(3230), -2303.5, 1000, 4907]
  check l.computed(n6) == [float32(3230), -2303.5, 1000, 1000]
  check l.computed(n7) == [float32(3230), -510.5, 1000, 1000]
  check l.computed(n8) == [float32(3230), 1282.5, 288, 0]
  check l.computed(n9) == [float32(3230), 2075.5, 309, 528]

test2 "container_grow_to_content_wrap_row":
  setup(LayoutRow, WrapWrap)

  l.compute(root)

  check int32(root) == 1
  check l.len == 10

  check l.computed(root) == [float32(0), 0, 300, 4976]

  check l.computed(n2) == [float32(-350), 0, 1000, 1000]
  check l.computed(n3) == [float32(-350), 1793, 1000, 1000]
  check l.computed(n4) == [float32(-2303.5), 3586, 4907, 288]
  check l.computed(n10) == [float32(-114), 4667, 528, 309]

  check l.computed(n5) == [float32(-2303.5), 3230, 4907, 1000]
  check l.computed(n6) == [float32(-2303.5), 3230, 1000, 1000]
  check l.computed(n7) == [float32(-510.5), 3230, 1000, 1000]
  check l.computed(n8) == [float32(1282.5), 3230, 0, 288]
  check l.computed(n9) == [float32(2075.5), 3230, 528, 309]

test2 "container_grow_to_content_nowrap_column":
  setup(LayoutColumn, WrapNoWrap)

  l.compute(root)

  check int32(root) == 1
  check l.len == 10

  check l.computed(root) == [float32(0), 0, 1000, 300]
  check l.computed(n4) == [float32(0), -1567, 288, 4907]
  check l.computed(n5) == [float32(-356), -1567, 1000, 4907]

  check l.computed(n2) == [float32(0), -3569, 1000, 1000]
  check l.computed(n3) == [float32(0), -2568, 1000, 1000]
  check l.computed(n6) == [float32(-356), -1567, 1000, 1000]
  check l.computed(n7) == [float32(-356), 226, 1000, 1000]
  check l.computed(n8) == [float32(-356), 2019, 288, 0]
  check l.computed(n9) == [float32(-356), 2812, 309, 528]
  check l.computed(n10) == [float32(0), 3341, 309, 528]

test2 "container_grow_to_content_nowrap_row":
  setup(LayoutRow, WrapNoWrap)

  l.compute(root)

  check int32(root) == 1
  check l.len == 10

  check l.computed(root) == [float32(0), 0, 300, 1000]
  check l.computed(n4) == [float32(-1567), 0, 4907, 288]
  check l.computed(n5) == [float32(-1567), -356, 4907, 1000]

  check l.computed(n2) == [float32(-3569), 0, 1000, 1000]
  check l.computed(n3) == [float32(-2568), 0, 1000, 1000]
  check l.computed(n6) == [float32(-1567), -356, 1000, 1000]
  check l.computed(n7) == [float32(226), -356, 1000, 1000]
  check l.computed(n8) == [float32(2019), -356, 0, 288]
  check l.computed(n9) == [float32(2812), -356, 528, 309]
  check l.computed(n10) == [float32(3341), 0, 528, 309]
