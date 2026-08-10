include karax / prelude
import karax / [kdom, vstyles]

import buju
import buju / core
import buju / dumps

import std / [strutils, sequtils, math, json, jsffi]
import std / sets

const
  verticalAligns = {AlignTop, AlignBottom}
  horizontalAligns = {AlignLeft, AlignRight}

type
  ButtonKind = enum
    buttonDefault
    buttonPrimary

  TreeNode = object
    id: string
    label: string
    icon: VNode
    children: seq[TreeNode]

  NodeAttr = object
    wrap: Wrap
    layout: Layout
    mainAxisAlign: MainAxisAlign
    crossAxisAlign: CrossAxisAlign
    crossAxisLineAlign: CrossAxisLineAlign
    align: set[Align]
    size: array[2, float32]
    gap: array[2, float32]
    margin: array[4, float32]
    padding: array[4, float32]

  Mode = enum
    Buju
    Html5

  # Snapshot of a node's geometry from both renderers: `computed[0]` is Buju's math, `computed[1]` is the live HTML5 rect. Each is [x, y, width, height] in layout units, so the comparison tool diffs them directly.
  CompareEntry = object
    id: int32
    computed: array[2, array[4, float32]]

var
  engine = Context()
  enabledModes = {Buju}

  # Set true by `markLayoutDirty` on a geometry change. `createDom` consumes it
  # once per frame and runs `engine.compute` only when set (default true so the
  # first render computes the initial tree).
  layoutDirty = true

  rootId = default(NodeID)
  focusId = default(NodeID)
  selected: seq[NodeID]      # multi-selection, focusId is the shallowest
  anchorId = default(NodeID) # shift-range pivot in the tree's visible order
  collapsed: seq[NodeID]

  dragIds: seq[NodeID]       # nodes being dragged (subset of selected)
  dropTargetId = default(NodeID)

  defaultNodeAttr = NodeAttr(size: [50, 50])
  sourceFileName = "buju.json"

  # Viewport camera (shared pan/zoom, CSS pixels)
  viewOffsetX = float32(0)
  viewOffsetY = float32(0)
  zoomScale = float32(1)

  # Drag is captured over a full-stage overlay so handlers stay typed Karax procs.
  activeDragMode = int32(-1)
  dragMoved = false
  dragStartMouseX = float32(0)
  dragStartMouseY = float32(0)
  dragStartOffsetX = float32(0)
  dragStartOffsetY = float32(0)

proc numberField*(
    label, value, placeholder: string,
    onValueChanged: proc(value: float32),
    min: float32 = NegInf, max: float32 = Inf, step: float32 = float32(1),
): VNode =
  proc onBlur(event: Event; n: VNode) =
    var parsed = parseFloat(n.value)
    if parsed != parsed:
      parsed = 0
    if parsed < min:
      parsed = min
    if parsed > max:
      parsed = max
    onValueChanged(float32(parsed))

  buildHtml:
    tdiv(class = kstring"field"):
      span(class = kstring"field-label"): text label
      input(
        class = kstring"field-input",
        `type` = "number",
        value = kstring(value),
        placeholder = kstring(placeholder),
        onblur = onBlur,
      )

proc optionGroup*[T](
    value: T, options: openArray[T],
    iconOf: proc(option: T): VNode, labelOf: proc(option: T): string,
    onOptionChanged: proc(option: T),
): VNode =
  ## Mutually-exclusive options driven by `value`. The picked option is read
  ## from the node index at click time (no loop variable captured - avoids the
  ## Nim closure footgun). `preventDefault` keeps the VDOM owning `checked`.
  let opts = toSeq(options)

  proc onClick(event: Event; n: VNode) =
    onOptionChanged(opts[n.index])
    preventDefault(event)

  buildHtml:
    section(class = kstring"option-list"):
      for i in 0 ..< opts.len:
        let
          opt = opts[i]
          active = opt == value
          rowClass = if active: "option-row on" else: "option-row"
        label(class = kstring(rowClass)):
          input(
            `type` = "checkbox",
            checked = active,
            index = i,
            onclick = onClick,
          )
          if iconOf != nil:
            span(class = kstring"control-icon"): iconOf(opt)
          span(class = kstring"option-name"): text labelOf(opt)


proc toggleControl*(
    checked: bool, caption: string, onToggled: proc(checked: bool),
    icon: VNode = nil,
): VNode =
  proc onClick(event: Event; n: VNode) =
    onToggled(not checked)

  buildHtml:
    label(class = kstring"toggle"):
      input(
        `type` = "checkbox",
        checked = checked,
        onclick = onClick,
      )
      if icon != nil:
        span(class = kstring"control-icon"):
          icon
      text caption


proc cellGrid*(
    selected: HashSet[int32], rows: int32 = int32(3), cols: int32 = int32(3),
    onToggle: proc(index: int32),
): VNode =
  let total = rows * cols

  proc onCell(event: Event; n: VNode) =
    onToggle(n.index)

  buildHtml:
    section(class = kstring"anchor-picker"):
      for i in 0 ..< total:
        let cellClass = if i in selected: "cell on" else: "cell"
        tdiv(class = kstring(cellClass), index = i, onclick = onCell)


proc panel*(
    title: string, children: seq[VNode],
    collapsible: bool = false, expanded: bool = true,
    onExpandedChanged: proc(expanded: bool) = nil,
): VNode =
  proc onCaret(event: Event; n: VNode) =
    if onExpandedChanged != nil:
      onExpandedChanged(not expanded)

  buildHtml:
    tdiv(class = kstring"group"):
      span(class = kstring"title"):
        if collapsible:
          let caretClass = if expanded: "caret open" else: "caret"
          tdiv(class = kstring(caretClass), onclick = onCaret)
        text title
      if not collapsible or expanded:
        for child in children:
          child


proc keyValueGrid*(pairs: openArray[(string, string)]): VNode =
  buildHtml:
    section(class = kstring"computed-grid"):
      for i in 0 ..< pairs.len:
        tdiv(class = kstring"computed-cell"):
          span(class = kstring"computed-key"): text pairs[i][0]
          span(class = kstring"computed-value"): text pairs[i][1]


proc buttonControl*(
    label: string, onClick: proc(event: Event; n: VNode),
    kind: ButtonKind = buttonDefault, disabled: bool = false,
): VNode =
  let buttonClass = "tool"
  buildHtml:
    button(class = kstring(buttonClass), disabled = disabled, onclick = onClick):
      text label

proc treeView*(
    nodes: seq[TreeNode],
    expandedKeys, selectedKeys: HashSet[string],
    focusKey: string = "",
    draggingKeys: HashSet[string] = initHashSet[string](),
    dropOverKey: string = "",
    onNodeExpand: proc(id: string), onNodeSelect: proc(id: string,
        event: Event),
    onNodeDragStart: proc(id: string) = nil,
    onNodeDragOver: proc(id: string) = nil,
    onNodeDrop: proc(id: string) = nil,
    onNodeDragLeave: proc(id: string) = nil,
    onNodeDragEnd: proc(id: string) = nil,
): VNode =
  ## Controlled tree. The caller owns `expandedKeys` / `selectedKeys` / `focusKey`
  ## / drag state as plain string sets. `onNodeSelect` gets the event so the
  ## caller can branch on shift/ctrl/meta for range and toggle selection.
  proc renderTreeRow(node: TreeNode, depth: int32): VNode =
    let
      childCount = node.children.len
      expanded = node.id in expandedKeys
      selected = node.id in selectedKeys
      hasFocus = node.id == focusKey
      isDragging = node.id in draggingKeys
      isDropOver = node.id == dropOverKey
      nodeClass = "tree-node" &
        (if hasFocus: " focus" else: "") &
        (if isDragging: " dragging" else: "") &
        (if isDropOver: " dropover" else: "") &
        (if not hasFocus and selected: " sel" else: "")
      caretClass = if childCount > 0: "caret" else: "caret empty"

    proc onCaret(event: Event; n: VNode) =
      onNodeExpand(node.id)

    proc onSelectClick(event: Event; n: VNode) =
      onNodeSelect(node.id, event)

    proc onDragStart(event: Event; n: VNode) =
      if onNodeDragStart != nil:
        onNodeDragStart(node.id)

    proc onDragOver(event: Event; n: VNode) =
      preventDefault(event)
      if onNodeDragOver != nil:
        onNodeDragOver(node.id)

    proc onDrop(event: Event; n: VNode) =
      if onNodeDrop != nil:
        onNodeDrop(node.id)

    proc onDragLeave(event: Event; n: VNode) =
      if onNodeDragLeave != nil:
        onNodeDragLeave(node.id)

    proc onDragEnd(event: Event; n: VNode) =
      if onNodeDragEnd != nil:
        onNodeDragEnd(node.id)

    let rowPadding = $(depth * int32(14) + int32(4)) & "px"

    buildHtml:
      tdiv(class = kstring"tree-branch"):
        tdiv(
          class = kstring"tree-row",
          style = style((StyleAttr.paddingLeft, kstring(rowPadding))),
        ):
          tdiv(class = kstring(caretClass), onclick = onCaret):
            if childCount > 0:
              if not expanded:
                text ">"
              else:
                text "v"
          tdiv(
            class = kstring(nodeClass),
            draggable = true,
            id = kstring(node.id),
            onclick = onSelectClick,
            ondragstart = onDragStart,
            ondragover = onDragOver,
            ondrop = onDrop,
            ondragleave = onDragLeave,
            ondragend = onDragEnd,
          ):
            tdiv(class = kstring"tree-id"): text node.id
            tdiv(class = kstring"tree-name"): text node.label
            if childCount > 0:
              tdiv(class = kstring"tree-child-count"): text $(childCount)
        if childCount > 0 and expanded:
          tdiv(class = kstring"tree-children"):
            for child in node.children:
              renderTreeRow(child, depth + 1)

  buildHtml:
    tdiv(class = kstring"tree-list"):
      for node in nodes:
        renderTreeRow(node, 0)

