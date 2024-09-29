import unittest

import buju
import ./debug

test "wrap_row_1":
  var l: Layout
  defer:
    l.dump("dumps/wrap_row_1.png")

  let root = l.node()
  l.setSize(root, vec2(50, 50))
  l.setBoxFlags(root, LayoutBoxRow or LayoutBoxWrap)

  const numItems = 5 * 5
  var items: array[numItems, LayoutNodeID]

  for i in 0..<numItems:
    let node = l.node()
    l.setSize(node, vec2(10, 10))
    l.insertChild(root, node)
    items[i] = node

  l.compute()

  for i in 0..<numItems:
    let x = i mod 5
    let y = i div 5
    check l.computed(items[i]) == vec4(float(x * 10), float(y * 10), 10, 10)

test "wrap_row_2":
  var l: Layout
  defer:
    l.dump("dumps/wrap_row_2.png")

  let root = l.node()
  l.setSize(root, vec2(57, 57))
  l.setBoxFlags(root, LayoutBoxRow or LayoutBoxWrap or LayoutBoxStart)

  const numItems = 5 * 5
  var items: array[numItems, LayoutNodeID]

  for i in 0..<numItems:
    let node = l.node()
    l.setSize(node, vec2(10, 10))
    l.insertChild(root, node)
    items[i] = node

  l.compute()

  for i in 0..<numItems:
    let x = i mod 5
    let y = i div 5
    check l.computed(items[i]) == vec4(float(x * 10), float(y * 10), 10, 10)

test "wrap_row_3":
  var l: Layout
  defer:
    l.dump("dumps/wrap_row_3.png")

  let root = l.node()
  l.setSize(root, vec2(57, 57))
  l.setBoxFlags(root, LayoutBoxRow or LayoutBoxWrap or LayoutBoxEnd)

  const numItems = 5 * 5
  var items: array[numItems, LayoutNodeID]

  for i in 0..<numItems:
    let node = l.node()
    l.setSize(node, vec2(10, 10))
    l.insertChild(root, node)
    items[i] = node

  l.compute()

  for i in 0..<numItems:
    let x = i mod 5
    let y = i div 5
    check l.computed(items[i]) == vec4(float(7 + x * 10), float(y * 10), 10, 10)

test "wrap_row_4":
  var l: Layout
  defer:
    l.dump("dumps/wrap_row_4.png")

  let root = l.node()
  l.setSize(root, vec2(58, 57))
  l.setBoxFlags(root, LayoutBoxRow or LayoutBoxWrap)

  let spacer = l.node()
  l.setSize(spacer, vec2(58, 7))
  l.insertChild(root, spacer)

  const numItems = 5 * 5
  var items: array[numItems, LayoutNodeID]

  for i in 0..<numItems:
    let node = l.node()
    l.setSize(node, vec2(10, 10))
    l.insertChild(root, node)
    items[i] = node

  l.compute()

  for i in 0..<numItems:
    let x = i mod 5
    let y = i div 5
    check l.computed(items[i]) == vec4(float(4 + x * 10), float(7 + y * 10),
        10, 10)

test "wrap_row_5":
  var l: Layout
  defer:
    l.dump("dumps/wrap_row_5.png")

  let root = l.node()
  l.setSize(root, vec2(54, 50))
  l.setBoxFlags(root, LayoutBoxRow or LayoutBoxWrap or LayoutBoxJustify)

  const numItems = 5 * 5
  var items: array[numItems, LayoutNodeID]

  for i in 0..<numItems:
    let node = l.node()
    l.setSize(node, vec2(10, 10))
    l.insertChild(root, node)
    items[i] = node

  l.compute()

  for i in 0..<numItems:
    let x = i mod 5
    let y = i div 5
    check l.computed(items[i]) == vec4(float(x * 11), float(y * 10), 10, 10)

