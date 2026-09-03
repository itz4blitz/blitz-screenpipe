import QtQuick
import QtQuick.Controls
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
  property bool demoLock: false
  property string mode: "auto"
  property string org: ""
  property string label: "Screenpipe"
  property string shortLabel: "?"
  property string reason: ""
  property string apiUrl: ""
  property bool agentShare: false
  property string agentLabel: ""
  property string agentNote: ""
  property string hint: ""
  property string dirShort: ""
  property string sizeHuman: ""
  property var orgs: []
  property int hoveredBucket: -1
  property string pickingOrg: ""

  // Popup surface colors (not bar colors) — readable on the card
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

  readonly property string stateWord: {
    if (!root.ready) return "Offline"
    if (root.paused) return "Paused"
    if (root.recording) return "Live"
    return "Idle"
  }

  readonly property string heroMeta: {
    if (!root.ready) return root.hint !== "" ? root.hint : "not configured"
    var bits = []
    if (root.dirShort) bits.push(root.dirShort + (root.sizeHuman ? "  ·  " + root.sizeHuman : ""))
    bits.push(root.mode === "auto" ? "auto" : "pinned")
    return bits.join("  ·  ")
  }

  readonly property color stateColor: {
    if (!root.ready) return root.warnColor
    if (root.paused) return root.faintColor
    if (root.recording) return root.okColor
    return root.dimColor
  }

  function apply(payload) {
    try { var d = JSON.parse(String(payload)) } catch (e) { return }
    ready = d.ready !== false
    paused = d.paused === true
    recording = d.recording === true
    mode = String(d.mode || "auto")
    org = String(d.org || "")
    label = String(d.label || "Screenpipe")
    shortLabel = String(d.short || "?")
    reason = String(d.reason || "")
    apiUrl = String(d.api_url || "")
    agentShare = (d.agent_share === true || d.hermes_share === true)
    var h = d.agent || d.hermes || {}
    agentLabel = String(h.label || "")
    agentNote = String(h.note || "")
    hint = String(d.hint || "")
    dirShort = String(d.dir_short || d.dir || "")
    sizeHuman = String(d.size_human || "")
    orgs = Array.isArray(d.orgs) ? d.orgs : []
    // DEMO mode auto-opens once for README shots. Do NOT bind the panel's
    // `open` to demoLock — KeyboardPanel is a fullscreen overlay, and that
    // OR would make outside-click / Escape unable to dismiss it.
    if (d.demo) {
      if (!demoLock) {
        demoLock = true
        if (!root.opened) root.open()
      }
    } else if (demoLock) {
      demoLock = false
    }
  }

  function refresh() {
    if (!collectProc.running) collectProc.running = true
  }

  function runAction(name) {
    if (actionProc.running) return
    actionProc.command = ["python3", root.collectorPath, "action", name]
    actionProc.running = true
  }

  function pickDir(orgId) {
    if (actionProc.running || !orgId) return
    pickingOrg = orgId
    actionProc.command = ["python3", root.collectorPath, "action", "pick-dir", orgId]
    actionProc.running = true
  }

  function openDir(path) {
    if (!root.bar || !path) return
    root.bar.run("bash -lc 'xdg-open " + JSON.stringify(path) + "'")
  }

  function openRoutes() {
    if (root.bar) root.bar.run("bash -lc 'xdg-open \"$HOME/.config/screenpipe/org-routes.toml\"'")
  }

  function openAgentTargets() {
    if (root.bar) root.bar.run("bash -lc 'xdg-open \"$HOME/.config/screenpipe/agent-targets.json\"'")
  }

  function bucketShares(m) {
    return (m.agent && m.agent.share) || (m.hermes && m.hermes.share) || m.agent_share === true
  }

  function triggerPress(button) {
    if (button === Qt.MiddleButton || button === Qt.RightButton) {
      root.runAction(root.paused ? "resume" : "pause")
      return
    }
    root.toggle()
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

  // ── bar chip ──────────────────────────────────────────────
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
        color: root.recording ? Color.accent : "transparent"
        border.width: root.recording ? 0 : 1.5
        border.color: root.ready
          ? (bar && bar.dimForeground ? bar.dimForeground : Color.muted)
          : Color.urgent
        anchors.verticalCenter: parent.verticalCenter

        SequentialAnimation on opacity {
          running: root.recording
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.28; duration: 1000; easing.type: Easing.InOutSine }
          NumberAnimation { from: 0.28; to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
        }
      }

      Text {
        text: root.shortLabel
        color: root.recording
          ? Color.accent
          : (bar ? bar.barForeground : Color.foreground)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // ── panel ─────────────────────────────────────────────────
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(
      Style.space(56)           // hero
      + Style.space(16) + 1     // gap + hairline
      + Style.space(16) + Style.space(34)  // gap + segment
      + Style.space(16) + Style.space(18) + (root.orgs.length * Style.space(68))  // storage rows
      + Style.space(16) + Style.space(88)  // agent footer
      + Style.space(24),
      Style.space(760)
    )

    Column {
      id: panelBody
      width: parent.width
      spacing: Style.space(16)

      // Hero: monogram + state + pause switch
      Item {
        width: parent.width
        height: Style.space(56)

        // Monogram disc
        Rectangle {
          id: mono
          width: Style.space(48)
          height: width
          radius: width / 2
          color: root.recording
            ? Qt.rgba(root.okColor.r, root.okColor.g, root.okColor.b, 0.18)
            : root.surfaceLift
          border.width: 1
          border.color: root.recording
            ? Qt.rgba(root.okColor.r, root.okColor.g, root.okColor.b, 0.55)
            : root.trackColor
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: root.shortLabel
            color: root.recording ? root.okColor : root.foreground
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

          Row {
            spacing: Style.space(8)
            width: parent.width

            Text {
              text: root.ready ? root.label : "Screenpipe"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: Math.min(implicitWidth, parent.width - statePill.width - Style.space(8))
            }

            Rectangle {
              id: statePill
              anchors.verticalCenter: parent.verticalCenter
              width: stateTxt.implicitWidth + Style.space(12)
              height: Style.space(20)
              radius: height / 2
              color: root.recording
                ? Qt.rgba(root.okColor.r, root.okColor.g, root.okColor.b, 0.18)
                : root.surfaceLift

              Text {
                id: stateTxt
                anchors.centerIn: parent
                text: root.stateWord
                color: root.stateColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.6
              }
            }
          }

          Text {
            width: parent.width
            text: root.heroMeta
            color: root.dimColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
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

      // Hairline
      Rectangle {
        width: parent.width
        height: 1
        color: root.trackColor
      }

      // Mode control — Auto follows window routes; Pinned locks current bucket
      Row {
        width: parent.width
        height: Style.space(36)
        spacing: Style.space(6)

        // Auto
        Rectangle {
          width: (parent.width - parent.spacing) / 2
          height: parent.height
          radius: Style.cornerRadius
          color: root.mode === "auto"
            ? Util.alpha(root.okColor, 0.16)
            : root.surfaceLift
          border.width: 1
          border.color: root.mode === "auto"
            ? Util.alpha(root.okColor, 0.45)
            : root.trackColor

          Column {
            anchors.centerIn: parent
            spacing: Style.space(1)
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Auto"
              color: root.mode === "auto" ? root.okColor : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "follow apps"
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.runAction("clear")
          }
        }

        // Pinned
        Rectangle {
          width: (parent.width - parent.spacing) / 2
          height: parent.height
          radius: Style.cornerRadius
          color: root.mode === "manual"
            ? Util.alpha(root.foreground, 0.12)
            : root.surfaceLift
          border.width: 1
          border.color: root.mode === "manual"
            ? Util.alpha(root.foreground, 0.28)
            : root.trackColor

          Column {
            anchors.centerIn: parent
            spacing: Style.space(1)
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Pinned"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.mode === "manual" ? ("hold " + root.shortLabel) : "lock current"
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              // Pin whatever is showing now (active / desired bucket)
              if (root.org && root.org.length)
                root.runAction(root.org)
            }
          }
        }
      }

      // Storage destinations (buckets)
      Column {
        width: parent.width
        spacing: Style.space(4)

        Text {
          text: "RECORDING STORAGE"
          color: root.faintColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.4
        }

        Repeater {
          model: root.orgs
          delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: parent.width
            height: Style.space(64)
            readonly property bool selected: modelData.selected === true
            readonly property bool live: modelData.recording === true
            readonly property bool hot: root.hoveredBucket === index
            readonly property bool picking: root.pickingOrg === modelData.id

            Rectangle {
              anchors.fill: parent
              radius: Style.cornerRadius
              color: {
                if (row.live) return Qt.rgba(root.okColor.r, root.okColor.g, root.okColor.b, 0.10)
                if (row.selected) return Util.alpha(root.foreground, 0.08)
                if (row.hot) return Util.alpha(root.foreground, 0.05)
                return "transparent"
              }
              border.width: row.selected || row.live ? 1 : 0
              border.color: row.live
                ? Qt.rgba(root.okColor.r, root.okColor.g, root.okColor.b, 0.35)
                : Util.alpha(root.foreground, 0.14)

              Behavior on color { ColorAnimation { duration: 90 } }
            }

            Rectangle {
              visible: row.selected || row.live
              width: Style.space(3)
              height: parent.height - Style.space(14)
              radius: width / 2
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              color: row.live ? root.okColor : root.faintColor
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(18)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(28)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: row.live
                  ? Qt.rgba(root.okColor.r, root.okColor.g, root.okColor.b, 0.20)
                  : root.surfaceLift

                Text {
                  anchors.centerIn: parent
                  text: String(modelData.short || modelData.label || "?").slice(0, 2)
                  color: row.live ? root.okColor : root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              Column {
                width: parent.width - Style.space(28) - Style.space(10) - Style.space(64)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: modelData.label
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - sizeTxt.implicitWidth - Style.space(8))
                  }

                  Text {
                    id: sizeTxt
                    text: String(modelData.size_human || "")
                    color: root.dimColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Text {
                  width: parent.width
                  text: row.picking
                    ? "pick a folder…"
                    : String(modelData.dir_short || modelData.dir || "no folder set")
                  color: row.live ? root.okColor : root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideMiddle
                }
              }

              // Folder button — change storage path
              Rectangle {
                width: Style.space(34)
                height: Style.space(28)
                radius: Style.cornerRadius
                anchors.verticalCenter: parent.verticalCenter
                color: root.surfaceLift
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

              // Radio / live mark
              Item {
                width: Style.space(18)
                height: width
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  anchors.fill: parent
                  radius: width / 2
                  color: "transparent"
                  border.width: 1.5
                  border.color: row.live || row.selected ? root.okColor : root.faintColor

                  Rectangle {
                    visible: row.selected || row.live
                    anchors.centerIn: parent
                    width: parent.width * 0.45
                    height: width
                    radius: width / 2
                    color: row.live ? root.okColor : root.foreground
                  }
                }
              }
            }

              MouseArea {
              anchors.fill: parent
              anchors.rightMargin: Style.space(48)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.hoveredBucket = index
              onExited: if (root.hoveredBucket === index) root.hoveredBucket = -1
              onClicked: root.runAction(modelData.id)
              onPressAndHold: {
                var p = modelData.dir || ""
                if (p) root.openDir(p)
              }
            }
          }
        }
      }

      // Agent footer
      Rectangle {
        width: parent.width
        height: agentInner.implicitHeight + Style.space(20)
        radius: Style.cornerRadius
        color: root.surfaceLift

        Column {
          id: agentInner
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.space(12)
          spacing: Style.space(4)

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              text: "AGENT"
              color: root.faintColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.4
              anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: 1; height: 1 }

            Text {
              visible: root.ready
              text: root.agentShare ? "opt-in" : "off"
              color: root.agentShare ? root.okColor : root.faintColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.agentShare
              ? (root.agentLabel || "Agent") + (root.apiUrl ? "  ·  " + root.apiUrl : "")
              : (root.agentNote || "This bucket never leaves the machine.")
            color: root.dimColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Row {
            spacing: Style.space(14)
            topPadding: Style.space(4)

            Text {
              text: "Routes"
              color: root.okColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openRoutes()
              }
            }

            Text {
              text: "Agent map"
              color: root.okColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openAgentTargets()
              }
            }
          }
        }
      }
    }
  }
}