proc formatNumber(value: float32): string =
  let floatValue = float64(value)
  if floatValue == floor(floatValue):
    $(int32(floatValue))
  else:
    var formattedText = formatFloat(floatValue, ffDecimal, 2)
    while formattedText.endsWith("0"):
      formattedText = formattedText[0 ..< formattedText.len - 1]
    if formattedText.endsWith("."):
      formattedText = formattedText[0 ..< formattedText.len - 1]
    formattedText

proc trimTypeName(symbol: string, T: typedesc): string =
  symbol.replace($T, "")

proc toPixelSize(value: float32): kstring =
  kstring(formatFloat(value, ffDecimal, 2) & "px")

proc layoutName(attribute: NodeAttr): string =
  case attribute.layout
  of LayoutRow: "Row"
  of LayoutColumn: "Column"
  of LayoutFree: "Free"

proc getParent(nodeId: NodeID): NodeID =
  when defined(debug):
    let
      n = engine.addr.node(nodeId)
    if not n.isNil:
      result = n.parent
  else:
    for idx in 0 ..< engine.nodes.len:
      let
        parentId = cast[NodeID](idx + 1)

      for child in engine.children(parentId):
        if child == nodeId:
          result = parentId
          break

proc getDepth(n: NodeID): int32 =
  result = 0
  var current = n
  while true:
    let parent = getParent(current)
    if parent.isNil: break
    current = parent
    inc result

proc getSubtreeNodes(nodeId: NodeID, pruneCollapsed: bool = false): seq[NodeID] =
  ## Depth-first pre-order under `nodeId` (including it). `pruneCollapsed` skips descendants of collapsed nodes for Shift+click range selection. false walks the whole subtree (viewports and fit need full layout).

  if nodeId.isNil:
    return

  proc collect(id: NodeID, nodes: var seq[NodeID]) =
    for child in engine.children(id):
      nodes.add(child)
      if not pruneCollapsed or child notin collapsed:
        collect(child, nodes)

  result.add(nodeId)
  if not pruneCollapsed or nodeId notin collapsed:
    collect(nodeId, result)

proc hasChild(parentId, childId: NodeID): bool =
  var
    current = childId
  while not current.isNil:
    let
      parentNode = getParent(current)
    if parentNode == parentId:
      result = true
      break

    current = parentNode

proc shallowestSelected(sel: seq[NodeID]): NodeID =
  ## The selected node closest to the root (used as the edit target).
  result = sel[0]
  var bestDepth = getDepth(result)
  for i in 1 ..< sel.len:
    let depth = getDepth(sel[i])
    if depth < bestDepth:
      bestDepth = depth
      result = sel[i]

proc selectOnly(n: NodeID) =
  focusId = n
  selected = @[n]
  anchorId = n

proc toggleSelect(n: NodeID) =
  ## Toggle `n` in the selection. The selection is never emptied.
  let idx = selected.find(n)
  if idx >= 0:
    if selected.len > 1:
      selected.delete(idx)
  else:
    selected.add(n)
  focusId = shallowestSelected(selected)
  anchorId = n

proc selectRange(to: NodeID) =
  ## Select every visible row between `anchorId` and `to` (inclusive), replacing
  ## the old selection. If there is no anchor, behave like a single select.
  if anchorId.isNil or anchorId == to:
    selectOnly(to)
    return

  let
    order = getSubtreeNodes(rootId, pruneCollapsed = true)
    anchorIndex = order.find(anchorId)
    targetIndex = order.find(to)
  if anchorIndex < 0 or targetIndex < 0:
    selectOnly(to)
    return

  let (lo, hi) = if anchorIndex <= targetIndex: (anchorIndex, targetIndex) else: (targetIndex, anchorIndex)
  var nodes: seq[NodeID]
  for i in lo .. hi:
    nodes.add(order[i])

  selected = nodes
  focusId = shallowestSelected(selected)

proc independentTopNodes(ids: seq[NodeID]): seq[NodeID] =
  ## Keep only nodes that are not descendants of another node in `ids`, so a
  ## subtree is moved as one unit rather than its members independently.
  for nodeId in ids:
    if not ids.anyIt(it != nodeId and hasChild(it, nodeId)):
      result.add(nodeId)


proc getAttr(id: NodeID): NodeAttr =
  let n = node(engine.addr, id)
  if n.isNil:
    return

  result.wrap = n.wrap
  result.layout = n.layout
  result.mainAxisAlign = n.mainAxisAlign
  result.crossAxisAlign = n.crossAxisAlign
  result.crossAxisLineAlign = n.crossAxisLineAlign
  result.align = n.align
  result.size = n.size
  result.gap = n.gap
  result.margin = n.margin
  result.padding = n.padding

proc updateAttr(n: NodeID, attr: NodeAttr) =
  engine.setWrap(n, attr.wrap)
  engine.setLayout(n, attr.layout)
  engine.setMainAxisAlign(n, attr.mainAxisAlign)
  engine.setCrossAxisAlign(n, attr.crossAxisAlign)
  engine.setCrossAxisLineAlign(n, attr.crossAxisLineAlign)
  engine.setAlign(n, attr.align)
  engine.setSize(n, attr.size)
  engine.setMargin(n, attr.margin)
  engine.setPadding(n, attr.padding)

proc markLayoutDirty() =
  ## Mark the layout stale after a geometry change. `engine.compute` is deferred to the render pass (once per frame), so repeated calls still yield one recompute. Pure view transforms (pan/zoom) must NOT call this.
  layoutDirty = true

proc createNode(attr: NodeAttr): NodeID =
  result = engine.node()
  updateAttr(result, attr)

proc removeNode(childId: NodeID) =
  let parentId = getParent(childId)
  if parentId.isNil:
    return

  if focusId == childId:
    focusId = engine.nextSibling(childId)
    if focusId.isNil:
      focusId = parentId

  engine.removeChild(parentId, childId)
  selected = @[focusId]
  anchorId = focusId
  markLayoutDirty()

proc removeNextSiblings(childId: NodeID) =
  let parentId = getParent(childId)
  if parentId.isNil:
    return

  if focusId == childId:
    var next = engine.nextSibling(childId)
    while not next.isNil:
      let n = engine.nextSibling(next)
      engine.removeChild(parentId, next)
      next = n
    focusId = parentId

  engine.removeChild(parentId, childId)
  selected = @[focusId]
  anchorId = focusId
  markLayoutDirty()

proc canDrop(child, target: NodeID): bool =
  if child == target or child == rootId:
    return

  var current = target
  while not current.isNil:
    if current == child:
      return

    current = getParent(current)

  result = true

proc reparent(child, target: NodeID) =
  if not canDrop(child, target):
    return

  let oldParent = getParent(child)
  if oldParent.isNil or oldParent == target:
    return

  # engine requires the node detached from its old parent before insert (debug asserts `parent.isNil`).
  engine.removeChild(oldParent, child)
  engine.insertChild(target, child)
  focusId = child

