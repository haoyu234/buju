import buju
import buju/core
import buju/dumps

import std/tables
import std/sugar
import std/strutils
import std/jsffi

import karax/[kbase, karax, karaxdsl, vdom, jstrutils, kdom, vstyles]

type
  NodeAttr = object
    wrap: Wrap
    layout: Layout
    mainAxisAlign: MainAxisAlign
    crossAxisAlign: CrossAxisAlign
    crossAxisLineAlign: CrossAxisLineAlign
    align: set[Align]
    size: array[2, float32]
    margin: array[4, float32]

  Mode = enum
    Buju
    Html5

var
  l = Context()
  modes = {Buju}
  rootId = default(NodeID)
  focusId = default(NodeID)
  mapping = initTable[NodeID, NodeID]()
  scale = 1
  defaultAttr = NodeAttr(size: [50, 50], margin: [5, 5, 5, 5])

proc download(data: cstring, mime: cstring, name: cstring) =
  when defined(js):
    {.
      emit:
        """
      let blob = new Blob([`data`], { `mime` });
      let downloadElement = document.createElement("a");
      let href = window.URL.createObjectURL(blob);
      downloadElement.href = href;
      downloadElement.download = `name`;
      document.body.appendChild(downloadElement);
      downloadElement.click();
      document.body.removeChild(downloadElement);
      window.URL.revokeObjectURL(href);
    """
    .}

proc upload(cb: proc(data: cstring)) =
  when defined(js):
    {.
      emit:
        """
      let inputElement = document.createElement("input");
      inputElement.type = "file";
      inputElement.style.display = "none";
      inputElement.accept = "application/json";
      inputElement.single = true;
      inputElement.onchange = function () {
        const file = inputElement.files[0];
        if (file) {
          const reader = new FileReader();
          reader.readAsText(file);
          reader.onload = () => {
            `cb`(reader.result);
          };
        }
      };

      document.body.appendChild(inputElement);
      inputElement.click();
      document.body.removeChild(inputElement);
    """
    .}

proc exportJson() =
  let json = l.dumpJson(rootId)
  download(json.cstring, "application/json".cstring, "buju.json".cstring)

proc importJson() =
  proc updateMapping(id: NodeID) =
    for n in l.children(id):
      mapping[n] = id
      updateMapping(n)

  upload:
    proc(data: cstring) =
      l.clear()
      rootId = l.loadJson($data)
      focusId = rootId
      updateMapping(rootId)
      redraw()

proc getAttr(id: NodeID): NodeAttr =
  let n = node(l.addr, id)

  if n.isNil:
    return

  result.wrap = n.wrap
  result.layout = n.layout
  result.mainAxisAlign = n.mainAxisAlign
  result.crossAxisAlign = n.crossAxisAlign
  result.crossAxisLineAlign = n.crossAxisLineAlign
  result.align = n.align
  result.size = n.size
  result.margin = n.margin

proc insertChild(parentID, childID: NodeID) =
  l.insertChild(parentID, childID)
  mapping[childID] = parentID

proc removeNode(childID: NodeID) =
  mapping.withValue(childID, parentID):
    if focusId == childID:
      focusId = l.nextSibling(childID)
      if focusId.isNil:
        focusId = parentID[]
    l.removeChild(parentID[], childID)
    mapping.del(childID)

proc removeNextSiblings(childID: NodeID) =
  mapping.withValue(childID, parentID):
    if focusId == childID:
      var next = l.nextSibling(childID)
      while not next.isNil:
        let n = l.nextSibling(next)
        l.removeChild(parentID[], next)
        next = n

      focusId = parentID[]

    l.removeChild(parentID[], childID)
    mapping.del(childID)

proc updateAttr(n: NodeID, attr: NodeAttr) =
  l.setWrap(n, attr.wrap)
  l.setLayout(n, attr.layout)
  l.setMainAxisAlign(n, attr.mainAxisAlign)
  l.setCrossAxisAlign(n, attr.crossAxisAlign)
  l.setCrossAxisLineAlign(n, attr.crossAxisLineAlign)
  l.setAlign(n, attr.align)
  l.setSize(n, attr.size)
  l.setMargin(n, attr.margin)

