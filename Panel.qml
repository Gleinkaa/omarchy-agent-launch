import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Agent Launch: choose harness, model and effort; copy the launch command.
// Keys: Up/Down move between rows, Left/Right change the choice in a row,
// Enter copies. Selections are remembered per harness in shell.json.
Panel {
  id: root
  moduleName: "nik.agent-launch"
  // No ipcTarget: the bar already routes `omarchy-shell nik.agent-launch toggle`.

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // Harness list: settings.harnesses overrides the built-in list.
  readonly property var harnesses: Model.normalizeHarnesses(setting("harnesses", null))
  property int harnessIndex: 0
  property string model: ""
  property string effort: ""
  property int row: 0            // 0 harness, 1 model, 2 effort, 3 copy
  property bool cursorActive: false
  property bool justCopied: false

  readonly property var harness: harnesses[Math.min(harnessIndex, harnesses.length - 1)]
  readonly property string command: Model.buildCommand(harness, model, effort)
  readonly property bool hasEfforts: harness && harness.efforts.length > 0

  // Restores the remembered model/effort for the chosen harness.
  function selectHarness(index) {
    harnessIndex = Model.wrap(index, 0, harnesses.length)
    var h = harnesses[harnessIndex]
    var saved = (setting("selection", {}) || {})[h.id] || {}
    model = h.models.indexOf(saved.model) >= 0 ? saved.model : h.models[0]
    effort = h.efforts.indexOf(saved.effort) >= 0 ? saved.effort : h.defaultEffort
  }

  function restore() {
    selectHarness(Model.indexOfId(harnesses, setting("lastHarness", "")))
  }

  function step(dx) {
    var h = harness
    if (row === 0) selectHarness(Model.wrap(harnessIndex, dx, harnesses.length))
    else if (row === 1) model = h.models[Model.wrap(h.models.indexOf(model), dx, h.models.length)]
    else if (row === 2 && hasEfforts) effort = h.efforts[Model.wrap(h.efforts.indexOf(effort), dx, h.efforts.length)]
  }

  function moveRow(dy) {
    var next = row + dy
    if (next === 2 && !hasEfforts) next += dy
    row = Math.max(0, Math.min(3, next))
  }

  function remember() {
    var sel = Object.assign({}, setting("selection", {}) || {})
    sel[harness.id] = { model: model, effort: effort }
    root.settings = Object.assign({}, root.settings, { lastHarness: harness.id, selection: sel })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  function copy() {
    if (command === "" || copyProc.running) return
    // argv, never a shell string; tokens are already restricted by Model.safeToken.
    copyProc.command = ["wl-copy", "--", command]
    copyProc.running = true
  }

  onOpenedChanged: if (opened) { restore(); row = 0; cursorActive = false; justCopied = false }
  Component.onCompleted: restore()

  Process {
    id: copyProc
    onExited: function(code) {
      if (code !== 0) return
      root.justCopied = true
      root.remember()
      if (root.setting("closeOnCopy", true) === true) closeTimer.restart()
    }
  }

  Timer { id: closeTimer; interval: 450; onTriggered: root.close() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱓞"   // nf-md-rocket_launch
    slotSize: Style.bar.iconSlot
    tooltipText: root.opened ? "" : strings.t("tooltip")
    onPressed: function(b) {
      // Right click copies the last-used command without opening the panel.
      if (b === Qt.RightButton) { root.restore(); root.copy() }
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveRow(dy)
        else if (dx !== 0) root.step(dx)
      }
      onActivateRequested: root.copy()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero ----------
        Row {
          spacing: Style.space(14)
          PlainText {
            text: button.text
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            PlainText { text: strings.t("title"); font.pixelSize: Style.font.title; font.bold: true }
            PlainText {
              text: strings.t("subtitle").toUpperCase()
              opacity: 0.6
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        OptionRow {
          title: strings.t("harness")
          rowIndex: 0
          options: root.harnesses.map(function(h) { return h.id })
          labels: root.harnesses.map(function(h) { return h.label })
          current: root.harness ? root.harness.id : ""
          onPicked: function(i) { root.selectHarness(i) }
        }

        OptionRow {
          title: strings.t("model")
          rowIndex: 1
          options: root.harness ? root.harness.models : []
          labels: options.map(function(m) { return Model.modelLabel(m) })
          current: root.model
          onPicked: function(i) { root.model = options[i] }
        }

        OptionRow {
          visible: root.hasEfforts
          title: strings.t("effort")
          rowIndex: 2
          options: root.harness ? root.harness.efforts : []
          labels: options
          current: root.effort
          onPicked: function(i) { root.effort = options[i] }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Command preview + copy ----------
        Rectangle {
          width: parent.width
          implicitHeight: cmdText.implicitHeight + Style.space(16)
          radius: Style.space(6)
          color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.08)

          PlainText {
            id: cmdText
            anchors.fill: parent
            anchors.margins: Style.space(8)
            text: "$ " + root.command
            font.family: "monospace"
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WrapAnywhere
            verticalAlignment: Text.AlignVCenter
          }
        }

        Button {
          width: parent.width
          iconText: root.justCopied ? "" : ""   // check / copy
          text: root.justCopied ? strings.t("copied") : strings.t("copy")
          fontSize: Style.font.bodySmall
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
          bordered: true
          active: root.justCopied
          hasCursor: root.cursorActive && root.row === 3
          onClicked: root.copy()
          onHovered: function(h) { if (h) { root.cursorActive = true; root.row = 3 } }
        }
      }
    }
  }

  component PlainText: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
  }

  component OptionRow: Column {
    id: optionRow
    property string title: ""
    property int rowIndex: 0
    property var options: []
    property var labels: []
    property string current: ""
    signal picked(int index)

    width: parent.width
    spacing: Style.space(8)

    PanelSectionHeader {
      text: optionRow.title
      foreground: root.bar.foreground
      fontFamily: root.bar.fontFamily
    }

    Flow {
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: optionRow.options
        Button {
          required property var modelData
          required property int index
          text: optionRow.labels[index] !== undefined ? String(optionRow.labels[index]) : String(modelData)
          fontSize: Style.font.bodySmall
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX + Style.space(2)
          bordered: true
          active: optionRow.current === modelData
          hasCursor: root.cursorActive && root.row === optionRow.rowIndex && optionRow.current === modelData
          onClicked: { root.row = optionRow.rowIndex; optionRow.picked(index) }
          onHovered: function(h) { if (h) { root.cursorActive = true; root.row = optionRow.rowIndex } }
        }
      }
    }
  }
}