proc reparent(children: seq[NodeID], target: NodeID) =
  ## Reparent every top-level selected node under `target`. descendants ride along (filtered by `independentTopNodes`), so a subtree moves as one.
  var moved: seq[NodeID]
  for topNode in independentTopNodes(children):
    if canDrop(topNode, target):
      reparent(topNode, target)
      moved.add(topNode)

  if moved.len > 0:
    selected = moved
    focusId = shallowestSelected(moved)
    anchorId = focusId
    markLayoutDirty()

# Karax does not wrap `WheelEvent`. this is `importcpp` (typed FFI), not the string-injection `emit` escape hatch.
proc wheelDeltaY(event: Event): float32 {.importcpp: "#.deltaY", nodecl.}


proc getViewportClientSize(): tuple[w, h: float32] =
  ## Viewport size in CSS pixels. `document` is the real browser global, so this works regardless of Nim bindings.
  when defined(js):
    let element = document.querySelector(".viewer-viewport".cstring)
    if element == nil:
      return (float32(0), float32(0))
    let rect = element.getBoundingClientRect()
    return (rect.width, rect.height)


proc computeBoundingBox(): tuple[
    width, height, minX, minY: float32
  ] =
  ## Union bounding box of every node at zoom 1 (screen px), including negative coordinates. The 1px outline (see `.node` in styles.css) takes no layout space, but the union is still expanded 1px per side as a safety margin against `overflow: hidden` clipping it. Used to size the world and shift the origin to (0,0).
  var
    minX = float32(1e30)
    minY = float32(1e30)
    maxX = float32(-1e30)
    maxY = float32(-1e30)

  for n in getSubtreeNodes(rootId):
    let
      computed = engine.computed(n)
    minX = min(minX, computed[0])
    minY = min(minY, computed[1])
    maxX = max(maxX, computed[0] + computed[2])
    maxY = max(maxY, computed[1] + computed[3])

  if minX > maxX:
    minX = 0
    maxX = 0

  if minY > maxY:
    minY = 0
    maxY = 0

  let
    minXpx = minX - 1
    minYpx = minY - 1
    maxXpx = maxX + 1
    maxYpx = maxY + 1

  result.width = maxXpx - minXpx
  result.height = maxYpx - minYpx
  result.minX = minXpx
  result.minY = minYpx

proc fitView() =
  ## "Fit to screen": clear old zoom/drag, pick a zoom fitting the whole bounding box (the world is flex-centered and scaled about its center, so drag stays 0).
  ## `engine.compute` normally runs inside `createDom` via Karax's async `redraw()`. fitView is called synchronously right after, so we compute here up front or `computeBoundingBox` would read the previous tree.
  engine.compute(rootId)
  layoutDirty = false

  let (viewportWidth, viewportHeight) = getViewportClientSize()

  if viewportWidth <= 0 or viewportHeight <= 0:
    zoomScale = float32(1)
    viewOffsetX = 0
    viewOffsetY = 0
    redraw()
    return

  let box = computeBoundingBox()

  if box.width <= 0 or box.height <= 0:
    zoomScale = float32(1)
  else:
    const pad = float32(0.9)
    let fitZoom = min(viewportWidth / box.width, viewportHeight / box.height) * pad
    zoomScale = max(float32(0.01), min(fitZoom, float32(100.0)))

  viewOffsetX = 0
  viewOffsetY = 0
  redraw()

proc installSpaceFitShortcut(callback: proc()) =
  when defined(js):
    window.addEventListener("keydown".cstring, proc(event: Event) =
      let keyboardEvent = cast[KeyboardEvent](event)
      if keyboardEvent.code != "Space".cstring and keyboardEvent.key !=
          " ".cstring: return
      # Skip when focus is in a form field. `document.activeElement` is a property, not a function, so it is read directly (a function-style binding compiles to `document.activeElement()` and throws on every keydown).
      {.emit: """
      var activeElement = document.activeElement;
      if (activeElement && (activeElement.nodeName === "INPUT" || activeElement.nodeName === "TEXTAREA" || activeElement.nodeName === "SELECT")) {
        return;
      }
      """.}
      keyboardEvent.preventDefault()
      callback()
    )


proc makeViewportDragHandler(mode: Mode): proc(event: Event; n: VNode) =
  proc(event: Event; n: VNode) =
    let mouseEvent = cast[MouseEvent](event)
    activeDragMode = int32(mode)
    dragMoved = false
    dragStartMouseX = float32(mouseEvent.clientX)
    dragStartMouseY = float32(mouseEvent.clientY)
    dragStartOffsetX = viewOffsetX
    dragStartOffsetY = viewOffsetY

proc makeViewportWheelHandler(mode: Mode): proc(event: Event; n: VNode) =
  proc(event: Event; n: VNode) =
    let mouseEvent = cast[MouseEvent](event)
    let
      deltaY = wheelDeltaY(event)
      rect = event.currentTarget.getBoundingClientRect()
      mouseX = float32(mouseEvent.clientX) - float32(rect.left)
      mouseY = float32(mouseEvent.clientY) - float32(rect.top)
      oldZoom = zoomScale
      oldOffsetX = viewOffsetX
      oldOffsetY = viewOffsetY
      factor = if deltaY < 0: float32(1.1) else: float32(0.9)

    var newZoom = oldZoom * factor
    if newZoom < float32(0.1):
      newZoom = float32(0.1)
    if newZoom > float32(10.0):
      newZoom = float32(10.0)

    let
      viewportWidth = float32(rect.width)
      viewportHeight = float32(rect.height)
      ratio = newZoom / oldZoom

    viewOffsetX =
      oldOffsetX + (mouseX - viewportWidth / 2 - oldOffsetX) * (1 - ratio)
    viewOffsetY =
      oldOffsetY + (mouseY - viewportHeight / 2 - oldOffsetY) * (1 - ratio)
    zoomScale = newZoom

    preventDefault(event)

proc renderViewportDragOverlay(): VNode =
  if activeDragMode < 0:
    result = buildHtml(tdiv(class = "drag-overlay hidden"))
    return

  proc onMouseMove(event: Event; n: VNode) =
    let
      mouseEvent = cast[MouseEvent](event)
      deltaX = float32(mouseEvent.clientX) - dragStartMouseX
      deltaY = float32(mouseEvent.clientY) - dragStartMouseY
    dragMoved = true
    viewOffsetX = dragStartOffsetX + deltaX
    viewOffsetY = dragStartOffsetY + deltaY

  proc onMouseUp(event: Event; n: VNode) =
    activeDragMode = -1

  buildHtml:
    tdiv(
      class = "drag-overlay is-dragging",
      onmousemove = onMouseMove,
      onmouseup = onMouseUp,
    )


proc getFlexUtilityClassName(attribute: StyleAttr, value: kstring): string =
  result = ""
  case attribute
  of StyleAttr.display:
    if value == kstring("flex"): result = "d-flex"
  of StyleAttr.flexDirection:
    if value == kstring("column"): result = "fd-column"
    elif value == kstring("row"): result = "fd-row"
  of StyleAttr.flexWrap:
    if value == kstring("wrap"): result = "fw-wrap"
  of StyleAttr.justifyContent:
    if value == kstring("flex-start"): result = "jc-start"
    elif value == kstring("center"): result = "jc-center"
    elif value == kstring("flex-end"): result = "jc-end"
    elif value == kstring("space-between"): result = "jc-between"
    elif value == kstring("space-around"): result = "jc-around"
    elif value == kstring("space-evenly"): result = "jc-evenly"
  of StyleAttr.alignItems:
    if value == kstring("flex-start"): result = "ai-start"
    elif value == kstring("center"): result = "ai-center"
    elif value == kstring("flex-end"): result = "ai-end"
    elif value == kstring("stretch"): result = "ai-stretch"
  of StyleAttr.alignContent:
    if value == kstring("flex-start"): result = "ac-start"
    elif value == kstring("center"): result = "ac-center"
    elif value == kstring("flex-end"): result = "ac-end"
    elif value == kstring("stretch"): result = "ac-stretch"
    elif value == kstring("space-between"): result = "ac-between"
    elif value == kstring("space-around"): result = "ac-around"
    elif value == kstring("space-evenly"): result = "ac-evenly"
  else: discard

proc getMainAxisCss(attribute: MainAxisAlign): kstring =
  case attribute
  of MainAxisAlignMiddle: kstring("center")
  of MainAxisAlignStart: kstring("flex-start")
  of MainAxisAlignEnd: kstring("flex-end")
  of MainAxisAlignSpaceBetween: kstring("space-between")
  of MainAxisAlignSpaceAround: kstring("space-around")
  of MainAxisAlignSpaceEvenly: kstring("space-evenly")