proc toPixelSize(v: float32): kstring =
  kstring($(float32(scale) * v) & "px")

proc trim(s: string, T: typedesc): string =
  s.replace($T, "")

proc createNode(attr: NodeAttr): NodeID =
  result = l.node()
  updateAttr(result, attr)

iterator nodes(id: NodeID): NodeID =
  var nodes = newSeqOfCap[NodeID](l.len)
  nodes.add(id)

  var idx = 0

  while idx < nodes.len:
    yield nodes[idx]

    let n2 = nodes[idx]
    for n in l.children(n2):
      nodes.add(n)

    inc idx, 1

proc viewerBuju(): VNode =
  proc toClass(n: NodeID): string =
    if n == focusId: "node focus" else: "node"

  proc toStyle(xywh: array[4, float32], zIndex: int32): VStyle =
    style(
      (StyleAttr.left, toPixelSize(xywh[0])),
      (StyleAttr.top, toPixelSize(xywh[1])),
      (StyleAttr.width, toPixelSize(xywh[2])),
      (StyleAttr.height, toPixelSize(xywh[3])),
      (StyleAttr.position, kstring("absolute")),
      (StyleAttr.zIndex, kstring($zIndex)),
    )

  let xywh = l.computed(rootId)

  buildHtml:
    section(
      style = style(
        [
          (StyleAttr.position, kstring("relative")),
          (StyleAttr.width, toPixelSize(xywh[2])),
          (StyleAttr.height, toPixelSize(xywh[3])),
        ]
      )
    ):
      for n in nodes(rootId):
        let onClick = capture n:
          proc(e: Event, vn: VNode) =
            focusId = n
            e.stopPropagation()

        let xywh = l.computed(n)
        tdiv(
          class = kstring(toClass(n)),
          style = toStyle(xywh, int32(n)),
          onClick = onClick,
        ):
          tdiv(class = "label"):
            text $cast[int32](n)

