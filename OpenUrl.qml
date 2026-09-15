import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Url.js" as Url
import "History.js" as History

Item {
  id: root

  // Injected by omarchy-shell when this plugin is summoned.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string text: ""
  property int selectedIndex: 0

  // Recency cache. Loaded once at shell start and kept in memory, so opening
  // the palette and every keystroke are pure JS — no process, no disk.
  property var entries: []
  property string historyPath: Quickshell.env("HOME") + "/.local/state/omarchy/open-url-history.json"
  property int historyLimit: 500
  property int matchLimit: 50
  property double now: 0

  // Shares the [menu] surface tokens so the palette matches the launcher.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property var selectedBorderSpec: Border.surfaceSpec("menu", "selected-border", Color.menu.selectedBorder, 0)
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int rowHeight: Math.max(Style.space(50), Style.font.body + Style.spacing.rowPaddingX * 2)
  property int rowSpacing: Style.spacing.xs
  property int maxVisibleRows: 6

  readonly property string url: Url.normalizeUrl(root.text)
  readonly property bool valid: root.url.length > 0
  readonly property int visibleRows: Math.min(displayModel.count, root.maxVisibleRows)
  readonly property int listHeight: displayModel.count === 0
    ? root.rowHeight
    : root.visibleRows * root.rowHeight + (root.visibleRows - 1) * root.rowSpacing

  property int cardWidth: Math.min(Style.space(420), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(
    contentMargin * 2 + headerHeight + contentSpacing + listHeight,
    panel.height - Style.gapsOut * 2)

  function open(payloadJson) {
    root.pruneExpired()
    root.text = ""
    field.text = ""
    root.selectedIndex = 0
    root.opened = true
    root.rebuild()
    Qt.callLater(function() { field.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "nonmirror.open-url")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function loadHistory(raw) {
    root.entries = History.parse(raw)
    root.pruneExpired()
    if (root.opened) root.rebuild()
  }

  function saveHistory() {
    historyFile.setText(History.serialize(root.entries))
  }

  // Aging runs once per open and once per reload, never on a keystroke. The
  // file is rewritten only when something actually expires, so a plain
  // open/close never writes.
  function pruneExpired() {
    var pruned = History.prune(root.entries, Date.now(), History.TTL_MS)
    if (pruned.length !== root.entries.length) {
      root.entries = pruned
      root.saveHistory()
    }
  }

  // Rebuilds the suggestion list. Pure in-memory matching over the loaded
  // cache, so a keystroke is microseconds of JS and nothing else.
  function rebuild() {
    root.now = Date.now()

    displayModel.clear()

    var typed = root.url
    var cached = History.matches(root.entries, root.text, root.matchLimit)
    if (typed.length > 0 && !History.containsUrl(cached, typed)) {
      displayModel.append({
        url: typed,
        label: History.displayUrl(typed),
        detail: "Open link in default browser",
        kind: "typed"
      })
    }
    for (var i = 0; i < cached.length; i++) {
      displayModel.append({
        url: cached[i].url,
        label: History.displayUrl(cached[i].url),
        detail: History.formatAge(cached[i].accessed, root.now),
        kind: "cached"
      })
    }

    root.selectedIndex = 0
    Qt.callLater(function() {
      if (displayModel.count > 0) resultList.positionViewAtIndex(0, ListView.Beginning)
    })
  }

  function select(delta) {
    if (displayModel.count === 0) return
    root.selectedIndex = (root.selectedIndex + delta + displayModel.count) % displayModel.count
    Qt.callLater(function() { resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain) })
  }

  function submit() {
    if (displayModel.count > 0) {
      var index = Math.max(0, Math.min(root.selectedIndex, displayModel.count - 1))
      root.openUrl(displayModel.get(index).url)
      return
    }
    if (root.valid) root.openUrl(root.url)
  }

  function openUrl(url) {
    var link = String(url || "")
    if (!link) return

    root.entries = History.record(root.entries, link, Date.now(), root.historyLimit)
    root.saveHistory()
    root.dismiss()
    // execArgv keeps the URL a literal argument, so a pasted link cannot be
    // re-tokenized by the shell. omarchy-launch-browser focuses an existing
    // browser window; xdg-open is the fallback.
    Util.execArgv(["sh", "-c", 'omarchy-launch-browser "$1" 2>/dev/null || xdg-open "$1"', "sh", link])
  }

  ListModel { id: displayModel }

  FileView {
    id: historyFile
    path: root.historyPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("[]")
    onFileChanged: reload()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-open-url"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Item {
          width: parent.width
          height: root.headerHeight

          Text {
            anchors.fill: parent
            visible: field.text.length === 0
            text: "Open URL…"
            color: root.foreground
            opacity: 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            verticalAlignment: Text.AlignVCenter
          }

          // A real TextInput gives native editing (click, select, copy/paste)
          // that a hand-rolled key filter would not.
          TextInput {
            id: field
            anchors.fill: parent
            focus: root.opened
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            selectionColor: root.selectedBackground
            selectedTextColor: root.selectedText
            clip: true
            onTextChanged: {
              root.text = text
              if (root.opened) root.rebuild()
            }
            onAccepted: root.submit()
            // Selection follows the launcher's muscle memory: Alt+J down,
            // Alt+K up. Arrow keys keep working as a secondary.
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_K && (event.modifiers & Qt.AltModifier)) {
                root.select(-1)
                event.accepted = true
              } else if (event.key === Qt.Key_J && (event.modifiers & Qt.AltModifier)) {
                root.select(1)
                event.accepted = true
              }
            }
            Keys.onUpPressed: function(event) { root.select(-1); event.accepted = true }
            Keys.onDownPressed: function(event) { root.select(1); event.accepted = true }
            Keys.onEscapePressed: function(event) {
              if (root.text) { root.text = ""; field.text = "" }
              else root.dismiss()
              event.accepted = true
            }
          }
        }

        Item {
          width: parent.width
          height: root.listHeight

          ListView {
            id: resultList
            anchors.fill: parent
            model: displayModel
            clip: true
            spacing: root.rowSpacing
            boundsBehavior: Flickable.StopAtBounds

            delegate: BorderSurface {
              id: row
              required property int index
              required property string url
              required property string label
              required property string detail

              readonly property bool hasCursor: row.index === root.selectedIndex

              width: ListView.view.width
              height: root.rowHeight
              radius: root.cornerRadius
              color: row.hasCursor ? root.selectedBackground : "transparent"
              borderSpec: row.hasCursor ? root.selectedBorderSpec : Border.none()

              Text {
                id: rowIcon
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: "󰖟"
                color: row.hasCursor ? root.selectedText : root.foreground
                opacity: row.hasCursor ? 1 : 0.8
                font.family: root.fontFamily
                font.pixelSize: Style.font.iconLarge
                width: Style.space(36)
                horizontalAlignment: Text.AlignHCenter
              }

              Column {
                anchors.left: rowIcon.right
                anchors.leftMargin: Style.space(6)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: row.label
                  color: row.hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.heading
                  font.weight: Font.Medium
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  visible: row.detail.length > 0
                  text: row.detail
                  color: row.hasCursor ? root.selectedText : root.foreground
                  opacity: 0.52
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = row.index
                onClicked: {
                  root.selectedIndex = row.index
                  root.openUrl(row.url)
                }
              }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(6)
            visible: displayModel.count === 0

            Text {
              text: "󰖟"
              color: root.selectedText
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: parent.parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.text.length > 0
                ? "No match for “" + root.text + "”"
                : "Type or paste a link"
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              width: parent.parent.width
            }
          }
        }
      }
    }
  }
}
