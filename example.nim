import unittest

import src/buju

proc drawXYWH(x, y, w, h: float32) =
  discard

# Let's pretend we're creating some kind of GUI with a master list on the
# left, and the content view on the right.

proc main() =
  # We first need one of these
  var l = default(Context)

  # Create our root node. Nodes are just 2D boxes.
  let root = l.node()

  # Let's pretend we have a window in our game or OS of some known dimension.
  # We'll want to explicitly set our root node to be that size.
  l.setSize(root, [float32(1280), 720])

  # Set our root node to arrange its children in a row, left-to-right, in the
  # order they are inserted.
  l.setLayout(root, LayoutRow)

  # Create the node for our master list.
  let masterList = l.node()
  l.insertChild(root, masterList)

  # Our master list has a specific fixed width, but we want it to fill all
  # available vertical space.
  l.setSize(masterList, [float32(400), 0])

  # We set our node's behavior within its parent to desire filling up available
  # vertical space.
  l.setAlign(masterList, {AlignTop, AlignBottom})

  # And we set it so that it will layout its children in a column,
  # top-to-bottom, in the order they are inserted.
  l.setLayout(masterList, LayoutColumn)

  let contentView = l.node()
  l.insertChild(root, contentView)

  # The content view just wants to fill up all of the remaining space, so we
  # don't need to set any size on it.
  #
  # We could just set LayoutFill here instead of bitwise-or'ing `LayoutHorizontalFill` and
  # `LayoutVerticalFill`, but I want to demonstrate that this is how you combine flags.
  l.setAlign(contentView, {AlignLeft, AlignTop, AlignRight, AlignBottom})

  # Normally at this point, we would probably want to create items for our
  # master list and our content view and insert them. This is just a dumb fake
  # example, so let's move on to finishing up.

  # this does all of the actual calculations.
  l.compute(root)

  # Now we can get the calculated size of our items as 2D rectangles. The four
  # components of the vector represent x and y of the top left corner, and then
  # the width and height.
  let masterListRect = l.computed(masterList)
  let contentViewRect = l.computed(contentView)

  check masterListRect == [float32(0), 0, 400, 720]
  check contentViewRect == [float32(400), 0, 880, 720]

  # If we're using an immediate-mode graphics library, we could draw our boxes
  # with it now.
  drawXYWH(masterListRect[0], masterListRect[1], masterListRect[2],
      masterListRect[3])

  # You could also recursively go through the entire node hierarchy using
  # `firstChild` and `nextSibling`, or something like that.

  # After you've used `compute`, the results should remain valid unless a
  # reallocation occurs.
  #
  # However, while it's true that you could manually update the existing items
  # in the context by using `setSize`, and then calling `compute`
  # again, you might want to consider just rebuilding everything from scratch
  # every frame. This is a lot easier to program than tedious fine-grained
  # invalidation, and a context with thousands of items will probably still only
  # take a handful of microseconds.
  #
  # If we want to reset our context so that we can rebuild our layout
  # tree from scratch, we use `clear`:
  l.clear()

  # And now we could start over with creating the root node, inserting more
  # items, etc. The reason we don't create a new context from scratch is that we
  # want to reuse the buffer that was already allocated.

main()
