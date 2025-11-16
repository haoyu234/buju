# buju

buju (布局) is a simple layout engine, it is a Nim port of [layout.h](https://github.com/randrew/layout).
It has fixed several bugs left over from the original implementation and optimized the performance of some functions.

# Features
1. [Layout Visualization Tool](https://htmlpreview.github.io/?https://github.com/haoyu234/buju/blob/main/assets/viewer.html) - Used to debug exported layout JSON files.
2. Added main/cross axis alignment and gap support compared to the original version.

# Limitations
1. Does not support constraint-based solving.
2. Layout uses absolute coordinates.
3. Only supports border-box.

# Example
```nim
import buju

var l = Context()

let root = l.node()
l.setLayout(LayoutFree)
l.setSize(root, [float32(50), 50])

template alignBox(n, align) =
  let n = l.node()
  l.setSize(n, [float32(10), 10])
  l.setAlign(n, align)
  l.insertChild(root, n)

# |2|4|3|
# |5|7|6|
# |8|10|9|

alignBox(node2, {AlignTop, AlignLeft})
alignBox(node3, {AlignTop, AlignRight})
alignBox(node4, {AlignTop})

alignBox(node5, {AlignLeft})
alignBox(node6, {AlignRight})
alignBox(node7, {})

alignBox(node8, {AlignBottom, AlignLeft})
alignBox(node9, {AlignBottom, AlignRight})
alignBox(node10,{AlignBottom})

l.compute(root)

check l.computed(node2) == [float32(0), 0, 10, 10]
check l.computed(node3) == [float32(40), 0, 10, 10]
check l.computed(node4) == [float32(20), 0, 10, 10]

check l.computed(node5) == [float32(0), 20, 10, 10]
check l.computed(node6) == [float32(40), 20, 10, 10]
check l.computed(node7) == [float32(20), 20, 10, 10]

check l.computed(node8) == [float32(0), 40, 10, 10]
check l.computed(node9) == [float32(40), 40, 10, 10]
check l.computed(node10) == [float32(20), 40, 10, 10]

```