proc getCrossAxisCss(attribute: CrossAxisAlign): kstring =
  case attribute
  of CrossAxisAlignMiddle: kstring("center")
  of CrossAxisAlignStart: kstring("flex-start")
  of CrossAxisAlignEnd: kstring("flex-end")
  of CrossAxisAlignStretch: kstring("stretch")

proc getCrossLineCss(attribute: CrossAxisLineAlign): kstring =
  case attribute
  of CrossAxisLineAlignMiddle: kstring("center")
  of CrossAxisLineAlignStart: kstring("flex-start")
  of CrossAxisLineAlignEnd: kstring("flex-end")
  of CrossAxisLineAlignStretch: kstring("stretch")
  of CrossAxisLineAlignSpaceBetween: kstring("space-between")
  of CrossAxisLineAlignSpaceAround: kstring("space-around")
  of CrossAxisLineAlignSpaceEvenly: kstring("space-evenly")

proc getAlignCss(attribute: Align): kstring =
  case attribute
  of AlignLeft, AlignTop:
    kstring("flex-start")
  of AlignRight, AlignBottom:
    kstring("flex-end")
  of AlignMiddle:
    kstring("center")

proc alignmentGlyph(
    attrs: seq[(StyleAttr, kstring)], extraClass: string, blockCount: int32
): VNode =
  var classNames = "glyph " & extraClass
  for (attribute, value) in attrs:
    let className = getFlexUtilityClassName(attribute, value)
    if className.len > 0:
      classNames &= " " & className
  buildHtml:
    span(class = kstring(classNames)):
      for i in 0 ..< blockCount:
        span(class = "glyph-block")

proc freeGlyph(): VNode =
  buildHtml:
    span(class = "glyph glyph-free"):
      span(class = "glyph-block")
      span(class = "glyph-block")
      span(class = "glyph-block")

proc layoutGlyph(layout: Layout): VNode =
  case layout
  of LayoutRow:
    result = alignmentGlyph(
      @[
        (StyleAttr.display, kstring("flex")),
        (StyleAttr.flexDirection, kstring("row")),
        (StyleAttr.alignItems, kstring("center")),
      ],
      "", 3)
  of LayoutColumn:
    result = alignmentGlyph(
      @[
        (StyleAttr.display, kstring("flex")),
        (StyleAttr.flexDirection, kstring("column")),
        (StyleAttr.alignItems, kstring("center")),
      ],
      "cross-axis", 3)
  of LayoutFree:
    result = freeGlyph()

proc mainAxisGlyph(attribute: MainAxisAlign): VNode =
  alignmentGlyph(
    @[
      (StyleAttr.display, kstring("flex")),
      (StyleAttr.justifyContent, getMainAxisCss(attribute)),
      (StyleAttr.alignItems, kstring("center")),
    ],
    "", 3)

proc crossAxisGlyph(attribute: CrossAxisAlign): VNode =
  ## Cross-axis alignment drawn as a vertical bar column. Stretch fills it.
  let (jc, stretch) = case attribute
    of CrossAxisAlignStart: (kstring("flex-start"), false)
    of CrossAxisAlignMiddle: (kstring("center"), false)
    of CrossAxisAlignEnd: (kstring("flex-end"), false)
    of CrossAxisAlignStretch: (kstring("flex-start"), true)
  let glyphClass = if stretch: "cross-axis stretch" else: "cross-axis"
  alignmentGlyph(
    @[
      (StyleAttr.display, kstring("flex")),
      (StyleAttr.flexDirection, kstring("column")),
      (StyleAttr.justifyContent, jc),
    ],
    glyphClass, 3)

proc crossLineGlyph(attribute: CrossAxisLineAlign): VNode =
  # Three-bar column. justify-content drives line-align spread, Stretch fills vertically.
  let (jc, ai, stretch) = case attribute
    of CrossAxisLineAlignStart: (kstring("flex-start"), kstring("center"), false)
    of CrossAxisLineAlignMiddle: (kstring("center"), kstring("center"), false)
    of CrossAxisLineAlignEnd: (kstring("flex-end"), kstring("center"), false)
    of CrossAxisLineAlignStretch: (kstring("flex-start"), kstring("stretch"), true)
    of CrossAxisLineAlignSpaceBetween: (kstring("space-between"), kstring(
        "center"), false)
    of CrossAxisLineAlignSpaceAround: (kstring("space-around"), kstring(
        "center"), false)
    of CrossAxisLineAlignSpaceEvenly: (kstring("space-evenly"), kstring(
        "center"), false)
  let glyphClass = if stretch: "line-align stretch" else: "line-align"
  alignmentGlyph(
    @[
      (StyleAttr.display, kstring("flex")),
      (StyleAttr.flexDirection, kstring("column")),
      (StyleAttr.justifyContent, jc),
      (StyleAttr.alignItems, ai),
    ],
    glyphClass, 3)


proc wrapGlyph(): VNode =
  buildHtml:
    span(class = kstring"glyph glyph-wrap"):
      span(class = kstring"wrap-flow"):
        span(class = kstring"glyph-block")
        span(class = kstring"glyph-block")
        span(class = kstring"glyph-block")

proc stretchGlyph(horizontal: bool): VNode =
  let glyphClass = if horizontal: "glyph stretch-h" else: "glyph stretch-v"
  buildHtml:
    span(class = kstring(glyphClass)):
      span(class = kstring"glyph-block")

proc cellToAlign(columnIndex, rowIndex: int32): set[Align] =
  result = {}
  if columnIndex == 1 and rowIndex == 1:
    # Center cell sets `AlignMiddle`. Resolved per axis it yields AxisAlignMiddle:
    # on the cross axis it centers the child (align-self: center, overriding the
    # parent). In the Free overlay model it also centers the main axis. Distinct
    # from the empty set, which means "inherit the parent's cross-axis alignment".
    result.incl AlignMiddle
    return

  case columnIndex
  of 0: result.incl AlignLeft
  of 2: result.incl AlignRight
  else: discard

  case rowIndex
  of 0: result.incl AlignTop
  of 2: result.incl AlignBottom
  else: discard

proc getNodeClassName(n: NodeID): string =
  if n == focusId: "node focus" else: "node"

proc renderNode(n: NodeID, style: VStyle, suffix: string, children: seq[
    VNode] = @[]): VNode =
  buildHtml:
    tdiv(
      class = kstring(getNodeClassName(n) & " " & suffix),
      style = style,
      name = kstring($n),
    ):
      tdiv(class = "node-label"):
        text $(cast[int32](n))
      for child in children:
        child

proc renderBuju(zoom: float32, minX: float32, minY: float32): VNode =
  ## Absolute renderer. Coordinates pre-multiplied by `zoom` so outline/label
  ## stay constant 1px / 11px (no CSS transform).
  proc getBujuNodeStyle(bounds: array[4, float32], zIndex: int32): VStyle =
    style(
      (StyleAttr.left, toPixelSize((bounds[0] - minX) * zoom)),
      (StyleAttr.top, toPixelSize((bounds[1] - minY) * zoom)),
      (StyleAttr.width, toPixelSize(bounds[2] * zoom)),
      (StyleAttr.height, toPixelSize(bounds[3] * zoom)),
      (StyleAttr.position, kstring"absolute"),
      (StyleAttr.zIndex, kstring($zIndex)),
    )

  let nodes = getSubtreeNodes(rootId)

  buildHtml:
    section(class = kstring"viewer-buju"):
      for n in nodes:
        renderNode(n, getBujuNodeStyle(engine.computed(n), int32(n)), "is-absolute")

proc getHtml5Rect(n: NodeID, rootLeft, rootTop, rootWidth, rootHeight: float32,
    rootWorld: array[4, float32]): array[4, float32] =
  ## Measure a node's live HTML5 rect and normalize back to world coordinates (all-zeros when the node is absent from the DOM, i.e. "unmeasured"). The pixel->world scale is taken from the root's *actual* rendered box, not the nominal fit-zoom: calibrating against the live box divides out the browser's sub-pixel drift, keeping the round-trip exact.
  let element = document.querySelector((".viewer-html5 [name=" & $n & "]").cstring)
  if element == nil:
    result = [float32(0), float32(0), float32(0), float32(0)]
    return

  let
    rect = element.getBoundingClientRect()
    scaleX = if rootWidth != 0: rootWorld[2] / rootWidth else: float32(1)
    scaleY = if rootHeight != 0: rootWorld[3] / rootHeight else: float32(1)
  result[0] = rootWorld[0] + float32((rect.left - float64(rootLeft)) * float64(scaleX))
  result[1] = rootWorld[1] + float32((rect.top - float64(rootTop)) * float64(scaleY))
  result[2] = float32(rect.width * float64(scaleX))
  result[3] = float32(rect.height * float64(scaleY))