proc viewerH5(): VNode =
  proc toClass(n: NodeID): string =
    if n == focusId: "node focus" else: "node"

  proc toStyle(
      attr: NodeAttr, parentAttr: NodeAttr, xywh: array[4, float32], zIndex: int32
  ): VStyle =
    result = style(
      (StyleAttr.marginLeft, toPixelSize(attr.margin[0])),
      (StyleAttr.marginTop, toPixelSize(attr.margin[1])),
      (StyleAttr.marginRight, toPixelSize(attr.margin[2])),
      (StyleAttr.marginBottom, toPixelSize(attr.margin[3])),
      (StyleAttr.position, kstring("relative")),
      (StyleAttr.flexShrink, kstring("0")),
      (StyleAttr.zIndex, kstring($zIndex)),
    )

    if attr.size[0] > 0:
      result.setAttr(StyleAttr.width, toPixelSize(attr.size[0]))

    if attr.size[1] > 0:
      result.setAttr(StyleAttr.height, toPixelSize(attr.size[1]))

    case attr.layout
    of LayoutRow:
      result.setAttr(StyleAttr.display, "flex")
      result.setAttr(StyleAttr.flexDirection, "row")
    of LayoutColumn:
      result.setAttr(StyleAttr.display, "flex")
      result.setAttr(StyleAttr.flexDirection, "column")
    of LayoutFree:
      discard

    case attr.wrap
    of WrapWrap:
      result.setAttr(StyleAttr.flexWrap, "wrap")
    of WrapNoWrap:
      result.setAttr(StyleAttr.flexWrap, "nowrap")

    case attr.mainAxisAlign
    of MainAxisAlignMiddle:
      result.setAttr(StyleAttr.justifyContent, "center")
    of MainAxisAlignStart:
      result.setAttr(StyleAttr.justifyContent, "flex-start")
    of MainAxisAlignEnd:
      result.setAttr(StyleAttr.justifyContent, "flex-end")
    of MainAxisAlignSpaceBetween:
      result.setAttr(StyleAttr.justifyContent, "space-between")
    of MainAxisAlignSpaceAround:
      result.setAttr(StyleAttr.justifyContent, "space-around")
    of MainAxisAlignSpaceEvenly:
      result.setAttr(StyleAttr.justifyContent, "space-evenly")

    case attr.crossAxisLineAlign
    of CrossAxisLineAlignMiddle:
      result.setAttr(StyleAttr.alignContent, "center")
    of CrossAxisLineAlignStart:
      result.setAttr(StyleAttr.alignContent, "flex-start")
    of CrossAxisLineAlignEnd:
      result.setAttr(StyleAttr.alignContent, "flex-end")
    of CrossAxisLineAlignStretch:
      result.setAttr(StyleAttr.alignContent, "stretch")
    of CrossAxisLineAlignSpaceBetween:
      result.setAttr(StyleAttr.alignContent, "space-between")
    of CrossAxisLineAlignSpaceAround:
      result.setAttr(StyleAttr.alignContent, "space-around")
    of CrossAxisLineAlignSpaceEvenly:
      result.setAttr(StyleAttr.alignContent, "space-evenly")

    case attr.crossAxisAlign
    of CrossAxisAlignMiddle:
      result.setAttr(StyleAttr.alignItems, "center")
    of CrossAxisAlignStart:
      result.setAttr(StyleAttr.alignItems, "flex-start")
    of CrossAxisAlignEnd:
      result.setAttr(StyleAttr.alignItems, "flex-end")
    of CrossAxisAlignStretch:
      result.setAttr(StyleAttr.alignItems, "stretch")

    proc toCssAlign(a: Align): kstring =
      case a
      of AlignLeft, AlignTop: kstring("flex-start")
      of AlignRight, AlignBottom: kstring("flex-end")

    const
      V = {AlignTop, AlignBottom}
      H = {AlignLeft, AlignRight}

    case parentAttr.layout
    of LayoutRow:
      let align = attr.align * V
      if len(align) == len(V):
        result.setAttr(StyleAttr.alignSelf, "stretch")
      else:
        for a in [AlignTop, AlignBottom]:
          if a in align:
            result.setAttr(StyleAttr.alignSelf, a.toCssAlign)
            break

      if attr.align * H == H:
        result.setAttr(StyleAttr.flexGrow, "1")
    of LayoutColumn:
      let align = attr.align * H
      if len(align) == len(H):
        result.setAttr(StyleAttr.alignSelf, "stretch")
      else:
        for a in [AlignLeft, AlignRight]:
          if a in align:
            result.setAttr(StyleAttr.alignSelf, a.toCssAlign)
            break

      if attr.align * V == V:
        result.setAttr(StyleAttr.flexGrow, "1")
    of LayoutFree:
      discard

  proc createNode(n: NodeID, parentAttr: NodeAttr): VNode =
    let xywh = l.computed(n)

    let onClick = capture n:
      proc(e: Event, vn: VNode) =
        focusId = n
        e.stopPropagation()

    buildHtml:
      let attr = getAttr(n)
      tdiv(
        class = kstring(toClass(n)),
        style = toStyle(attr, parentAttr, xywh, int32(n)),
        onClick = onClick,
      ):
        tdiv(class = "label"):
          text $cast[int32](n)

        for child in l.children(n):
          createNode(child, attr)

  buildHtml:
    section(style = style([(StyleAttr.display, kstring("flex"))])):
      createNode(rootId, NodeAttr())

