import unittest
import std/typetraits

import buju
import buju/core

proc check2(l: ptr LayoutObj, n, firstChild, lastChild, prevSibling,
    nextSibling: LayoutNodeID) =
  let n = l.node(n)
  check n.firstChild == firstChild
  check n.lastChild == lastChild
  check n.prevSibling == prevSibling
  check n.nextSibling == nextSibling

test "insertChild":
  var l: Layout
  let p = distinctBase(l).addr

  let root = l.node()
  let node1 = l.node()
  let node2 = l.node()
  let node3 = l.node()

  check2(p, root, NIL, NIL, NIL, NIL)

  l.insertChild(root, node1)

  check2(p, root, node1, node1, NIL, NIL)
  check2(p, node1, NIL, NIL, NIL, NIL)

  l.insertChild(root, node2)

  check2(p, root, node1, node2, NIL, NIL)
  check2(p, node1, NIL, NIL, NIL, node2)
  check2(p, node2, NIL, NIL, node1, NIL)

  l.insertChild(root, node3)

  check2(p, root, node1, node3, NIL, NIL)
  check2(p, node1, NIL, NIL, NIL, node2)
  check2(p, node2, NIL, NIL, node1, node3)
  check2(p, node3, NIL, NIL, node2, NIL)

test "removeChild":
  var l: Layout
  let p = distinctBase(l).addr

  let root = l.node()
  let node1 = l.node()
  let node2 = l.node()
  let node3 = l.node()

  l.insertChild(root, node1)
  l.insertChild(root, node2)
  l.insertChild(root, node3)

  l.removeChild(root, node2)

  check2(p, root, node1, node3, NIL, NIL)
  check2(p, node1, NIL, NIL, NIL, node3)
  check2(p, node2, NIL, NIL, NIL, NIL)
  check2(p, node3, NIL, NIL, node1, NIL)

  l.removeChild(root, node1)

  check2(p, root, node3, node3, NIL, NIL)
  check2(p, node1, NIL, NIL, NIL, NIL)
  check2(p, node2, NIL, NIL, NIL, NIL)
  check2(p, node3, NIL, NIL, NIL, NIL)

  l.removeChild(root, node3)

  check2(p, root, NIL, NIL, NIL, NIL)
  check2(p, node1, NIL, NIL, NIL, NIL)
  check2(p, node2, NIL, NIL, NIL, NIL)
  check2(p, node3, NIL, NIL, NIL, NIL)
