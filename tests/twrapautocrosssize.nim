import buju
import unittest

import ./utils

# Wrapped container cross size is auto-derived from content (Row from wrapped
# lines' height, Column from lines' width). Isomorphic Row/Column mirror.

template setup(layout: Layout): untyped =
  let root {.inject.} = l.node()
  l.setLayout(root, layout)
  l.setWrap(root, WrapWrap)
  l.setMainAxisAlign(root, MainAxisAlignMiddle)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)
  l.setCrossAxisLineAlign(root, CrossAxisLineAlignEnd)
  l.setAlign(root, {})
  l.setSize(root, if layout == LayoutColumn: [float32(0), 300] else: [float32(300), 0])
  l.setGap(root, if layout == LayoutColumn: [float32(793), 0] else: [float32(0), 793])

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
  if layout == LayoutColumn:
    l.setAlign(n4, {AlignTop, AlignRight})
    l.setSize(n4, [float32(0), 288])
  else:
    l.setAlign(n4, {AlignLeft, AlignBottom})
    l.setSize(n4, [float32(288), 0])
  l.insertChild(root, n4)

  let n5 {.inject.} = l.node()
  l.setLayout(n5, LayoutFree)
  l.setMainAxisAlign(n5, MainAxisAlignMiddle)
  l.setCrossAxisAlign(n5, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(n5, CrossAxisLineAlignMiddle)
  l.setAlign(n5, {})
  if layout == LayoutColumn:
    l.setSize(n5, [float32(528), 309])
  else:
    l.setSize(n5, [float32(309), 528])
  l.insertChild(root, n5)

test2 "wrap_auto_cross_size_column":
  setup(LayoutColumn)

  l.compute(root)

  check int32(root) == 1
  check l.len == 5

  check l.computed(root) == [float32(0), 0, 4907, 300]

  check l.computed(n2) == [float32(0), -350, 1000, 1000]
  check l.computed(n3) == [float32(1793), -350, 1000, 1000]
  check l.computed(n4) == [float32(3586), 6, 0, 288]
  check l.computed(n5) == [float32(4379), -4.5, 528, 309]

test2 "wrap_auto_cross_size_row":
  setup(LayoutRow)

  l.compute(root)

  check int32(root) == 1
  check l.len == 5

  check l.computed(root) == [float32(0), 0, 300, 4907]

  check l.computed(n2) == [float32(-350), 0, 1000, 1000]
  check l.computed(n3) == [float32(-350), 1793, 1000, 1000]
  check l.computed(n4) == [float32(6), 3586, 288, 0]
  check l.computed(n5) == [float32(-4.5), 4379, 309, 528]
