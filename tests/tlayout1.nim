import unittest

import buju
import ./utils

test2 "simple_fill":
  let root = l.node()
  let child = l.node()

  l.setSize(root, vec2(30, 40))
  l.setAlign(child, {AlignLeft, AlignTop, AlignRight, AlignBottom})
  l.insertChild(root, child)
  l.compute(root)

  let root_r = l.computed(root)
  let child_r = l.computed(child)

  check root_r[0] == 0
  check root_r[1] == 0
  check root_r[2] == 30
  check root_r[3] == 40

  check child_r[0] == 0
  check child_r[1] == 0
  check child_r[2] == 30
  check child_r[3] == 40

test2 "multiple_uninserted":
  let root = l.node()
  let child1 = l.node()
  let child2 = l.node()

  l.setSize(root, vec2(155, 177))
  l.setSize(child2, vec2(1, 1))
  l.compute(root)

  check l.computed(root) == vec4(0, 0, 155, 177)
  check l.computed(child1) == vec4(0, 0, 0, 0)
  check l.computed(child2) == vec4(0, 0, 0, 0)

test2 "column_even_fill":
  let root = l.node()
  let child1 = l.node()
  let child2 = l.node()
  let child3 = l.node()

  l.setSize(root, vec2(50, 60))
  l.setLayout(root, LayoutColumn)
  l.setAlign(child1, {AlignLeft, AlignTop, AlignRight, AlignBottom})
  l.setAlign(child2, {AlignLeft, AlignTop, AlignRight, AlignBottom})
  l.setAlign(child3, {AlignLeft, AlignTop, AlignRight, AlignBottom})

  l.insertChild(root, child1)
  l.insertChild(root, child2)
  l.insertChild(root, child3)
  l.compute(root)

  check l.computed(root) == vec4(0, 0, 50, 60)
  check l.computed(child1) == vec4(0, 0, 50, 20)
  check l.computed(child2) == vec4(0, 20, 50, 20)
  check l.computed(child3) == vec4(0, 40, 50, 20)

test2 "row_even_fill":
  let root = l.node()
  let child1 = l.node()
  let child2 = l.node()
  let child3 = l.node()

  l.setSize(root, vec2(90, 3))
  l.setLayout(root, LayoutRow)
  l.setAlign(child1, {AlignLeft, AlignRight, AlignTop})
  l.setAlign(child2, {AlignLeft, AlignRight})
  l.setAlign(child3, {AlignLeft, AlignRight, AlignBottom})

  l.setSize(child1, vec2(0, 1))
  l.setSize(child2, vec2(0, 1))
  l.setSize(child3, vec2(0, 1))

  l.insertChild(root, child1)
  l.insertChild(root, child2)
  l.insertChild(root, child3)
  l.compute(root)

  check l.computed(root) == vec4(0, 0, 90, 3)
  check l.computed(child1) == vec4(0, 0, 30, 1)
  check l.computed(child2) == vec4(30, 1, 30, 1)
  check l.computed(child3) == vec4(60, 2, 30, 1)

test2 "fixed_and_fill":
  let root = l.node()
  let fixed1 = l.node()
  let fixed2 = l.node()
  let filler = l.node()

  l.setLayout(root, LayoutColumn)

  l.setSize(root, vec2(50, 60))
  l.setSize(fixed1, vec2(50, 15))
  l.setSize(fixed2, vec2(50, 15))
  l.setAlign(filler, {AlignLeft, AlignTop, AlignRight, AlignBottom})

  l.insertChild(root, fixed1)
  l.insertChild(root, filler)
  l.insertChild(root, fixed2)
  l.compute(root)

  check l.computed(root) == vec4(0, 0, 50, 60)
  check l.computed(fixed1) == vec4(0, 0, 50, 15)
  check l.computed(filler) == vec4(0, 15, 50, 30)
  check l.computed(fixed2) == vec4(0, 45, 50, 15)

