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
  property var orgs: []

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dimColor: bar && bar.dimForeground ? bar.dimForeground : Color.muted
  readonly property color trackColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.22)
  readonly property color okColor: Color.accent
  readonly property color warnColor: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string collectorPath: {
    var url = String(Qt.resolvedUrl("screenpipe_collect.py"))
    return url.startsWith("file://") ? url.substring(7) : url
  }

  readonly property string statusLine: {
    if (!root.ready) return root.hint !== "" ? root.hint : "unavailable"
    var parts = []
    parts.push(root.paused ? "Paused" : (root.recording ? "Recording" : "Idle"))
    parts.push(root.mode)
    if (root.reason) parts.push(root.reason)
    return parts.join(" · ")
  }

  readonly property string agentSummary: {
    if (!root.ready) return ""
    if (root.agentShare)
      return root.agentLabel + (root.apiUrl ? " · " + root.apiUrl : "")
    return "Local only · not shared with agents"
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
    orgs = Array.isArray(d.orgs) ? d.orgs : []
    if (d.demo) {
      demoLock = true
      if (!root.opened) root.open()
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

  function openRoutes() {
    if (root.bar) root.bar.run("bash -lc 'xdg-open \"$HOME/.config/screenpipe/org-routes.toml\"'")
  }

  function openAgentTargets() {
    if (root.bar) root.bar.run("bash -lc 'xdg-open \"$HOME/.config/screenpipe/agent-targets.json\"'")
  }

  function bucketShares(modelData) {
    return (modelData.agent && modelData.agent.share)
      || (modelData.hermes && modelData.hermes.share)
      || modelData.agent_share === true
  }

  function bucketAgentLabel(modelData) {
    if (modelData.agent && modelData.agent.label) return modelData.agent.label
    if (modelData.hermes && modelData.hermes.label) return modelData.hermes.label
    return "agent"
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
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.apply(text) }
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
      spacing: Style.space(8)

      // Live / idle indicator
      Rectangle {
        width: Style.space(9)
        height: width
        radius: width / 2
        color: root.recording ? root.okColor : "transparent"
        border.width: root.recording ? 0 : 1.5
        border.color: root.ready ? root.dimColor : root.warnColor
        anchors.verticalCenter: parent.verticalCenter

        SequentialAnimation on opacity {
          running: root.recording
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.35; duration: 900 }
          NumberAnimation { from: 0.35; to: 1.0; duration: 900 }
        }
      }

      Text {
        text: root.shortLabel
        color: root.recording ? root.okColor : root.foreground
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
    open: root.opened || root.demoLock
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(Style.space(520), Style.space(600))

    Item {
      anchors.fill: parent

      Column {
        id: panelBody
        anchors.fill: parent
        spacing: Style.space(14)

        PanelHero {
          width: parent.width
          title: root.paused ? "Paused" : (root.ready ? root.label : "Screenpipe")
          meta: root.statusLine
          foreground: root.foreground
          fontFamily: root.fontFamily
          trailingControl: Component {
            Button {
              text: root.paused ? "Resume" : "Pause"
              foreground: root.foreground
              onClicked: root.runAction(root.paused ? "resume" : "pause")
            }
          }
        }

        // Compact action strip
        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            text: root.mode === "auto" ? "Auto ✓" : "Auto"
            foreground: root.foreground
            onClicked: root.runAction("clear")
          }
          Button {
            text: "Routes"
            foreground: root.foreground
            onClicked: root.openRoutes()
          }
          Button {
            text: "Agents"
            foreground: root.foreground
            onClicked: root.openAgentTargets()
          }
        }

        Flickable {
          id: orgList
          width: parent.width
          height: parent.height - y
          clip: true
          contentWidth: width
          contentHeight: orgCol.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: orgCol
            width: orgList.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "BUCKETS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.orgs
              delegate: BorderSurface {
                required property var modelData
                width: orgCol.width
                height: Style.space(78)
                radius: Style.spacing.labelGap
                color: modelData.selected
                  ? Style.selectedFillFor(root.foreground, Color.accent)
                  : "transparent"
                borderSpec: Border.controlSpec(
                  modelData.selected ? "selected" : "normal",
                  root.foreground,
                  Color.accent
                )

                Row {
                  anchors.fill: parent
                  anchors.margins: Style.space(14)
                  spacing: Style.space(12)

                  // Status pip
                  Rectangle {
                    width: Style.space(11)
                    height: width
                    radius: width / 2
                    color: modelData.recording ? root.okColor : root.trackColor
                    border.width: modelData.recording ? 0 : 1
                    border.color: root.dimColor
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                      running: modelData.recording === true
                      loops: Animation.Infinite
                      NumberAnimation { from: 1.0; to: 0.4; duration: 850 }
                      NumberAnimation { from: 0.4; to: 1.0; duration: 850 }
                    }
                  }

                  Column {
                    width: parent.width - Style.space(90)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(3)

                    Text {
                      text: modelData.label
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      width: parent.width
                      text: ":" + modelData.port
                        + (root.bucketShares(modelData)
                          ? " · shares with " + root.bucketAgentLabel(modelData)
                          : " · local only")
                      color: root.dimColor
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                }

                // REC / SELECTED pill
                Rectangle {
                  visible: modelData.recording || modelData.selected
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(14)
                  anchors.verticalCenter: parent.verticalCenter
                  width: pillText.implicitWidth + Style.space(14)
                  height: Style.space(22)
                  radius: height / 2
                  color: modelData.recording
                    ? Qt.rgba(root.okColor.r, root.okColor.g, root.okColor.b, 0.22)
                    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)

                  Text {
                    id: pillText
                    anchors.centerIn: parent
                    text: modelData.recording ? "REC" : "ON"
                    color: modelData.recording ? root.okColor : root.dimColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.runAction(modelData.id)
                }
              }
            }

            Item { width: 1; height: Style.space(4) }

            PanelSectionHeader {
              text: "AGENT"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            BorderSurface {
              width: parent.width
              height: agentCol.implicitHeight + Style.space(28)
              radius: Style.spacing.labelGap
              color: Qt.rgba(0, 0, 0, 0.22)
              borderSpec: Border.none()

              Column {
                id: agentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(14)
                spacing: Style.space(4)

                Text {
                  width: parent.width
                  wrapMode: Text.WordWrap
                  text: root.agentSummary
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                Text {
                  width: parent.width
                  wrapMode: Text.WordWrap
                  text: root.agentNote !== ""
                    ? root.agentNote
                    : "Middle/right-click chip to pause. Click a bucket to pin. Auto clears the pin."
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }
      }
    }
  }
}