proc renderHtml5(zoom: float32, minX: float32, minY: float32): VNode =
  ## Flex renderer. Lengths pre-multiplied by `zoom` so outlines stay 1px. The
  ## tree is shifted by the root's offset from the bounding-box origin.
  proc getHtml5NodeStyle(
      attr: NodeAttr, parentAttr: NodeAttr, parentBounds: array[4, float32],
      bounds: array[4, float32], zIndex: int32, n: NodeID
  ): VStyle =
    result = style(
      (StyleAttr.marginLeft, toPixelSize(attr.margin[0] * zoom)),
      (StyleAttr.marginTop, toPixelSize(attr.margin[1] * zoom)),
      (StyleAttr.marginRight, toPixelSize(attr.margin[2] * zoom)),
      (StyleAttr.marginBottom, toPixelSize(attr.margin[3] * zoom)),
      (StyleAttr.paddingLeft, toPixelSize(attr.padding[0] * zoom)),
      (StyleAttr.paddingTop, toPixelSize(attr.padding[1] * zoom)),
      (StyleAttr.paddingRight, toPixelSize(attr.padding[2] * zoom)),
      (StyleAttr.paddingBottom, toPixelSize(attr.padding[3] * zoom)),
      (StyleAttr.zIndex, kstring($zIndex)),
    )

    # size is a hard minimum. A stretching flex axis stays `auto` so CSS
    # flex-grow / align-self:stretch take over (pinning there kills stretch).
    # we emit min-* always and pin a fixed size only on non-stretching axes.

    # `AlignMiddle` overrides opposing anchors in buju (centered, never stretched),
    # so a centered child is treated as not stretched here.
    let
      centered = AlignMiddle in attr.align
      mainStretched =
        case parentAttr.layout
        of LayoutRow: (attr.align * horizontalAligns) == horizontalAligns
        of LayoutColumn: (attr.align * verticalAligns) == verticalAligns
        else: false
      # A flex child with no explicit cross-axis anchor INHERITS the parent's
      # `crossAxisAlign`. When that is Stretch the child stretches too, so its
      # size stays `auto` (else it is pinned to `size` and never reaches the
      # parent's cross size).
      crossStretched =
        case parentAttr.layout
        of LayoutRow:
          let crossAnchors = attr.align * verticalAligns
          (len(crossAnchors) == 2) or
            (len(crossAnchors) == 0 and
             parentAttr.crossAxisAlign == CrossAxisAlignStretch)
        of LayoutColumn:
          let crossAnchors = attr.align * horizontalAligns
          (len(crossAnchors) == 2) or
            (len(crossAnchors) == 0 and
             parentAttr.crossAxisAlign == CrossAxisAlignStretch)
        else: false

    if parentAttr.layout == LayoutFree:
      # Free children are absolutely positioned. Their box is owned by the
      # Free-child branch below, so do NOT pin `size` here.
      discard
    else:
      # A stretched flex axis stays `auto` (min-* is the floor) so CSS flexbox
      # does its own stretch. We do NOT pin it to buju's `bounds`. Pinning would
      # make jsHtml a verbatim echo of jsBuju, so the buju-vs-jsHtml diff would
      # always pass for stretched nodes (circular) and hide real divergences.
      let
        stretchedHorizontally =
          (parentAttr.layout == LayoutRow and mainStretched and not centered) or
          (parentAttr.layout == LayoutColumn and crossStretched and not centered)
        stretchedVertically =
          (parentAttr.layout == LayoutRow and crossStretched and not centered) or
          (parentAttr.layout == LayoutColumn and mainStretched and not centered)

      # Non-stretched axis: pin the explicit `size` (fixed box). Stretched axis:
      # leave `auto` so CSS can stretch it. only enforce `size` as the floor.
      if not stretchedHorizontally and attr.size[0] > 0:
        result.setAttr(StyleAttr.width, toPixelSize(attr.size[0] * zoom))
      if attr.size[0] > 0:
        result.setAttr(StyleAttr.minWidth, toPixelSize(attr.size[0] * zoom))

      if not stretchedVertically and attr.size[1] > 0:
        result.setAttr(StyleAttr.height, toPixelSize(attr.size[1] * zoom))
      if attr.size[1] > 0:
        result.setAttr(StyleAttr.minHeight, toPixelSize(attr.size[1] * zoom))

    if attr.gap[0] > 0:
      result.setAttr(StyleAttr.columnGap, toPixelSize(attr.gap[0] * zoom))

    if attr.gap[1] > 0:
      result.setAttr(StyleAttr.rowGap, toPixelSize(attr.gap[1] * zoom))

    case attr.layout
    of LayoutRow:
      result.setAttr(StyleAttr.display, "flex")
      result.setAttr(StyleAttr.flexDirection, "row")
    of LayoutColumn:
      result.setAttr(StyleAttr.display, "flex")
      result.setAttr(StyleAttr.flexDirection, "column")
    of LayoutFree:
      # A Free container is the positioning context for its absolute children.
      # Echo BOTH computed dimensions (the engine already folded stretch into
      # `bounds`). `flex-grow` is suppressed below so flexbox does not
      # double-count free space. The main axis must be pinned too: its size is
      # content-derived from absolutely-positioned children, which flexbox
      # cannot reproduce from `flex-grow`, so `auto` would collapse it.
      result.setAttr(StyleAttr.position, kstring"relative")
      if parentAttr.layout == LayoutFree:
        # Absolute child of a Free container: the final computed rect IS the box.
        result.setAttr(StyleAttr.width, toPixelSize(bounds[2] * zoom))
        result.setAttr(StyleAttr.height, toPixelSize(bounds[3] * zoom))
      else:
        result.setAttr(StyleAttr.width, toPixelSize(bounds[2] * zoom))
        result.setAttr(StyleAttr.height, toPixelSize(bounds[3] * zoom))

    case attr.wrap
    of WrapWrap:
      result.setAttr(StyleAttr.flexWrap, "wrap")
    of WrapNoWrap:
      result.setAttr(StyleAttr.flexWrap, "nowrap")

    result.setAttr(StyleAttr.justifyContent, getMainAxisCss(attr.mainAxisAlign))

    result.setAttr(StyleAttr.alignContent, getCrossLineCss(
        attr.crossAxisLineAlign))
    result.setAttr(StyleAttr.alignItems, getCrossAxisCss(attr.crossAxisAlign))
    case parentAttr.layout
    of LayoutRow:
      # Mirror buju's AlignMiddle-over-opposing-anchors priority: Left+Right +
      # AlignMiddle centers, does not stretch.
      let
        centered = AlignMiddle in attr.align
        matchedAligns = attr.align * verticalAligns
      if not centered and len(matchedAligns) == len(verticalAligns):
        result.setAttr(StyleAttr.alignSelf, "stretch")
      elif centered:
        result.setAttr(StyleAttr.alignSelf, "center")
      else:
        for a in verticalAligns:
          if a in matchedAligns:
            result.setAttr(StyleAttr.alignSelf, getAlignCss(a))
            break

      if attr.layout != LayoutFree and not centered and
          attr.align * horizontalAligns == horizontalAligns:
        result.setAttr(StyleAttr.flexGrow, "1")

    of LayoutColumn:
      let
        centered = AlignMiddle in attr.align
        matchedAligns = attr.align * horizontalAligns
      if not centered and len(matchedAligns) == len(horizontalAligns):
        result.setAttr(StyleAttr.alignSelf, "stretch")
      elif centered:
        result.setAttr(StyleAttr.alignSelf, "center")
      else:
        for a in horizontalAligns:
          if a in matchedAligns:
            result.setAttr(StyleAttr.alignSelf, getAlignCss(a))
            break

      if attr.layout != LayoutFree and not centered and
          attr.align * verticalAligns == verticalAligns:
        result.setAttr(StyleAttr.flexGrow, "1")

    of LayoutFree:
      # Free children are absolutely positioned. Opposing anchors become CSS
      # insets (CSS computes the stretched size). A single/no anchor echoes the
      # computed rect relative to the parent.
      result.setAttr(StyleAttr.position, "absolute")
      # Free children carry no CSS margin: it is already folded into the insets
      # (stretch) or into computed (echo), so reset to avoid double-counting.
      result.setAttr(StyleAttr.marginLeft, "0")
      result.setAttr(StyleAttr.marginTop, "0")
      result.setAttr(StyleAttr.marginRight, "0")
      result.setAttr(StyleAttr.marginBottom, "0")

      let
        hasLeft = AlignLeft in attr.align
        hasRight = AlignRight in attr.align
        hasTop = AlignTop in attr.align
        hasBottom = AlignBottom in attr.align

      # buju gives AlignMiddle priority over opposing anchors: Left+Right (or
      # Top+Bottom) + AlignMiddle centers, not stretches. Emit stretch insets
      # only when AlignMiddle is absent. Otherwise echo the computed rect.
      let centered = AlignMiddle in attr.align

      if (hasLeft and hasRight) and not centered:
        result.setAttr(StyleAttr.left, toPixelSize((parentAttr.padding[0] +
            attr.margin[0]) * zoom))
        result.setAttr(StyleAttr.right, toPixelSize((parentAttr.padding[2] +
            attr.margin[2]) * zoom))
        if attr.size[0] > 0:
          result.setAttr(StyleAttr.minWidth, toPixelSize(attr.size[0] * zoom))
      else:
        result.setAttr(StyleAttr.left, toPixelSize((bounds[0] - parentBounds[
            0]) * zoom))
        result.setAttr(StyleAttr.width, toPixelSize(bounds[2] * zoom))

      if (hasTop and hasBottom) and not centered:
        result.setAttr(StyleAttr.top, toPixelSize((parentAttr.padding[1] +
            attr.margin[1]) * zoom))
        result.setAttr(StyleAttr.bottom, toPixelSize((parentAttr.padding[3] +
            attr.margin[3]) * zoom))
        if attr.size[1] > 0:
          result.setAttr(StyleAttr.minHeight, toPixelSize(attr.size[1] * zoom))
      else:
        result.setAttr(StyleAttr.top, toPixelSize((bounds[1] - parentBounds[
            1]) * zoom))
        result.setAttr(StyleAttr.height, toPixelSize(bounds[3] * zoom))

    # Pin the ROOT to flex:none. The dummy `parentAttr = LayoutRow` at the call
    # site makes the branch above emit `flex-grow:1` + `align-self:stretch`, so
    # the root grows to fill `.viewer-html5` (display:flex) and getHtml5Rect's
    # scaleX normalization divides that overshoot into every descendant,
    # producing ~4% size errors. flex:none makes the root use its exact computed
    # size (scaleX==1), so the comparison is faithful.
    if n == rootId:
      result.setAttr(StyleAttr.flexGrow, "0")
      result.setAttr(StyleAttr.flexShrink, "0")
      result.setAttr(StyleAttr.flexBasis, "auto")
      # Pin BOTH dimensions to buju's authoritative computed rect so CSS never
      # re-derives the size (an auto-height root would give stretched children
      # nothing to fill).
      result.setAttr(StyleAttr.width, toPixelSize(bounds[2] * zoom))
      result.setAttr(StyleAttr.height, toPixelSize(bounds[3] * zoom))
      # Reset root margin: it is already baked into `rootOffset`, so re-emitting
      # it would shift the whole subtree (Html5-only mismatch. buju mode never
      # applies margin).
      result.setAttr(StyleAttr.marginLeft, "0")
      result.setAttr(StyleAttr.marginTop, "0")
      result.setAttr(StyleAttr.marginRight, "0")
      result.setAttr(StyleAttr.marginBottom, "0")

  proc renderHtml5Node(n: NodeID, parentAttr: NodeAttr, parentBounds: array[4,
      float32]): VNode =

    let
      bounds = engine.computed(n)
      attr = getAttr(n)

    var children: seq[VNode]
    for child in engine.children(n):
      children.add(renderHtml5Node(child, attr, bounds))

    renderNode(n, getHtml5NodeStyle(attr, parentAttr, parentBounds, bounds,
        int32(n), n), "flex-node", children)

  let
    rootComputed = engine.computed(rootId)
    rootOffsetX = (rootComputed[0] - minX) * zoom
    rootOffsetY = (rootComputed[1] - minY) * zoom

  buildHtml:
    section(
      class = kstring"viewer-html5",
      style = style(
        (StyleAttr.position, kstring"relative"),
        (StyleAttr.left, toPixelSize(rootOffsetX)),
        (StyleAttr.top, toPixelSize(rootOffsetY)),
      )
    ):
      # Pass a non-Free dummy so the Free-child absolute branch never fires.
      renderHtml5Node(rootId, NodeAttr(layout: LayoutRow), engine.computed(rootId))