test2 "simple_margins_1":
  let root = l.node()
  let child1 = l.node()
  let child2 = l.node()
  let child3 = l.node()

  l.setLayout(root, LayoutColumn)
  l.setAlign(child1, {AlignLeft, AlignRight})
  l.setAlign(child2, {AlignLeft, AlignRight, AlignTop, AlignBottom})
  l.setAlign(child3, {AlignLeft, AlignRight})

  l.setSize(root, vec2(100, 90))

  l.setMargin(child1, vec4(3, 5, 7, 10))
  l.setSize(child1, vec2(0, (30 - (5 + 10))))
  l.setSize(child3, vec2(0, 30))

  l.insertChild(root, child1)
  l.insertChild(root, child2)
  l.insertChild(root, child3)
  l.compute(root)

  check l.computed(child1) == vec4(3, 5, 90, (5 + 10))
  check l.computed(child2) == vec4(0, 30, 100, 30)
  check l.computed(child3) == vec4(0, 60, 100, 30)

test2 "nested_boxes_1":
  const numRows = 5
  const numRowsWithHeight = numRows - 1

  let root = l.node()
  let mainChild = l.node()

  l.setSize(root, vec2(70, float32(numRowsWithHeight * 10 + 2 * 10)))
  l.setMargin(mainChild, vec4(10, 10, 10, 10))
  l.setLayout(mainChild, LayoutColumn)
  l.insertChild(root, mainChild)
  l.setAlign(mainChild, {AlignLeft, AlignTop, AlignRight, AlignBottom})

  var rows: array[numRows, NodeID]

  rows[0] = l.node()
  l.setLayout(rows[0], LayoutRow)
  l.setAlign(rows[0], {AlignLeft, AlignTop, AlignRight, AlignBottom})

  var cols1: array[5, NodeID]
  for i in 0 ..< 5:
    let col = l.node()
    l.setAlign(col, {AlignLeft, AlignTop, AlignRight, AlignBottom})
    l.insertChild(rows[0], col)
    cols1[i] = col

  rows[1] = l.node()
  l.setLayout(rows[1], LayoutRow)
  l.setAlign(rows[1], {AlignTop, AlignBottom})

  var cols2: array[5, NodeID]
  for i in 0 ..< 5:
    let col = l.node()
    l.setSize(col, vec2(10, 0))
    l.setAlign(col, {AlignTop, AlignBottom})
    l.insertChild(rows[1], col)
    cols2[i] = col

  rows[2] = l.node()
  l.setLayout(rows[2], LayoutRow)

  var cols3: array[2, NodeID]
  for i in 0 ..< 2:
    let col = l.node()
    let innerSizer = l.node()
    l.setSize(innerSizer, vec2(25, float32(10 * i)))
    l.setAlign(col, {AlignBottom})
    l.insertChild(col, innerSizer)
    l.insertChild(rows[2], col)
    cols3[i] = col

  rows[3] = l.node()
  l.setLayout(rows[3], LayoutRow)
  l.setAlign(rows[3], {AlignLeft, AlignRight})

  var cols4: array[99, NodeID]
  for i in 0 ..< 99:
    let col = l.node()
    l.insertChild(rows[3], col)
    cols4[i] = col

  rows[4] = l.node()
  l.setLayout(rows[4], LayoutRow)
  l.setAlign(rows[4], {AlignLeft, AlignTop, AlignRight, AlignBottom})

  var cols5: array[50, NodeID]
  for i in 0 ..< 50:
    let col = l.node()
    l.setAlign(col, {AlignLeft, AlignTop, AlignRight, AlignBottom})
    l.insertChild(rows[4], col)
    cols5[i] = col

  for i in 0 ..< numRows:
    l.insertChild(mainChild, rows[i])

  for i in 0 ..< 5:
    l.compute(root)

    check l.computed(mainChild) == vec4(10, 10, 50, 40)

    check l.computed(rows[0]) == vec4(10, 10, 50, 10)
    check l.computed(rows[1]) == vec4(10, 20, 50, 10)
    check l.computed(rows[2]) == vec4(10, 30, 50, 10)

    check l.computed(rows[3]) == vec4(10, 40, 50, 0)
    check l.computed(rows[4]) == vec4(10, 40, 50, 10)

    for i in 0 ..< 5:
      check l.computed(cols1[i]) == vec4(float32(10 + 10 * i), 10, 10, 10)

    for i in 0 ..< 5:
      check l.computed(cols2[i]) == vec4(float32(10 + 10 * i), 20, 10, 10)

    check l.computed(cols3[0]) == vec4(10, 40, 25, 0)
    check l.computed(cols3[1]) == vec4(35, 30, 25, 10)

    for i in 0 ..< 99:
      check l.computed(cols4[i]) == vec4(25 + 10, 40, 0, 0)

    for i in 0 ..< 50:
      check l.computed(cols5[i]) == vec4(float32(10 + i), 40, 1, 10)

