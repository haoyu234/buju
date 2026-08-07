import buju
import unittest

import std/sugar

import ./utils

# Golden geometry for every MainAxisAlign mode. The assertions are the spec.

template setup(layout: Layout, mainAxisAlign: MainAxisAlign): untyped =
  let root = l.node()
  l.setSize(root, [float32(130), 130])
  l.setWrap(root, WrapWrap)
  l.setLayout(root, layout)
  l.setMainAxisAlign(root, mainAxisAlign)
  l.setCrossAxisAlign(root, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(root, CrossAxisLineAlignMiddle)

  let nodes {.inject.} = collect:
    for _ in 0 ..< 4:
      let n = l.node()
      l.setSize(n, [float32(50), 50])
      l.insertChild(root, n)
      n

  l.compute(root)

test2 "main_axis_align_middle_column":
  setup(LayoutColumn, MainAxisAlignMiddle)

  check l.computed(nodes[0]) == [float32(15), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(15), 65, 50, 50]
  check l.computed(nodes[2]) == [float32(65), 15, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 65, 50, 50]

test2 "main_axis_align_middle_row":
  setup(LayoutRow, MainAxisAlignMiddle)

  check l.computed(nodes[0]) == [float32(15), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(65), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(15), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 65, 50, 50]

test2 "main_axis_align_start_column":
  setup(LayoutColumn, MainAxisAlignStart)

  check l.computed(nodes[0]) == [float32(15), 0, 50, 50]
  check l.computed(nodes[1]) == [float32(15), 50, 50, 50]
  check l.computed(nodes[2]) == [float32(65), 0, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 50, 50, 50]

test2 "main_axis_align_start_row":
  setup(LayoutRow, MainAxisAlignStart)

  check l.computed(nodes[0]) == [float32(0), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(50), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(0), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(50), 65, 50, 50]

test2 "main_axis_align_end_column":
  setup(LayoutColumn, MainAxisAlignEnd)

  check l.computed(nodes[0]) == [float32(15), 30, 50, 50]
  check l.computed(nodes[1]) == [float32(15), 80, 50, 50]
  check l.computed(nodes[2]) == [float32(65), 30, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 80, 50, 50]

test2 "main_axis_align_end_row":
  setup(LayoutRow, MainAxisAlignEnd)

  check l.computed(nodes[0]) == [float32(30), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(80), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(30), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(80), 65, 50, 50]

test2 "main_axis_align_space_between_column":
  setup(LayoutColumn, MainAxisAlignSpaceBetween)

  check l.computed(nodes[0]) == [float32(15), 0, 50, 50]
  check l.computed(nodes[1]) == [float32(15), 80, 50, 50]
  check l.computed(nodes[2]) == [float32(65), 0, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 80, 50, 50]

test2 "main_axis_align_space_between_row":
  setup(LayoutRow, MainAxisAlignSpaceBetween)

  check l.computed(nodes[0]) == [float32(0), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(80), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(0), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(80), 65, 50, 50]

test2 "main_axis_align_space_around_column":
  setup(LayoutColumn, MainAxisAlignSpaceAround)

  check l.computed(nodes[0]) == [float32(15), 7.5, 50, 50]
  check l.computed(nodes[1]) == [float32(15), 72.5, 50, 50]
  check l.computed(nodes[2]) == [float32(65), 7.5, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 72.5, 50, 50]

test2 "main_axis_align_space_around_row":
  setup(LayoutRow, MainAxisAlignSpaceAround)

  check l.computed(nodes[0]) == [float32(7.5), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(72.5), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(7.5), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(72.5), 65, 50, 50]

test2 "main_axis_align_space_evenly_column":
  setup(LayoutColumn, MainAxisAlignSpaceEvenly)

  check l.computed(nodes[0]) == [float32(15), 10, 50, 50]
  check l.computed(nodes[1]) == [float32(15), 70, 50, 50]
  check l.computed(nodes[2]) == [float32(65), 10, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 70, 50, 50]

test2 "main_axis_align_space_evenly_row":
  setup(LayoutRow, MainAxisAlignSpaceEvenly)

  check l.computed(nodes[0]) == [float32(10), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(70), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(10), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(70), 65, 50, 50]