proc numberEntry[T](name: string, val: T, onChanged: proc(v: T)): VNode =
  proc onEnter(e: Event, vn: VNode) =
    when T is SomeFloat:
      onChanged(T(parseFloat(vn.value)))
    elif T is SomeInteger:
      onChanged(T(parseInt(vn.value)))

  buildHtml:
    li:
      label:
        text name
        input(
          id = name,
          `type` = "number",
          value = kstring($val),
          style = style(
            [(StyleAttr.width, kstring("5em")), (StyleAttr.marginLeft, kstring("1em"))]
          ),
          onblur = onEnter,
        )

proc radioGroup[T](
    name: string, val: T, values: openArray[T], onClick: proc(v: T)
): VNode =
  buildHtml:
    tdiv:
      for v in values:
        let onClick = capture v:
          proc() =
            onClick(v)

        li:
          label:
            input(`type` = "radio", name = name, checked = v == val,
                onClick = onClick)
            text trim($v, T)

proc checkboxGroup[T](
    name: string, val: set[T], values: openArray[T], onClick: proc(v: T)
): VNode =
  buildHtml:
    tdiv:
      for v in values:
        let onClick = capture v:
          proc() =
            onClick(v)

        li:
          label:
            input(
              `type` = "checkbox", name = name, checked = v in val,
              onClick = onClick
            )
            text trim($v, T)

proc setLayout(attr: NodeAttr): VNode =
  buildHtml:
    section(class = "group"):
      span(class = "title"):
        text "Layout"

      radioGroup(
        "Layout",
        attr.layout,
        collect do:
        for layout in Layout:
          layout,
        proc(layout: Layout) =
        l.setLayout(focusId, layout),
      )

      label:
        input(`type` = "checkbox", name = "Wrap", checked = attr.wrap == WrapWrap):
          proc onclick() =
            l.setWrap(
              focusId,
              case attr.wrap
              of WrapWrap: WrapNoWrap
              of WrapNoWrap: WrapWrap
              ,
            )

        text "Wrap"

proc setAlign(attr: NodeAttr): VNode =
  buildHtml:
    section(class = "group"):
      span(class = "title"):
        text "Align"

      checkboxGroup(
        "Align",
        attr.align,
        [AlignLeft, AlignTop, AlignRight, AlignBottom],
        proc(align: Align) =
          if align in attr.align:
            l.setAlign(focusId, attr.align - {align})
          else:
            l.setAlign(focusId, attr.align + {align}),
      )

proc setMainAxisAlign(attr: NodeAttr): VNode =
  buildHtml:
    section(class = "group"):
      span(class = "title"):
        text "MainAxisAlign"

      radioGroup(
        "MainAxisAlign",
        attr.mainAxisAlign,
        [
          MainAxisAlignMiddle, MainAxisAlignStart, MainAxisAlignEnd,
          MainAxisAlignSpaceBetween, MainAxisAlignSpaceAround,
          MainAxisAlignSpaceEvenly,
        ],
        proc(mainAxisAlign: MainAxisAlign) =
          l.setMainAxisAlign(focusId, mainAxisAlign),
      )

proc setCrossAxisAlign(attr: NodeAttr): VNode =
  buildHtml:
    section(class = "group"):
      span(class = "title"):
        text "CrossAxisAlign"

      radioGroup(
        "CrossAxisAlign",
        attr.crossAxisAlign,
        [
          CrossAxisAlignMiddle, CrossAxisAlignStart, CrossAxisAlignEnd,
          CrossAxisAlignStretch,
        ],
        proc(crossAxisAlign: CrossAxisAlign) =
          l.setCrossAxisAlign(focusId, crossAxisAlign),
      )

proc setCrossAxisLineAlign(attr: NodeAttr): VNode =
  buildHtml:
    section(class = "group"):
      span(class = "title"):
        text "CrossAxisLineAlign"

      radioGroup(
        "CrossAxisLineAlign",
        attr.crossAxisLineAlign,
        [
          CrossAxisLineAlignMiddle, CrossAxisLineAlignStart, CrossAxisLineAlignEnd,
          CrossAxisLineAlignStretch, CrossAxisLineAlignSpaceBetween,
          CrossAxisLineAlignSpaceAround, CrossAxisLineAlignSpaceEvenly,
        ],
        proc(crossAxisLineAlign: CrossAxisLineAlign) =
          l.setCrossAxisLineAlign(focusId, crossAxisLineAlign),
      )