proc chooseEnum[T](
    opts: openArray[T], current: T,
    iconOf: proc(option: T): VNode,
    onChanged: proc(option: T),
): VNode =
  proc dispatch(option: T) =
    onChanged(option)
    markLayoutDirty()

  optionGroup[T](
    current, opts, iconOf,
    proc(option: T): string = trimTypeName($option, T),
    onOptionChanged = dispatch)

proc chooseLayout(attr: NodeAttr): VNode =
  proc onChanged(value: Layout) =
    engine.setLayout(focusId, value)
    markLayoutDirty()

  chooseEnum(
    [LayoutRow, LayoutColumn, LayoutFree],
    attr.layout,
    layoutGlyph,
    onChanged)

proc chooseWrap(attr: NodeAttr): VNode =
  let on = attr.wrap == WrapWrap
  proc onChanged(option: int32) =
    engine.setWrap(focusId, if on: WrapNoWrap else: WrapWrap)
    markLayoutDirty()
  optionGroup[int32](
    (if on: int32(0) else: int32(-1)), @[int32(0)],
    proc(option: int32): VNode = wrapGlyph(),
    proc(option: int32): string = "Wrap",
    onChanged)

proc chooseAlign(attr: NodeAttr): VNode =
  let
    stretchedHorizontally = AlignLeft in attr.align and AlignRight in attr.align
    stretchedVertically = AlignTop in attr.align and AlignBottom in attr.align

  var selected = initHashSet[int32]()
  for rowIndex in 0 .. 2:
    for columnIndex in 0 .. 2:
      let
        mask = cellToAlign(int32(columnIndex), int32(rowIndex))
        active =
          if AlignMiddle in attr.align and AlignMiddle notin mask:
            false
          else:
            let common = mask * attr.align
            common == mask
      if active:
        selected.incl(int32(rowIndex * 3 + columnIndex))

  proc onToggleCell(index: int32) =
    let
      clickedColumn = index mod 3
      clickedRow = index div 3
      mask = cellToAlign(clickedColumn, clickedRow)
      common = mask * attr.align

    if AlignMiddle in mask:
      # Center cell toggles ONLY the center bit, keeping any edge anchors intact
      # so they are restored when center is off again.
      if AlignMiddle in attr.align:
        engine.setAlign(focusId, attr.align - {AlignMiddle})
      else:
        engine.setAlign(focusId, {AlignMiddle})
    else:
      # Edge/corner cell uses "complete-or-clear": if every anchor of this cell
      # is already selected, clicking clears them all. if not, all of them are
      # ensured selected (a partial corner is completed, not flipped edge by
      # edge). Picking a side also means "not centered", so drop any explicit
      # center first.
      if common == mask:
        engine.setAlign(focusId, attr.align - {AlignMiddle} - mask)
      else:
        engine.setAlign(focusId, attr.align - {AlignMiddle} + mask)
    markLayoutDirty()

  proc onHorizontalStretch(checked: bool) =
    # Enabling horizontal stretch must drop the explicit center bit first. buju
    # gives `AlignMiddle` priority over opposing anchors, so a node carrying
    # both would stay centered and the toggle would appear to do nothing.
    if checked:
      engine.setAlign(focusId, attr.align - {AlignMiddle} + horizontalAligns)
    else:
      engine.setAlign(focusId, attr.align - horizontalAligns)
    markLayoutDirty()

  proc onVerticalStretch(checked: bool) =
    # Same center-clearing caveat as the horizontal stretch handler above: enabling vertical stretch must drop the AlignMiddle bit first, since AlignMiddle takes priority over the opposing anchor pair and a node carrying both would stay centered.
    if checked:
      engine.setAlign(focusId, attr.align - {AlignMiddle} + verticalAligns)
    else:
      engine.setAlign(focusId, attr.align - verticalAligns)
    markLayoutDirty()

  buildHtml:
    tdiv(class = "anchor-row"):
      cellGrid(selected, onToggle = onToggleCell)
      tdiv(class = "axis-stretch"):
        toggleControl(stretchedHorizontally, caption = "Horizontal",
          icon = stretchGlyph(true), onToggled = onHorizontalStretch)
        toggleControl(stretchedVertically, caption = "Vertical",
          icon = stretchGlyph(false), onToggled = onVerticalStretch)

