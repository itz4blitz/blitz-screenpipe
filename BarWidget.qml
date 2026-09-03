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
  property string mode: "auto"
  property string org: "personal"
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

  // Mic glyphs (Nerd Font / Material-ish private use used elsewhere on this bar)
  readonly property string micOn: "\uF130"
  readonly property string micOff: "\uF131"

  readonly property color micColor: {
    if (!root.ready) return root.warnColor
    if (root.paused || !root.recording) return root.trackColor
    return root.okColor
  }

  function apply(payload) {
    try { var d = JSON.parse(String(payload)) } catch (e) { return }
    ready = d.ready !== false
    paused = d.paused === true
    recording = d.recording === true
    mode = String(d.mode || "auto")
    org = String(d.org || "personal")
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

  function triggerPress(button) {
    if (button === Qt.MiddleButton) {
      root.runAction(root.paused ? "resume" : "pause")
      return
    }
    if (button === Qt.RightButton) {
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

      // Little-Snitch style: filled when recording, hollow/dim when paused
      Rectangle {
        width: Style.space(10)
        height: width
        radius: width / 2
        color: root.recording ? root.okColor : "transparent"
        border.width: root.recording ? 0 : 1.5
        border.color: root.ready ? root.dimColor : root.warnColor
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          visible: root.recording
          anchors.centerIn: parent
          width: parent.width * 0.45
          height: width
          radius: width / 2
          color: root.foreground
          opacity: 0.9
        }
      }

      Text {
        text: root.recording ? root.micOn : root.micOff
        color: root.micColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
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
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(Style.space(480), Style.space(560))

    Item {
      anchors.fill: parent

      Column {
        id: panelBody
        anchors.fill: parent
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: root.paused ? "Screenpipe paused" : root.label
          meta: root.ready
            ? ((root.recording ? "Recording" : "Idle")
              + " · " + root.mode
              + (root.reason ? " · " + root.reason : ""))
            : (root.hint !== "" ? root.hint : "unavailable")
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

        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            text: "Auto"
            foreground: root.foreground
            enabled: root.mode !== "auto" || root.org !== ""
            onClicked: root.runAction("clear")
          }
          Button {
            text: "Routes"
            foreground: root.foreground
            onClicked: root.openRoutes()
          }
          Button {
            text: "Agent map"
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
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "ORG BUCKET"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.orgs
              delegate: BorderSurface {
                required property var modelData
                width: orgCol.width
                height: rowInner.implicitHeight + Style.space(14)
                radius: Style.spacing.labelGap
                color: modelData.selected
                  ? Style.selectedFillFor(root.foreground, Color.accent)
                  : "transparent"
                borderSpec: modelData.selected
                  ? Border.controlSpec("normal", root.foreground, Color.accent)
                  : Border.none()

                Column {
                  id: rowInner
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(10)
                  spacing: Style.space(2)

                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Rectangle {
                      width: Style.space(8)
                      height: width
                      radius: width / 2
                      color: modelData.recording ? root.okColor : root.trackColor
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      text: modelData.label
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                      width: Math.max(1, parent.width - 160)
                      height: 1
                    }

                    Text {
                      text: modelData.recording ? "REC" : (modelData.selected ? "selected" : "")
                      color: modelData.recording ? root.okColor : root.dimColor
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  Text {
                    width: parent.width
                    text: ":" + modelData.port
                      + ((modelData.agent && modelData.agent.share) || (modelData.hermes && modelData.hermes.share)
                        ? " · Agent: " + ((modelData.agent && modelData.agent.label) || (modelData.hermes && modelData.hermes.label) || "yes")
                        : " · local only")
                    color: root.dimColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.runAction(modelData.id)
                }
              }
            }

            PanelSectionHeader {
              text: "AGENT"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: root.agentShare
                ? (root.agentLabel + "\n" + root.apiUrl + "\n" + root.agentNote)
                : ("Not shared for " + root.label + ".\n" + (root.agentNote || "Personal stays on this machine."))
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Middle/right-click chip to pause. Click an org to pin it (manual). Auto clears the pin."
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
