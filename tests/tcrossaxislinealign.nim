import unittest

import buju
import ./utils

import std/sugar

template setup(crossAxisLineAlign: CrossAxisLineAlign): untyped =
  let root = l.node()
  l.setSize(root, [float32(130), 130])
  l.setWrap(root, WrapWrap)
  l.setLayout(root, LayoutRow)
  l.setMainAxisAlign(root, MainAxisAlignMiddle)
  l.setCrossAxisAlign(root, CrossAxisAlignMiddle)
  l.setCrossAxisLineAlign(root, crossAxisLineAlign)

  let nodes {.inject.} = collect:
    for _ in 0 ..< 4:
      let n = l.node()
      l.setSize(n, [float32(50), 50])
      l.insertChild(root, n)
      n

  l.compute(root)

test2 "cross_axis_line_align_middle":
  setup(CrossAxisLineAlignMiddle)

  check l.computed(nodes[0]) == [float32(15), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(65), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(15), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 65, 50, 50]

test2 "cross_axis_line_align_start":
  setup(CrossAxisLineAlignStart)

  check l.computed(nodes[0]) == [float32(15), 0, 50, 50]
  check l.computed(nodes[1]) == [float32(65), 0, 50, 50]
  check l.computed(nodes[2]) == [float32(15), 50, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 50, 50, 50]

test2 "cross_axis_line_align_end":
  setup(CrossAxisLineAlignEnd)

  check l.computed(nodes[0]) == [float32(15), 30, 50, 50]
  check l.computed(nodes[1]) == [float32(65), 30, 50, 50]
  check l.computed(nodes[2]) == [float32(15), 80, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 80, 50, 50]

test2 "cross_axis_line_align_stretch":
  setup(CrossAxisLineAlignStretch)

  check l.computed(nodes[0]) == [float32(15), 7.5, 50, 50]
  check l.computed(nodes[1]) == [float32(65), 7.5, 50, 50]
  check l.computed(nodes[2]) == [float32(15), 72.5, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 72.5, 50, 50]

test2 "cross_axis_line_align_space_between":
  setup(CrossAxisLineAlignSpaceBetween)

  check l.computed(nodes[0]) == [float32(15), 0, 50, 50]
  check l.computed(nodes[1]) == [float32(65), 0, 50, 50]
  check l.computed(nodes[2]) == [float32(15), 80, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 80, 50, 50]

test2 "cross_axis_line_align_space_around":
  setup(CrossAxisLineAlignSpaceAround)

  check l.computed(nodes[0]) == [float32(15), 7.5, 50, 50]
  check l.computed(nodes[1]) == [float32(65), 7.5, 50, 50]
  check l.computed(nodes[2]) == [float32(15), 72.5, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 72.5, 50, 50]

test2 "cross_axis_line_align_space_evenly":
  setup(CrossAxisLineAlignSpaceEvenly)

  check l.computed(nodes[0]) == [float32(15), 10, 50, 50]
  check l.computed(nodes[1]) == [float32(65), 10, 50, 50]
  check l.computed(nodes[2]) == [float32(15), 70, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 70, 50, 50]