proc chooseMainAxisAlign(attr: NodeAttr): VNode =
  proc onChanged(value: MainAxisAlign) =
    engine.setMainAxisAlign(focusId, value)
    markLayoutDirty()

  chooseEnum(
    [MainAxisAlignStart, MainAxisAlignMiddle, MainAxisAlignEnd,
     MainAxisAlignSpaceBetween, MainAxisAlignSpaceAround,
     MainAxisAlignSpaceEvenly],
    attr.mainAxisAlign,
    mainAxisGlyph,
    onChanged)

proc chooseCrossAxisAlign(attr: NodeAttr): VNode =
  proc onChanged(value: CrossAxisAlign) =
    engine.setCrossAxisAlign(focusId, value)
    markLayoutDirty()

  chooseEnum(
    [CrossAxisAlignStart, CrossAxisAlignMiddle, CrossAxisAlignEnd,
     CrossAxisAlignStretch],
    attr.crossAxisAlign,
    crossAxisGlyph,
    onChanged)

proc chooseCrossAxisLineAlign(attr: NodeAttr): VNode =
  proc onChanged(value: CrossAxisLineAlign) =
    engine.setCrossAxisLineAlign(focusId, value)
    markLayoutDirty()

  chooseEnum(
    [CrossAxisLineAlignStart, CrossAxisLineAlignMiddle, CrossAxisLineAlignEnd,
     CrossAxisLineAlignStretch, CrossAxisLineAlignSpaceBetween,
     CrossAxisLineAlignSpaceAround, CrossAxisLineAlignSpaceEvenly],
    attr.crossAxisLineAlign,
    crossLineGlyph,
    onChanged)

proc sizeGapFields(attr: NodeAttr): VNode =
  proc onWidth(value: float32) =
    var size = attr.size
    size[0] = value
    engine.setSize(focusId, size)
    markLayoutDirty()

  proc onHeight(value: float32) =
    var size = attr.size
    size[1] = value
    engine.setSize(focusId, size)
    markLayoutDirty()

  proc onGapX(value: float32) =
    var gap = attr.gap
    gap[0] = value
    engine.setGap(focusId, gap)
    markLayoutDirty()

  proc onGapY(value: float32) =
    var gap = attr.gap
    gap[1] = value
    engine.setGap(focusId, gap)
    markLayoutDirty()

  buildHtml:
    section(class = kstring"field-grid"):
      numberField("W", if attr.size[0] > 0: formatNumber(attr.size[0]) else: "",
        "auto", onWidth)
      numberField("H", if attr.size[1] > 0: formatNumber(attr.size[1]) else: "",
        "auto", onHeight)
      numberField("X", formatNumber(attr.gap[0]), "0", onGapX)
      numberField("Y", formatNumber(attr.gap[1]), "0", onGapY)

proc insetFields(
    values: array[4, float32],
    applyValue: proc(idx: int32, value: float32),
): VNode =
  ## Side-by-side [L T R B] cells (edge order matches the internal array).
  buildHtml:
    section(class = kstring"field-grid"):
      numberField("L", formatNumber(values[0]), "0", proc(
          value: float32) = applyValue(0, value))
      numberField("T", formatNumber(values[1]), "0", proc(
          value: float32) = applyValue(1, value))
      numberField("R", formatNumber(values[2]), "0", proc(
          value: float32) = applyValue(2, value))
      numberField("B", formatNumber(values[3]), "0", proc(
          value: float32) = applyValue(3, value))


proc downloadJsonData(json: cstring, fileName: cstring) =
  ## Browser download of `json` as `fileName` via a `data:` URI (avoids Blob/URL.createObjectURL, which have no kdom binding, and JS string injection).
  when defined(js):
    let
      anchorElement = document.createElement("a".cstring)
      href = "data:application/json;charset=utf-8," & $(encodeURIComponent(json))
    anchorElement.setAttribute("href".cstring, href.cstring)
    anchorElement.setAttribute("download".cstring, fileName)
    document.body.appendChild(anchorElement)
    anchorElement.click()
    document.body.removeChild(anchorElement)


proc resetTreeFromJson(data: string): NodeID =
  sourceFileName = "imported.json"
  engine.clear()
  collapsed.setLen(0)
  let newRoot = engine.loadJson(data)
  rootId = newRoot
  focusId = newRoot
  selected = @[newRoot]
  anchorId = newRoot
  result = newRoot

proc importJsonInteractive(data: cstring) {.exportc: "importJsonStringAndFitView".} =
  discard resetTreeFromJson($data)
  fitView()

proc importJsonHeadless(data: cstring): cstring {.exportc: "importJsonString".} =
  ## Loads a layout from a JSON string directly (headless dump driver), mirroring the interactive reset and enabling Html5. Two differences, both because nothing here is viewed: (1) zoom pinned at 1 - it is a pure precision tax (lengths written as `value*zoom` rounded to 0.01px, browser snaps to its 1/64px grid, and getHtml5Rect divides back out by ~1/zoom. At zoom 1 the error is ~0.013, invisible). (2) synchronous redraw via `redrawSync`, since plain `redraw()` only queues a rAF and would leave stale rects for dumpResultString. Returns the new root id as a string.
  let newRoot = resetTreeFromJson($data)
  enabledModes.incl(Html5)
  # compute inlined here (fitView's fitted zoom is not wanted on this path)
  engine.compute(newRoot)
  layoutDirty = false
  zoomScale = float32(1)
  viewOffsetX = 0
  viewOffsetY = 0
  redrawSync()
  result = cstring($(cast[int32](newRoot)))

proc importJson() =
  when defined(js):
    {.emit: """
    (function(){
      var input = document.createElement('input');
      input.type = 'file';
      input.accept = 'application/json';
      input.style.display = 'none';
      input.addEventListener('change', function(event){
        if (input.files.length > 0) {
          var reader = new FileReader();
          reader.onload = function(){ importJsonStringAndFitView(reader.result); };
          reader.readAsText(input.files[0]);
        }
        document.body.removeChild(input);
      });
      document.body.appendChild(input);
      input.click();
    })();
    """.}

proc exportJson() =
  let json = engine.dumpJson(rootId)
  downloadJsonData(json.cstring, "buju.json".cstring)

proc dumpResultString(): cstring {.exportc: "dumpResultString".} =
  ## Build the comparison JSON (Buju geometry + live HTML5 rect, in layout units) as a string for the headless dump driver to read via `page.evaluate`. Returns `cstring` (raw JS string), not `string`: a Nim string in JS is an internal object Playwright would deserialize as char codes. The HTML5 numbers come from the *live* DOM (`getBoundingClientRect`), so the Html5 view must be rendered. Format: `[ { "id": N, "computed": [ [buju x,y,w,h], [html x,y,w,h] ] }, ... ]`.
  let htmlLive = (Html5 in enabledModes)

  var
    rootLeft = float32(0)
    rootTop = float32(0)
    rootWidth = float32(1)
    rootHeight = float32(1)

  if htmlLive:
    let rootElement = document.querySelector((".viewer-html5 [name=" & $rootId & "]").cstring)
    if not (rootElement == nil):
      let rootRect = rootElement.getBoundingClientRect()
      rootLeft = float32(rootRect.left)
      rootTop = float32(rootRect.top)
      rootWidth = float32(rootRect.width)
      rootHeight = float32(rootRect.height)

  let
    rootWorld = engine.computed(rootId)
    nodes = getSubtreeNodes(rootId, pruneCollapsed = true)

  var entries: seq[CompareEntry]
  for n in nodes:
    let
      buju = engine.computed(n)
      html = getHtml5Rect(n, rootLeft, rootTop, rootWidth, rootHeight, rootWorld)

    entries.add(CompareEntry(
      id: cast[int32](n),
      computed: [buju, html],
    ))

  result = pretty(%*(entries)).cstring


proc onAddNode(event: Event; n: VNode) =
  engine.insertChild(focusId, createNode(defaultNodeAttr))
  markLayoutDirty()

proc onRemoveNode(event: Event; n: VNode) =
  removeNode(focusId)

proc onRemoveSiblings(event: Event; n: VNode) =
  removeNextSiblings(focusId)


