import QtQuick
import qs.Commons
import qs.Commons as Commons

// Right-hand detail for the selected row: label, swatch, text or image, hint.
Item {
  id: root
  property var row: ({})
  // smr: [{ label, keys: ["Super", "F"] }] for binds that do what the row does.
  property var shortcuts: []
  property bool compact: true
  property color accent: Commons.Color.accent
  property color foreground: Commons.Color.menu.text
  readonly property bool clipboard: (row.previewLabel || "") === "CLIPBOARD" || (row.previewLabel || "") === "DICTATION"
  readonly property bool emoji: row.emoji === true
  readonly property string imagePath: String(row.previewImage || "")
  readonly property bool image: imagePath !== ""
  readonly property bool vector: /\.svgz?$/i.test(imagePath)
  // smr: the pane now opens for every row while typing; a row with nothing
  // of its own to preview gets its icon, name and subtitle instead.
  readonly property bool hasContent: !!(row.preview || row.previewImage || row.swatch)
  // Where the pane's content must stop: the shortcut block if any, else the hint.
  readonly property real bottomY: keysBox.visible ? keysBox.y : hint.y
  readonly property real dpr: Screen.devicePixelRatio
  // With an image underneath, the caption keeps to a few lines so the picture
  // gets the room; only at the smallest size may it take a share of the pane,
  // so a long path is never cut short of its file name.
  readonly property int captionLines: 3
  readonly property real captionShare: 0.4
  readonly property var captionScale: compact ? [Style.font.display, Style.font.heading, Style.font.title, Style.font.body]
                                              : [Style.font.displayLarge, Style.font.display, Style.font.heading, Style.font.title, Style.font.body]

  // Monospace glyph and line extents per pixel of font size.
  FontMetrics { id: mono; font.family: "monospace"; font.pixelSize: 100 }
  readonly property real glyphRatio: mono.averageCharacterWidth / 100
  readonly property real lineRatio: mono.lineSpacing / 100

  // Room the caption may take at `px` above an image, in pixels. Half a line
  // of slack keeps a caption that just fits from eliding on rounding.
  function captionBudget(px, height) {
    var lines = (root.captionLines + 0.5) * px * root.lineRatio
    return px === root.captionScale[root.captionScale.length - 1] ? Math.max(lines, height * root.captionShare) : lines
  }

  // Largest size in the scale whose wrapped caption still fits its room.
  function captionSize(text, width, height) {
    var chars = String(text || "").length
    for (var i = 0; i < root.captionScale.length; i++) {
      var px = root.captionScale[i]
      var perLine = Math.max(1, Math.floor(width / (px * root.glyphRatio)))
      var lines = Math.ceil(chars / perLine)
      var room = root.image ? root.captionBudget(px, height) : height
      if (lines * px * root.lineRatio <= room) return px
    }
    return root.captionScale[root.captionScale.length - 1]
  }

  // Scale that fits a native size into a box without enlarging it; a vector
  // with no useful native size may grow until its long side reaches `floor`.
  function fitScale(w, h, boxW, boxH, floor) {
    if (!(w > 0) || !(h > 0) || !(boxW > 0) || !(boxH > 0)) return 0
    var s = Math.min(1, boxW / w, boxH / h)
    if (floor > 0 && Math.max(w, h) * s < floor) s = Math.min(boxW / w, boxH / h, floor / Math.max(w, h))
    return s
  }

  Text {
    id: label
    visible: root.hasContent
    x: 0; y: Style.space(10)
    text: root.row.previewLabel || "PREVIEW"
    textFormat: Text.PlainText
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 2
    color: Util.alpha(root.foreground, 0.5)
  }
  Rectangle {
    id: swatch
    y: Style.space(44); width: parent.width; height: Style.space(96)
    radius: Style.cornerRadius
    visible: !!root.row.swatch
    color: root.row.swatch || "transparent"
    border.width: 1
    border.color: Util.alpha(root.foreground, 0.15)
  }
  Text {
    id: caption
    y: root.row.swatch ? swatch.y + swatch.height + Style.space(18) : Style.space(46)
    width: parent.width
    readonly property int room: root.bottomY - y - Style.space(14)
    height: root.image ? Math.min(implicitHeight, root.captionBudget(font.pixelSize, room)) : room
    visible: !!root.row.preview
    text: root.row.preview || ""
    textFormat: Text.PlainText
    color: root.clipboard ? Util.alpha(root.foreground, 0.85) : root.accent
    font.family: root.emoji ? "Noto Color Emoji" : (root.clipboard ? Style.font.menuFamily : "monospace")
    font.pixelSize: root.emoji ? Style.space(72) : (root.clipboard ? Style.font.body : root.captionSize(text, width, room))
    wrapMode: Text.WrapAnywhere
    elide: Text.ElideRight
  }
  // Reads a vector's declared size; rasters report theirs through `picture`.
  Image {
    id: probe
    visible: false
    source: root.vector ? Util.fileUrl(root.imagePath) : ""
    asynchronous: true
  }
  Image {
    id: picture
    readonly property real above: caption.visible ? caption.y + caption.height + Style.space(14) : Style.space(46)
    readonly property real boxWidth: root.width
    readonly property real boxHeight: root.bottomY - above - Style.space(14)
    readonly property real nativeWidth: root.vector ? probe.implicitWidth : implicitWidth
    readonly property real nativeHeight: root.vector ? probe.implicitHeight : implicitHeight
    readonly property real fit: root.fitScale(nativeWidth, nativeHeight, boxWidth, boxHeight, root.vector ? Style.space(120) : 0)
    x: 0; y: above
    width: Math.round(nativeWidth * fit)
    height: Math.round(nativeHeight * fit)
    visible: root.image && fit > 0
    source: root.image ? Util.fileUrl(root.imagePath) : ""
    // Stretch, not PreserveAspectFit: the item already has the source's
    // aspect, and the fit mode makes Qt enlarge a small raster to sourceSize.
    // A plain sourceSize only ever scales a raster down, so it decodes no
    // larger than the pane; a vector rasterises at exactly its drawn size.
    fillMode: Image.Stretch
    sourceSize.width: root.vector ? width * root.dpr : root.width * root.dpr
    sourceSize.height: root.vector ? height * root.dpr : root.height * root.dpr
    asynchronous: true
    smooth: true
  }
  Column {
    id: identity
    visible: !root.hasContent && !!root.row.title
    width: parent.width
    y: Math.max(Style.space(30), Math.round((root.bottomY - height) * 0.42))
    spacing: Style.space(10)
    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Style.space(64); height: width
      Image {
        id: bigIcon
        anchors.fill: parent
        visible: !!root.row.iconSource && status === Image.Ready
        source: root.row.iconSource || ""
        sourceSize.width: width * root.dpr; sourceSize.height: height * root.dpr
        fillMode: Image.PreserveAspectFit
        asynchronous: true; smooth: true
      }
      Text {
        anchors.centerIn: parent
        visible: !bigIcon.visible
        text: root.row.icon || "󰘔"
        textFormat: Text.PlainText
        color: root.accent
        font.family: root.row.iconFont || Style.font.menuFamily
        font.pixelSize: Style.space(46)
      }
    }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.row.title || ""
      textFormat: Text.PlainText
      color: root.foreground
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.title
      font.weight: Font.DemiBold
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      visible: !!root.row.subtitle
      horizontalAlignment: Text.AlignHCenter
      text: root.row.subtitle || ""
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.6)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WrapAnywhere
      maximumLineCount: 3
      elide: Text.ElideMiddle
    }
  }
  // smr: the keys that do the same thing, so the palette teaches them.
  Column {
    id: keysBox
    visible: root.shortcuts.length > 0
    width: parent.width
    anchors.bottom: hint.top
    anchors.bottomMargin: Style.space(16)
    spacing: Style.space(8)
    Text {
      text: "SHORTCUT"
      textFormat: Text.PlainText
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 2
      color: Util.alpha(root.foreground, 0.5)
    }
    Repeater {
      model: root.shortcuts
      Row {
        required property var modelData
        spacing: Style.space(4)
        Repeater {
          model: modelData.keys
          Keycap { required property var modelData; label: modelData; bright: true; foreground: root.foreground }
        }
        Text {
          // Name the bind only when it isn't simply this row under another name.
          visible: String(modelData.label || "").toLowerCase() !== String(root.row.title || "").toLowerCase()
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: Style.space(6)
          text: modelData.label || ""
          textFormat: Text.PlainText
          color: Util.alpha(root.foreground, 0.55)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          width: Math.min(implicitWidth, root.width - x)
        }
      }
    }
  }
  // The detail line, with the row's badge (an extension's "extension" or
  // "local") beside its last line: provenance lives here, not on the row.
  Item {
    id: hint
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(16)
    width: parent.width
    height: Math.max(detail.height, badge.visible ? badge.height : 0)
    FontMetrics { id: detailMetrics; font: detail.font }
    Text {
      id: detail
      anchors.bottom: parent.bottom
      width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + Style.space(8) : 0))
      text: root.row.previewDetail || (root.row.verb ? "Press return to " + String(root.row.verb).toLowerCase() : "")
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.55)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
      maximumLineCount: 3
      elide: Text.ElideRight
    }
    Rectangle {
      id: badge
      visible: !!root.row.badge
      anchors.left: detail.right
      anchors.leftMargin: detail.text ? Style.space(8) : 0
      anchors.bottom: detail.bottom
      anchors.bottomMargin: Math.round((detailMetrics.height - height) / 2)
      width: badgeLabel.implicitWidth + Style.space(8)
      height: badgeLabel.implicitHeight + Style.space(3)
      radius: height / 2
      color: Util.alpha(root.foreground, 0.08)
      border.width: 1
      border.color: Util.alpha(root.foreground, 0.14)
      Text { id: badgeLabel; anchors.centerIn: parent; text: root.row.badge || ""; textFormat: Text.PlainText; color: Util.alpha(root.foreground, 0.7); font.family: Style.font.menuFamily; font.pixelSize: Style.font.caption - 1 }
    }
  }
}
