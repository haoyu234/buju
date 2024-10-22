# buju

buju (布局) is a simple layout engine, based on [layout.h](https://github.com/randrew/layout)

```nim
import buju

var l: Layout

let root = l.node()
l.setSize(root, vec2(50, 50))

template alignBox(n, flags) =
  let n = l.node()
  l.setSize(n, vec2(10, 10))
  l.setLayoutFlags(n, flags)
  l.insertChild(root, n)

# |1|3|2|
# |4|6|5|
# |7|9|8|

alignBox(child1, LayoutTop or LayoutLeft)
alignBox(child2, LayoutTop or LayoutRight)
alignBox(child3, LayoutTop)

alignBox(child4, LayoutLeft)
alignBox(child5, LayoutRight)
alignBox(child6, 0)

alignBox(child7, LayoutBottom or LayoutLeft)
alignBox(child8, LayoutBottom or LayoutRight)
alignBox(child9, LayoutBottom)

l.compute(root)

check l.computed(child1) == vec4(0, 0, 10, 10)
check l.computed(child2) == vec4(40, 0, 10, 10)
check l.computed(child3) == vec4(20, 0, 10, 10)

check l.computed(child4) == vec4(0, 20, 10, 10)
check l.computed(child5) == vec4(40, 20, 10, 10)
check l.computed(child6) == vec4(20, 20, 10, 10)

check l.computed(child7) == vec4(0, 40, 10
check l.computed(child8) == vec4(40, 40, 10, 10)
check l.computed(child9) == vec4(20, 40, 10, 10)

```