proc setSizeMargin(attr: NodeAttr): VNode =
  buildHtml:
    section(class = "group"):
      span(class = "title"):
        text "Size"

      const
        sizeProps = ["Width", "Height"]
        marginProps = ["MarginLeft", "MarginTop", "MarginRight", "MarginBottom"]

      for idx in 0 ..< len(sizeProps):
        let onChanged = capture idx:
          proc(v: float32) =
            var size = attr.size
            size[idx] = v
            l.setSize(focusId, size)

        numberEntry(sizeProps[idx], attr.size[idx], onChanged = onChanged)

      for idx in 0 ..< len(marginProps):
        let onChanged = capture idx:
          proc(v: float32) =
            var margin = attr.margin
            margin[idx] = v
            l.setMargin(focusId, margin)

        numberEntry(marginProps[idx], attr.margin[idx], onChanged = onChanged)

proc buttons(): VNode =
  proc toClass(n: NodeID): string =
    if n == focusId: "tool focus" else: "tool"

  buildHtml:
    section(class = "group"):
      for n in nodes(rootId):
        let onClick = capture n:
          proc() =
            focusId = n

        button(class = kstring(toClass(n)), onclick = onClick):
          text $cast[int32](n)

proc createDom(): VNode =
  l.compute(rootId)

  result = buildHtml(tdiv):
    section(class = "app"):
      section(
        class = "editor", style = style([(StyleAttr.display, kstring(
            "inline-block"))])
      ):
        section(class = "tools"):
          button(class = "tool", onclick = importJson):
            text "importJson"
          button(class = "tool", onclick = exportJson):
            text "exportJson"

          section(
            class = "tools",
            style = style(
              [
                (StyleAttr.display, kstring("inline-block")),
                (StyleAttr.marginLeft, kstring("2em")),
              ]
            ),
          ):
            button(class = "tool"):
              proc onclick() =
                insertChild(focusId, createNode(defaultAttr))

              text "+"

            button(class = "tool"):
              proc onclick() =
                removeNode(focusId)

              text "-"

            button(class = "tool"):
              proc onclick() =
                removeNextSiblings(focusId)

              text ">"

        section(class = "tools"):
          span(class = "title"):
            text "Mode"

          for val in [Buju, Html5]:
            let onClick = capture val:
              proc() =
                if val in modes:
                  modes.excl(val)
                else:
                  modes.incl(val)

            label:
              input(
                `type` = "checkbox",
                name = kstring($val),
                checked = val in modes,
                onclick = onClick,
              )
              text ($val).toLowerAscii

        section(class = "tools"):
          span(class = "title"):
            text "Scale"

          for val in [1, 2, 5, 10, 25]:
            let onClick = capture val:
              proc() =
                scale = val

            let class = if val == scale: "tool focus" else: "tool"

            button(class = kstring(class), onclick = onClick):
              text "x" & $val

        section(class = "options"):
          let attr = getAttr(focusId)
          thead:
            tr:
              th()
              th()
          tbody:
            tr:
              td(colspan = "2"):
                setSizeMargin(attr)
            tr:
              td:
                setLayout(attr)
              td:
                setAlign(attr)

            tr:
              td:
                setMainAxisAlign(attr)
              td:
                setCrossAxisAlign(attr)

            tr:
              td(colspan = "2"):
                setCrossAxisLineAlign(attr)

        section(class = "buttons"):
          buttons()

      for val in [Buju, Html5]:
        if val in modes:
          section(class = "viewer"):
            case val
            of Buju:
              viewerBuju()
            of Html5:
              viewerH5()

rootId = createNode(NodeAttr(layout: LayoutRow, size: [400, 400]))
focusId = rootId

setRenderer createDom