proc renderToolbar(): VNode =
  proc onImport(event: Event; n: VNode) = importJson()
  proc onExport(event: Event; n: VNode) = exportJson()
  proc onToggleBuju(checked: bool) =
    if checked: enabledModes.incl(Buju) else: enabledModes.excl(Buju)
  proc onToggleHtml5(checked: bool) =
    if checked: enabledModes.incl(Html5) else: enabledModes.excl(Html5)
  let geometry = engine.computed(focusId)
  let
    importButton = buttonControl("import", onImport)
    exportButton = buttonControl("export", onExport)
    addButton = buttonControl("+ node", onAddNode)
    removeButton = buttonControl("- node", onRemoveNode)
    siblingsButton = buttonControl("> siblings", onRemoveSiblings)
  buildHtml:
    section(class = "toolbar"):
      importButton
      exportButton
      span(class = "separator")
      addButton
      removeButton
      siblingsButton
      span(class = "separator")
      toggleControl(Buju in enabledModes, caption = "Buju",
        onToggled = onToggleBuju)
      toggleControl(Html5 in enabledModes, caption = "Html5",
        onToggled = onToggleHtml5)
      span(class = "toolbar-info", style = style((StyleAttr.marginLeft,
          kstring"auto"))):
        keyValueGrid([("X", formatNumber(geometry[0])), ("Y", formatNumber(geometry[1])),
          ("W", formatNumber(geometry[2])), ("H", formatNumber(geometry[3]))])

proc buildTreeNodes(id: NodeID): TreeNode =
  var node = TreeNode(id: $(cast[int32](id)), label: layoutName(getAttr(id)))
  if id notin collapsed:
    for child in engine.children(id):
      node.children.add(buildTreeNodes(child))
  node

proc renderTree(): VNode =
  let rootNode = buildTreeNodes(rootId)
  var expanded = initHashSet[string]()
  for n in getSubtreeNodes(rootId):
    if n notin collapsed:
      expanded.incl($(cast[int32](n)))
  var selectedKeys = initHashSet[string]()
  for s in selected:
    selectedKeys.incl($(cast[int32](s)))
  let focusKey = $(cast[int32](focusId))
  var draggingKeys = initHashSet[string]()
  for nodeId in dragIds:
    draggingKeys.incl($(cast[int32](nodeId)))
  let dropOverKey = if dropTargetId != default(NodeID): $(cast[int32](dropTargetId))
                    else: ""

  proc onNodeExpand(id: string) =
    let nodeId = cast[NodeID](parseInt(id))
    if nodeId in collapsed:
      collapsed.delete(collapsed.find(nodeId))
    else:
      collapsed.add(nodeId)

  proc onNodeSelect(id: string, event: Event) =
    let nodeId = cast[NodeID](parseInt(id))
    if cast[MouseEvent](event).shiftKey:
      selectRange(nodeId)
    elif cast[MouseEvent](event).ctrlKey or cast[MouseEvent](event).metaKey:
      toggleSelect(nodeId)
    else:
      selectOnly(nodeId)

  proc onNodeDragStart(id: string) =
    let nodeId = cast[NodeID](parseInt(id))
    if nodeId notin selected:
      selectOnly(nodeId)
    dragIds = selected.filterIt(it != rootId)

  proc onNodeDragOver(id: string) =
    let nodeId = cast[NodeID](parseInt(id))
    if dragIds.anyIt(canDrop(it, nodeId)):
      if dropTargetId != nodeId:
        dropTargetId = nodeId

  proc onNodeDrop(id: string) =
    let nodeId = cast[NodeID](parseInt(id))
    dropTargetId = default(NodeID)
    reparent(dragIds, nodeId)

  proc onNodeDragLeave(id: string) =
    let nodeId = cast[NodeID](parseInt(id))
    if dropTargetId == nodeId:
      dropTargetId = default(NodeID)

  proc onNodeDragEnd(id: string) =
    dragIds.setLen(0)
    dropTargetId = default(NodeID)

  buildHtml:
    section(class = "tree"):
      span(class = "panel-title"):
        text "Nodes"
      treeView(
        @[rootNode], expanded, selectedKeys, focusKey, draggingKeys,
            dropOverKey,
        onNodeExpand = onNodeExpand,
        onNodeSelect = onNodeSelect,
        onNodeDragStart = onNodeDragStart,
        onNodeDragOver = onNodeDragOver,
        onNodeDrop = onNodeDrop,
        onNodeDragLeave = onNodeDragLeave,
        onNodeDragEnd = onNodeDragEnd)

proc renderInspector(id: NodeID): VNode =
  let
    attr = getAttr(id)
    currentMargin = attr.margin
    currentPadding = attr.padding

  proc onMarginValue(idx: int32, value: float32) =
    var margin = currentMargin
    margin[idx] = value
    engine.setMargin(focusId, margin)
    markLayoutDirty()

  proc onPaddingValue(idx: int32, value: float32) =
    var padding = currentPadding
    padding[idx] = value
    engine.setPadding(focusId, padding)
    markLayoutDirty()

  buildHtml:
    section(class = "inspector"):
      span(class = "panel-title"):
        text "Attributes"

      panel("Size / Gap", @[sizeGapFields(attr)])
      panel("Margin", @[insetFields(currentMargin, onMarginValue)])
      panel("Padding", @[insetFields(currentPadding, onPaddingValue)])
      panel("Layout", @[chooseLayout(attr), chooseWrap(attr)])

      if attr.layout == LayoutFree:
        panel("Anchor", @[chooseAlign(attr)])
      else:
        panel("Main Axis", @[chooseMainAxisAlign(attr)])
        panel("Cross Axis", @[chooseCrossAxisAlign(attr)])
        if attr.wrap == WrapWrap:
          panel("Line Align", @[chooseCrossAxisLineAlign(attr)])
        # A Row/Column node that is itself a child of a layout container
        # positions itself via `align`: cross-axis anchors become align-self,
        # main-axis opposing anchors become flexGrow (stretch). This viewer's
        # HTML5 renderer interprets `align` for flex children the same way, so
        # the Anchor grid drives it. The root has no parent, so its `align` is inert.
        if id != rootId:
          panel("Anchor", @[chooseAlign(attr)])


proc renderViewer(mode: Mode): VNode =
  let
    captionText = if mode == Buju: "Buju" else: "Html5"
    box = computeBoundingBox()
    zoom = zoomScale

  # World box sized to the zoomed boundingBox. drag folded into a translate. No panel
  # measurement needed (it would be 0 before the element first renders).
  let
    worldWidth = box.width * zoom
    worldHeight = box.height * zoom
    worldTransform = "translate(" & $(viewOffsetX) & "px, " & $(viewOffsetY) & "px)"
    worldStyle = style(
      (StyleAttr.width, kstring($(worldWidth) & "px")),
      (StyleAttr.height, kstring($(worldHeight) & "px")),
      (StyleAttr.transform, kstring(worldTransform)),
    )

  let
    zoomPercent = int32(zoom * 100)
    rootComputed = engine.computed(rootId)
    rootPixelWidth = int32(rootComputed[2] * zoom)
    rootPixelHeight = int32(rootComputed[3] * zoom)

  buildHtml:
    section(class = "viewer"):
      section(class = "viewer-title-bar"):
        span(class = "viewer-title-text"):
          text captionText
        span(class = "viewer-title-info"):
          text "zoom " & $(zoomPercent) & "%  |  " & $(rootPixelWidth) &
            "x" & $(rootPixelHeight) & "px"

      section(
        class = "viewer-viewport",
        onmousedown = makeViewportDragHandler(mode),
        onwheel = makeViewportWheelHandler(mode),
      ):
        tdiv(
          class = "viewport-world",
          style = worldStyle,
        ):
          case mode
          of Buju: renderBuju(zoom, box.minX, box.minY)
          of Html5: renderHtml5(zoom, box.minX, box.minY)


proc createDom(): VNode =
  # Recompute only when a geometry change marked the layout stale (pure view transforms leave `layoutDirty` false).
  if layoutDirty:
    engine.compute(rootId)
    layoutDirty = false

  result = buildHtml(tdiv):
    section(class = "app"):
      section(class = "topbar"):
        renderToolbar()

      section(class = "body"):
        section(class = "panel tree-panel"):
          renderTree()

        section(class = "stage"):
          for mode in [Buju, Html5]:
            if mode in enabledModes:
              renderViewer(mode)

          if activeDragMode >= 0:
            renderViewportDragOverlay()

        section(class = "panel inspector-panel"):
          renderInspector(focusId)


rootId = createNode(NodeAttr(layout: LayoutRow, size: [400, 400]))
# The initial tree is never computed by createDom (it only recomputes when layoutDirty is set), so compute it once here.
engine.compute(rootId)
layoutDirty = false
focusId = rootId
selected = @[rootId]
anchorId = rootId

setRenderer createDom
installSpaceFitShortcut(fitView)
