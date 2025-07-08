# buju

buju (布局) is a simple layout engine, it is a Nim port of [layout.h](https://github.com/randrew/layout).
It has fixed several bugs left over from the original implementation and optimized the performance of some functions.

```nim
import buju

let root = Node()
root.layout = LayoutFree
root.size = vec2(50, 50)

template alignBox(n, align2) =
  let n = Node()
  n.size = vec2(10, 10)
  n.align = align2
  root.insertChild(n)

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

var l = default(Context)
l.compute(root)

check node2.computed == vec4(0, 0, 10, 10)
check node3.computed == vec4(40, 0, 10, 10)
check node4.computed == vec4(20, 0, 10, 10)

check node5.computed == vec4(0, 20, 10, 10)
check node6.computed == vec4(40, 20, 10, 10)
check node7.computed == vec4(20, 20, 10, 10)

check node8.computed == vec4(0, 40, 10, 10)
check node9.computed == vec4(40, 40, 10, 10)
check node10.computed == vec4(20, 40, 10, 10)

```
