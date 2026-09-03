import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "blitz.screenpipe"
  ipcTarget: "blitz.screenpipe"

  property bool ready: false
  property bool paused: true
  property bool recording: false
  property bool inMeeting: false
  property bool notify: false
  property bool demoLock: false
  property bool filing: false
  property string label: "Inbox"
  property string shortLabel: "In"
  property string reason: ""
  property string dirShort: ""
  property string sizeHuman: ""
  property string hint: ""
  property var activeMeeting: null
  property var pending: []
  property var destinations: []
  property int selectedPending: -1
  property int hoveredDest: -1
  property string pickingOrg: ""

  readonly property color foreground: Color.popups.text
  readonly property color dimColor: Util.alpha(foreground, 0.62)
  readonly property color faintColor: Util.alpha(foreground, 0.38)
  readonly property color trackColor: Util.alpha(foreground, 0.12)
  readonly property color okColor: Color.accent
  readonly property color warnColor: Color.urgent
  readonly property color surfaceLift: Util.alpha(foreground, 0.06)
  readonly property string fontFamily: Style.font.family
  readonly property string collectorPath: {
    var url = String(Qt.resolvedUrl("screenpipe_collect.py"))
    return url.startsWith("file://") ? url.substring(7) : url
  }

  readonly property var selectedMeeting: {
    if (root.activeMeeting && root.activeMeeting.open)
      return null // can't file open meetings
    if (root.selectedPending >= 0 && root.selectedPending < root.pending.length)
      return root.pending[root.selectedPending]
    if (root.pending.length > 0) return root.pending[0]
    return null
  }

  readonly property string heroTitle: {
    if (!root.ready) return "Screenpipe"
    if (root.paused) return "Paused"
    if (root.inMeeting && root.activeMeeting)
      return root.activeMeeting.label || root.activeMeeting.app || "On a call"
    if (root.pending.length > 0)
      return root.pending.length + " unfiled"
    return "Inbox"
  }

  readonly property string heroMeta: {
    if (!root.ready) return root.hint || "not ready"
    if (root.inMeeting)
      return (root.activeMeeting && root.activeMeeting.app ? root.activeMeeting.app + "  ·  " : "")
        + "recording to inbox — file when the call ends"
    if (root.pending.length > 0)
      return "pick a destination below"
    return root.dirShort + (root.sizeHuman ? "  ·  " + root.sizeHuman : "")
  }

  function apply(payload) {
    try { var d = JSON.parse(String(payload)) } catch (e) { return }
    ready = d.ready !== false
    paused = d.paused === true
    recording = d.recording === true
    inMeeting = d.in_meeting === true
    notify = d.notify === true
    label = String(d.label || "Inbox")
    shortLabel = String(d.short || "In")
    reason = String(d.reason || "")
    dirShort = String(d.dir_short || "")
    sizeHuman = String(d.size_human || "")
    hint = String(d.hint || "")
    activeMeeting = d.active_meeting || null
    pending = Array.isArray(d.pending) ? d.pending : []
    destinations = Array.isArray(d.destinations) && d.destinations.length
      ? d.destinations
      : (Array.isArray(d.orgs) ? d.orgs : [])
    if (selectedPending >= pending.length)
      selectedPending = pending.length ? 0 : -1
    if (selectedPending < 0 && pending.length)
      selectedPending = 0

    if (d.demo) {
      if (!demoLock) {
        demoLock = true
        if (!root.opened) root.open()
      }
    } else if (demoLock) {
      demoLock = false
    }

    // Call started → open panel once until acked
    if (notify && !root.opened && !d.demo)
      root.open()
  }

  function refresh() {
    if (!collectProc.running) collectProc.running = true
  }

  function runAction() {
    var args = ["python3", root.collectorPath, "action"]
    for (var i = 0; i < arguments.length; i++) args.push(String(arguments[i]))
    if (actionProc.running) return
    actionProc.command = args
    actionProc.running = true
  }

  function fileTo(destId) {
    var m = root.selectedMeeting
    if (!m || !destId || root.filing) return
    root.filing = true
    root.runAction("file", String(m.id), destId)
  }

  function pickDir(destId) {
    if (!destId) return
    pickingOrg = destId
    root.runAction("pick-dir", destId)
  }

  function triggerPress(button) {
    if (button === Qt.MiddleButton || button === Qt.RightButton) {
      root.runAction(root.paused ? "resume" : "pause")
      return
    }
    root.toggle()
    if (root.notify)
      root.runAction("ack")
  }

  onOpenedChanged: {
    if (root.opened && root.notify)
      root.runAction("ack")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: collectProc
    command: ["python3", root.collectorPath]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.apply(text) }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.filing = false
        root.pickingOrg = ""
        root.apply(text)
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    pressable: true
    horizontalMargin: 8
    fixedWidth: chip.implicitWidth + scaledHorizontalMargin * 2
    onPressed: function(b) { root.triggerPress(b) }

    Row {
      id: chip
      anchors.centerIn: parent
      spacing: Style.space(7)

      Rectangle {
        width: Style.space(8)
        height: width
        radius: width / 2
        color: root.inMeeting ? Color.accent
          : (root.pending.length ? root.warnColor : "transparent")
        border.width: (root.inMeeting || root.pending.length) ? 0 : 1.5
        border.color: bar && bar.dimForeground ? bar.dimForeground : Color.muted
        anchors.verticalCenter: parent.verticalCenter

        SequentialAnimation on opacity {
          running: root.inMeeting
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.28; duration: 900; easing.type: Easing.InOutSine }
          NumberAnimation { from: 0.28; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        }
      }

      Text {
        text: root.inMeeting ? "REC"
          : (root.pending.length ? String(root.pending.length) : root.shortLabel)
        color: root.inMeeting ? Color.accent
          : (root.pending.length ? (bar ? bar.urgent : Color.urgent)
            : (bar ? bar.barForeground : Color.foreground))
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(
      Style.space(64)
      + Style.space(20)
      + Style.space(100)
      + Style.space(18)
      + (Math.max(1, root.destinations.length) * Style.space(56))
      + Style.space(40),
      Style.space(720)
    )

    Column {
      width: parent.width
      spacing: Style.space(14)

      // Hero
      Item {
        width: parent.width
        height: Style.space(56)

        Rectangle {
          id: mono
          width: Style.space(48)
          height: width
          radius: width / 2
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          color: root.inMeeting
            ? Qt.rgba(root.okColor.r, root.okColor.g, root.okColor.b, 0.18)
            : root.surfaceLift
          border.width: 1
          border.color: root.inMeeting
            ? Util.alpha(root.okColor, 0.5)
            : root.trackColor

          Text {
            anchors.centerIn: parent
            text: root.inMeeting ? "●" : (root.pending.length ? String(root.pending.length) : "⌁")
            color: root.inMeeting ? root.okColor : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
        }

        Column {
          anchors.left: mono.right
          anchors.leftMargin: Style.space(14)
          anchors.right: pauseSwitch.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Text {
            width: parent.width
            text: root.heroTitle
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: root.heroMeta
            color: root.dimColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
          }
        }

        ToggleSwitch {
          id: pauseSwitch
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          checked: root.recording && !root.paused
          foreground: root.foreground
          accent: root.okColor
          onToggled: root.runAction(root.recording && !root.paused ? "pause" : "resume")
        }
      }

      Rectangle { width: parent.width; height: 1; color: root.trackColor }

      // Unfiled meetings
      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.pending.length > 0 || root.inMeeting

        Text {
          text: root.inMeeting ? "IN PROGRESS" : "UNFILED"
          color: root.faintColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.4
        }

        Text {
          visible: root.inMeeting
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Stays in the inbox until the call ends. Then pick a destination to file it."
          color: root.dimColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: root.pending
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: parent.width
            height: Style.space(44)
            radius: Style.cornerRadius
            color: root.selectedPending === index
              ? Util.alpha(root.foreground, 0.10)
              : root.surfaceLift
            border.width: root.selectedPending === index ? 1 : 0
            border.color: Util.alpha(root.foreground, 0.22)

            Column {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(12)
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: modelData.label
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: modelData.app
                  + (modelData.suggest_label ? "  ·  suggest " + modelData.suggest_label : "")
                color: root.dimColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectedPending = index
            }
          }
        }
      }

      // Destinations — click to file selected unfiled meeting (instant; no recorder restart)
      Column {
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: "FILE TO"
          color: root.faintColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.4
        }

        Text {
          visible: !root.selectedMeeting && !root.inMeeting
          width: parent.width
          text: "Nothing to file. Inbox keeps capturing quietly."
          color: root.dimColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.destinations
          delegate: Item {
            id: dest
            required property var modelData
            required property int index
            width: parent.width
            height: Style.space(52)
            readonly property bool hot: root.hoveredDest === index
            readonly property bool canFile: !!root.selectedMeeting && !root.filing

            Rectangle {
              anchors.fill: parent
              radius: Style.cornerRadius
              color: dest.hot && dest.canFile
                ? Util.alpha(root.okColor, 0.12)
                : root.surfaceLift
              border.width: 1
              border.color: dest.hot && dest.canFile
                ? Util.alpha(root.okColor, 0.4)
                : root.trackColor
            }

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(28)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Util.alpha(root.foreground, 0.08)
                Text {
                  anchors.centerIn: parent
                  text: String(modelData.short || "?").slice(0, 2)
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              Column {
                width: parent.width - Style.space(28) - Style.space(10) - Style.space(40)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)
                Text {
                  width: parent.width
                  text: modelData.label
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  text: (modelData.size_human || "") + "  ·  " + (modelData.dir_short || "")
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideMiddle
                }
              }

              Rectangle {
                width: Style.space(34)
                height: Style.space(28)
                radius: Style.cornerRadius
                anchors.verticalCenter: parent.verticalCenter
                color: Util.alpha(root.foreground, 0.06)
                border.width: 1
                border.color: root.trackColor
                Text {
                  anchors.centerIn: parent
                  text: "Dir"
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.pickDir(modelData.id)
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              anchors.rightMargin: Style.space(44)
              hoverEnabled: true
              enabled: dest.canFile
              cursorShape: dest.canFile ? Qt.PointingHandCursor : Qt.ArrowCursor
              onEntered: root.hoveredDest = index
              onExited: if (root.hoveredDest === index) root.hoveredDest = -1
              onClicked: root.fileTo(modelData.id)
            }
          }
        }
      }

      Text {
        width: parent.width
        visible: root.filing
        text: "Exporting into that folder…"
        color: root.okColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