test2 "deep_nest_1":
  const numItems = 500

  let root = l.node()

  var parent = root
  for i in 0 ..< numItems:
    let child = l.node()
    l.insertChild(parent, child)
    parent = child

  l.setSize(parent, vec2(77, 99))
  l.compute(root)

  check l.computed(root) == vec4(0, 0, 77, 99)

test2 "many_children_1":
  const numItems = 20000

  let root = l.node()
  l.setSize(root, vec2(1, 0))
  l.setLayout(root, LayoutColumn)

  let node1 = l.node()
  l.setSize(node1, vec2(1, 1))
  l.insertChild(root, node1)

  for i in 0 ..< (numItems - 1):
    let node2 = l.node()
    l.setSize(node2, vec2(1, 1))
    l.insertChild(root, node2)

  l.compute(root)

  check l.computed(root) == vec4(0, 0, 1, numItems)

test2 "child_align_1":
  let root = l.node()
  l.setSize(root, vec2(50, 50))

  template alignBox(n, align) =
    let n = l.node()
    l.setSize(n, vec2(10, 10))
    l.setAlign(n, align)
    l.insertChild(root, n)

  alignBox(child1, {AlignTop, AlignLeft})
  alignBox(child2, {AlignTop, AlignRight})
  alignBox(child3, {AlignTop})

  alignBox(child4, {AlignLeft})
  alignBox(child5, {AlignRight})
  alignBox(child6, {})

  alignBox(child7, {AlignBottom, AlignLeft})
  alignBox(child8, {AlignBottom, AlignRight})
  alignBox(child9, {AlignBottom})

  l.compute(root)

  check l.computed(child1) == vec4(0, 0, 10, 10)
  check l.computed(child2) == vec4(40, 0, 10, 10)
  check l.computed(child3) == vec4(20, 0, 10, 10)

  check l.computed(child4) == vec4(0, 20, 10, 10)
  check l.computed(child5) == vec4(40, 20, 10, 10)
  check l.computed(child6) == vec4(20, 20, 10, 10)

  check l.computed(child7) == vec4(0, 40, 10, 10)
  check l.computed(child8) == vec4(40, 40, 10, 10)
  check l.computed(child9) == vec4(20, 40, 10, 10)

test2 "child_align_2":
  let root = l.node()
  l.setSize(root, vec2(50, 50))

  template alignBox(n, align) =
    let n = l.node()
    l.setSize(n, vec2(10, 10))
    l.setAlign(n, align)
    l.insertChild(root, n)

  alignBox(child1, {AlignLeft, AlignRight, AlignTop})
  alignBox(child2, {AlignLeft, AlignRight})
  alignBox(child3, {AlignLeft, AlignRight, AlignBottom})

  alignBox(child4, {AlignTop, AlignBottom, AlignLeft})
  alignBox(child5, {AlignTop, AlignBottom, AlignRight})
  alignBox(child6, {AlignTop, AlignBottom})

  l.compute(root)

  check l.computed(child1) == vec4(0, 0, 50, 10)
  check l.computed(child2) == vec4(0, 20, 50, 10)
  check l.computed(child3) == vec4(0, 40, 50, 10)

  check l.computed(child4) == vec4(0, 0, 10, 50)
  check l.computed(child5) == vec4(40, 0, 10, 50)
  check l.computed(child6) == vec4(20, 0, 10, 50)
