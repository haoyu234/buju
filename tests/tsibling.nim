import unittest

import buju
import buju/core

template getAddr(body): auto =
  when NimMajor > 1: body.addr else: body.unsafeAddr

proc check2(l: ptr Context, n, firstChild, lastChild, prevSibling,
    nextSibling: NodeID) =
  let n = node(l, n)
  check n.firstChild == firstChild
  check n.lastChild == lastChild
  check n.prevSibling == prevSibling
  check n.nextSibling == nextSibling

test "insertChild":
  var l: Context

  let root = l.node()
  let node1 = l.node()
  let node2 = l.node()
  let node3 = l.node()

  check2(l.getAddr, root, NIL, NIL, NIL, NIL)

  l.insertChild(root, node1)

  check2(l.getAddr, root, node1, node1, NIL, NIL)
  check2(l.getAddr, node1, NIL, NIL, NIL, NIL)

  l.insertChild(root, node2)

  check2(l.getAddr, root, node1, node2, NIL, NIL)
  check2(l.getAddr, node1, NIL, NIL, NIL, node2)
  check2(l.getAddr, node2, NIL, NIL, node1, NIL)

  l.insertChild(root, node3)

  check2(l.getAddr, root, node1, node3, NIL, NIL)
  check2(l.getAddr, node1, NIL, NIL, NIL, node2)
  check2(l.getAddr, node2, NIL, NIL, node1, node3)
  check2(l.getAddr, node3, NIL, NIL, node2, NIL)

test "removeChild":
  var l: Context

  let root = l.node()
  let node1 = l.node()
  let node2 = l.node()
  let node3 = l.node()
  let node4 = l.node()

  l.insertChild(root, node1)
  l.insertChild(root, node2)
  l.insertChild(root, node3)
  l.insertChild(root, node4)

  # _x_
  l.removeChild(root, node2)

  check2(l.getAddr, root, node1, node4, NIL, NIL)
  check2(l.getAddr, node1, NIL, NIL, NIL, node3)
  check2(l.getAddr, node2, NIL, NIL, NIL, NIL)
  check2(l.getAddr, node3, NIL, NIL, node1, node4)
  check2(l.getAddr, node4, NIL, NIL, node3, NIL)

  # ^x_
  l.removeChild(root, node1)

  check2(l.getAddr, root, node3, node4, NIL, NIL)
  check2(l.getAddr, node1, NIL, NIL, NIL, NIL)
  check2(l.getAddr, node2, NIL, NIL, NIL, NIL)
  check2(l.getAddr, node3, NIL, NIL, NIL, node4)
  check2(l.getAddr, node4, NIL, NIL, node3, NIL)

  # _x$
  l.removeChild(root, node4)

  check2(l.getAddr, root, node3, node3, NIL, NIL)
  check2(l.getAddr, node1, NIL, NIL, NIL, NIL)
  check2(l.getAddr, node2, NIL, NIL, NIL, NIL)
  check2(l.getAddr, node3, NIL, NIL, NIL, NIL)
  check2(l.getAddr, node4, NIL, NIL, NIL, NIL)

  # ^x$
  l.removeChild(root, node3)

  check2(l.getAddr, root, NIL, NIL, NIL, NIL)
  check2(l.getAddr, node1, NIL, NIL, NIL, NIL)
  check2(l.getAddr, node2, NIL, NIL, NIL, NIL)
  check2(l.getAddr, node3, NIL, NIL, NIL, NIL)
  check2(l.getAddr, node4, NIL, NIL, NIL, NIL)
