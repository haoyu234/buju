type
  Align* = enum
    AlignLeft = 0x01
    AlignTop = 0x02
    AlignRight = 0x04
    AlignBottom = 0x08

  MainAxisAlign* = enum
    MainAxisAlignMiddle = 0x00
    MainAxisAlignStart = 0x01
    MainAxisAlignEnd = 0x02
    MainAxisAlignSpaceBetween = 0x03
    MainAxisAlignSpaceAround = 0x05
    MainAxisAlignSpaceEvenly = 0x07

  CrossAxisAlign* = enum
    CrossAxisAlignMiddle = 0x00
    CrossAxisAlignStart = 0x01
    CrossAxisAlignEnd = 0x04
    CrossAxisAlignStretch = 0x05

  Layout* = enum
    LayoutFree = 0x00
    LayoutRow = 0x01
    LayoutColumn = 0x02

  Wrap* = enum
    WrapNoWrap = 0x00
    WrapWrap = 0x01
