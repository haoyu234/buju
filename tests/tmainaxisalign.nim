import unittest

import buju
import ./utils

import std/sugar

template setup(mainAxisAlign: MainAxisAlign): untyped =
  let root = l.node()
  l.setSize(root, [float32(130), 130])
  l.setWrap(root, WrapWrap)
  l.setLayout(root, LayoutRow)
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

test2 "main_axis_align_middle":
  setup(MainAxisAlignMiddle)

  check l.computed(nodes[0]) == [float32(15), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(65), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(15), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(65), 65, 50, 50]

test2 "main_axis_align_start":
  setup(MainAxisAlignStart)

  check l.computed(nodes[0]) == [float32(0), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(50), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(0), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(50), 65, 50, 50]

test2 "main_axis_align_end":
  setup(MainAxisAlignEnd)

  check l.computed(nodes[0]) == [float32(30), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(80), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(30), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(80), 65, 50, 50]

test2 "main_axis_align_space_between":
  setup(MainAxisAlignSpaceBetween)

  check l.computed(nodes[0]) == [float32(0), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(80), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(0), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(80), 65, 50, 50]

test2 "main_axis_align_space_around":
  setup(MainAxisAlignSpaceAround)

  check l.computed(nodes[0]) == [float32(7.5), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(72.5), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(7.5), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(72.5), 65, 50, 50]

test2 "main_axis_align_space_evenly":
  setup(MainAxisAlignSpaceEvenly)

  check l.computed(nodes[0]) == [float32(10), 15, 50, 50]
  check l.computed(nodes[1]) == [float32(70), 15, 50, 50]
  check l.computed(nodes[2]) == [float32(10), 65, 50, 50]
  check l.computed(nodes[3]) == [float32(70), 65, 50, 50]
