import unittest

import buju

proc check2(
    n, firstChild, lastChild, prevSibling, nextSibling: Node
) =
  check n.firstChild == firstChild
  check n.lastChild == lastChild
  check n.prevSibling == prevSibling
  check n.nextSibling == nextSibling

test "insertChild":
  let root = Node()
  let node1 = Node()
  let node2 = Node()
  let node3 = Node()

  check2(root, nil, nil, nil, nil)

  root.insertChild(node1)

  check2(root, node1, node1, nil, nil)
  check2(node1, nil, nil, nil, nil)

  root.insertChild(node2)

  check2(root, node1, node2, nil, nil)
  check2(node1, nil, nil, nil, node2)
  check2(node2, nil, nil, node1, nil)

  root.insertChild(node3)

  check2(root, node1, node3, nil, nil)
  check2(node1, nil, nil, nil, node2)
  check2(node2, nil, nil, node1, node3)
  check2(node3, nil, nil, node2, nil)

test "removeChild":
  let root = Node()
  let node1 = Node()
  let node2 = Node()
  let node3 = Node()

  root.insertChild(node1)
  root.insertChild(node2)
  root.insertChild(node3)

  root.removeChild(node2)

  check2(root, node1, node3, nil, nil)
  check2(node1, nil, nil, nil, node3)
  check2(node2, nil, nil, nil, nil)
  check2(node3, nil, nil, node1, nil)

  root.removeChild(node1)

  check2(root, node3, node3, nil, nil)
  check2(node1, nil, nil, nil, nil)
  check2(node2, nil, nil, nil, nil)
  check2(node3, nil, nil, nil, nil)

  root.removeChild(node3)

  check2(root, nil, nil, nil, nil)
  check2(node1, nil, nil, nil, nil)
  check2(node2, nil, nil, nil, nil)
  check2(node3, nil, nil, nil, nil)