test "wrap_column_1":
  var l: Layout
  defer:
    l.dump("dumps/wrap_column_1.png")

  let root = l.node()
  l.setSize(root, vec2(50, 50))
  l.setBoxFlags(root, LayoutBoxColumn or LayoutBoxWrap)

  const numItems = 5 * 5
  var items: array[numItems, LayoutNodeID]

  for i in 0..<numItems:
    let node = l.node()
    l.setSize(node, vec2(10, 10))
    l.insertChild(root, node)
    items[i] = node

  l.compute()

  for i in 0..<numItems:
    let x = i div 5
    let y = i mod 5
    check l.computed(items[i]) == vec4(float(x * 10), float(y * 10), 10, 10)

test "wrap_column_2":
  var l: Layout
  defer:
    l.dump("dumps/wrap_column_2.png")

  let root = l.node()
  l.setSize(root, vec2(57, 57))
  l.setBoxFlags(root, LayoutBoxColumn or LayoutBoxWrap or LayoutBoxStart)

  const numItems = 5 * 5
  var items: array[numItems, LayoutNodeID]

  for i in 0..<numItems:
    let node = l.node()
    l.setSize(node, vec2(10, 10))
    l.insertChild(root, node)
    items[i] = node

  l.compute()

  for i in 0..<numItems:
    let x = i div 5
    let y = i mod 5
    check l.computed(items[i]) == vec4(float(x * 10), float(y * 10), 10, 10)

test "wrap_column_3":
  var l: Layout
  defer:
    l.dump("dumps/wrap_column_3.png")

  let root = l.node()
  l.setSize(root, vec2(57, 57))
  l.setBoxFlags(root, LayoutBoxColumn or LayoutBoxWrap or LayoutBoxEnd)

  const numItems = 5 * 5
  var items: array[numItems, LayoutNodeID]

  for i in 0..<numItems:
    let node = l.node()
    l.setSize(node, vec2(10, 10))
    l.insertChild(root, node)
    items[i] = node

  l.compute()

  for i in 0..<numItems:
    let x = i div 5
    let y = i mod 5
    check l.computed(items[i]) == vec4(float(x * 10), float(7 + y * 10), 10, 10)

test "wrap_column_4":
  var l: Layout
  defer:
    l.dump("dumps/wrap_column_4.png")

  let root = l.node()
  l.setSize(root, vec2(57, 58))
  l.setBoxFlags(root, LayoutBoxColumn or LayoutBoxWrap)

  let spacer = l.node()
  l.setSize(spacer, vec2(7, 58))
  l.insertChild(root, spacer)

  const numItems = 5 * 5
  var items: array[numItems, LayoutNodeID]

  for i in 0..<numItems:
    let node = l.node()
    l.setSize(node, vec2(10, 10))
    l.insertChild(root, node)
    items[i] = node

  l.compute()

  for i in 0..<numItems:
    let x = i div 5
    let y = i mod 5
    check l.computed(items[i]) == vec4(float(7 + x * 10), float(4 + y * 10),
        10, 10)

test "anchor_right_margin1":
  var l: Layout
  defer:
    l.dump("dumps/anchor_right_margin1.png")

  let root = l.node()
  l.setSize(root, vec2(100, 100))

  let child = l.node()
  l.setSize(child, vec2(50, 50))
  l.setMargin(child, vec4(5, 5, 0, 0))
  l.setLayoutFlags(child, LayoutBottom or LayoutRight)

  l.insertChild(root, child)

  l.compute()

  check l.computed(child) == vec4(50, 50, 50, 50)

test "anchor_right_margin2":
  var l: Layout
  defer:
    l.dump("dumps/anchor_right_margin2.png")

  let root = l.node()
  l.setSize(root, vec2(100, 100))

  let child = l.node()
  l.setSize(child, vec2(50, 50))
  l.setMargin(child, vec4(5, 5, 10, 10))
  l.setLayoutFlags(child, LayoutBottom or LayoutRight)

  l.insertChild(root, child)

  l.compute()

  check l.computed(child) == vec4(40, 40, 50, 50)
