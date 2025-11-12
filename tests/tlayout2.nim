import unittest

import buju
import ./utils

test2 "wrap_row_1":
  let root = l.node()
  l.setSize(root, [float32(50), 50])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)

  const numItems = 5 * 5
  var items: array[numItems, NodeID]

  for i in 0 ..< numItems:
    let node = l.node()
    l.setSize(node, [float32(10), 10])
    l.insertChild(root, node)
    items[i] = node

  l.compute(root)

  for i in 0 ..< numItems:
    let x = i mod 5
    let y = i div 5
    check l.computed(items[i]) == [float32(x * 10), float32(y * 10), 10, 10]

test2 "wrap_row_2":
  let root = l.node()
  l.setSize(root, [float32(57), 57])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)
  l.setMainAxisAlign(root, MainAxisAlignStart)

  # Before `setXxx` was available, these were "hardcoded" default values.
  l.setCrossAxisLineAlign(root, CrossAxisLineAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)

  const numItems = 5 * 5
  var items: array[numItems, NodeID]

  for i in 0 ..< numItems:
    let node = l.node()
    l.setSize(node, [float32(10), 10])
    l.insertChild(root, node)
    items[i] = node

  l.compute(root)

  for i in 0 ..< numItems:
    let x = i mod 5
    let y = i div 5
    check l.computed(items[i]) == [float32(x * 10), float32(y * 10), 10, 10]

test2 "wrap_row_3":
  let root = l.node()
  l.setSize(root, [float32(57), 57])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)
  l.setMainAxisAlign(root, MainAxisAlignEnd)

  l.setCrossAxisLineAlign(root, CrossAxisLineAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)

  const numItems = 5 * 5
  var items: array[numItems, NodeID]

  for i in 0 ..< numItems:
    let node = l.node()
    l.setSize(node, [float32(10), 10])
    l.insertChild(root, node)
    items[i] = node

  l.compute(root)

  for i in 0 ..< numItems:
    let x = i mod 5
    let y = i div 5
    check l.computed(items[i]) == [float32(7 + x * 10), float32(y * 10), 10, 10]

test2 "wrap_row_4":
  let root = l.node()
  l.setSize(root, [float32(58), 57])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)

  let spacer = l.node()
  l.setSize(spacer, [float32(58), 7])
  l.insertChild(root, spacer)

  const numItems = 5 * 5
  var items: array[numItems, NodeID]

  for i in 0 ..< numItems:
    let node = l.node()
    l.setSize(node, [float32(10), 10])
    l.insertChild(root, node)
    items[i] = node

  l.compute(root)

  for i in 0 ..< numItems:
    let x = i mod 5
    let y = i div 5
    check l.computed(items[i]) == [float32(4 + x * 10), float32(7 + y * 10), 10, 10]

test2 "wrap_row_5":
  let root = l.node()
  l.setSize(root, [float32(54), 50])
  l.setLayout(root, LayoutRow)
  l.setWrap(root, WrapWrap)
  l.setMainAxisAlign(root, MainAxisAlignSpaceBetween)

  const numItems = 5 * 5
  var items: array[numItems, NodeID]

  for i in 0 ..< numItems:
    let node = l.node()
    l.setSize(node, [float32(10), 10])
    l.insertChild(root, node)
    items[i] = node

  l.compute(root)

  for i in 0 ..< numItems:
    let x = i mod 5
    let y = i div 5
    check l.computed(items[i]) == [float32(x * 11), float32(y * 10), 10, 10]

test2 "wrap_column_1":
  let root = l.node()
  l.setSize(root, [float32(50), 50])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)

  const numItems = 5 * 5
  var items: array[numItems, NodeID]

  for i in 0 ..< numItems:
    let node = l.node()
    l.setSize(node, [float32(10), 10])
    l.insertChild(root, node)
    items[i] = node

  l.compute(root)

  for i in 0 ..< numItems:
    let x = i div 5
    let y = i mod 5
    check l.computed(items[i]) == [float32(x * 10), float32(y * 10), 10, 10]

test2 "wrap_column_2":
  let root = l.node()
  l.setSize(root, [float32(57), 57])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)
  l.setMainAxisAlign(root, MainAxisAlignStart)

  l.setCrossAxisLineAlign(root, CrossAxisLineAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)

  const numItems = 5 * 5
  var items: array[numItems, NodeID]

  for i in 0 ..< numItems:
    let node = l.node()
    l.setSize(node, [float32(10), 10])
    l.insertChild(root, node)
    items[i] = node

  l.compute(root)

  for i in 0 ..< numItems:
    let x = i div 5
    let y = i mod 5
    check l.computed(items[i]) == [float32(x * 10), float32(y * 10), 10, 10]

test2 "wrap_column_3":
  let root = l.node()
  l.setSize(root, [float32(57), 57])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)
  l.setMainAxisAlign(root, MainAxisAlignEnd)

  l.setCrossAxisLineAlign(root, CrossAxisLineAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)

  const numItems = 5 * 5
  var items: array[numItems, NodeID]

  for i in 0 ..< numItems:
    let node = l.node()
    l.setSize(node, [float32(10), 10])
    l.insertChild(root, node)
    items[i] = node

  l.compute(root)

  for i in 0 ..< numItems:
    let x = i div 5
    let y = i mod 5
    check l.computed(items[i]) == [float32(x * 10), float32(7 + y * 10), 10, 10]

test2 "wrap_column_4":
  let root = l.node()
  l.setSize(root, [float32(57), 58])
  l.setLayout(root, LayoutColumn)
  l.setWrap(root, WrapWrap)

  l.setCrossAxisLineAlign(root, CrossAxisLineAlignStart)
  l.setCrossAxisAlign(root, CrossAxisAlignStart)

  let spacer = l.node()
  l.setSize(spacer, [float32(7), 58])
  l.insertChild(root, spacer)

  const numItems = 5 * 5
  var items: array[numItems, NodeID]

  for i in 0 ..< numItems:
    let node = l.node()
    l.setSize(node, [float32(10), 10])
    l.insertChild(root, node)
    items[i] = node

  l.compute(root)

  for i in 0 ..< numItems:
    let x = i div 5
    let y = i mod 5
    check l.computed(items[i]) == [float32(7 + x * 10), float32(4 + y * 10), 10, 10]

test2 "anchor_right_margin1":
  let root = l.node()
  l.setSize(root, [float32(100), 100])

  let child = l.node()
  l.setSize(child, [float32(50), 50])
  l.setMargin(child, [float32(5), 5, 0, 0])
  l.setAlign(child, {AlignBottom, AlignRight})

  l.insertChild(root, child)

  l.compute(root)

  check l.computed(child) == [float32(50), 50, 50, 50]

test2 "anchor_right_margin2":
  let root = l.node()
  l.setSize(root, [float32(100), 100])

  let child = l.node()
  l.setSize(child, [float32(50), 50])
  l.setMargin(child, [float32(5), 5, 10, 10])
  l.setAlign(child, {AlignBottom, AlignRight})

  l.insertChild(root, child)

  l.compute(root)

  check l.computed(child) == [float32(40), 40, 50, 50]
