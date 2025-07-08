# buju

buju (布局) is a simple layout engine, it is a Nim port of [layout.h](https://github.com/randrew/layout).
It has fixed several bugs left over from the original implementation and optimized the performance of some functions.

```nim
import buju

var l = default(Context)

let root = l.node()
l.setLayout(LayoutFree)
l.setSize(root, vec2(50, 50))

template alignBox(n, align) =
  let n = l.node()
  l.setSize(n, vec2(10, 10))
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

check l.computed(node2) == vec4(0, 0, 10, 10)
check l.computed(node3) == vec4(40, 0, 10, 10)
check l.computed(node4) == vec4(20, 0, 10, 10)

check l.computed(node5) == vec4(0, 20, 10, 10)
check l.computed(node6) == vec4(40, 20, 10, 10)
check l.computed(node7) == vec4(20, 20, 10, 10)

check l.computed(node8) == vec4(0, 40, 10, 10)
check l.computed(node9) == vec4(40, 40, 10, 10)
check l.computed(node10) == vec4(20, 40, 10, 10)

```
