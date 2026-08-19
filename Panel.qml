import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "mttmng.proofreader"
  ipcTarget: "mttmng.proofreader"

  readonly property string helper: Qt.resolvedUrl("proofread.py").toString().replace("file://", "")
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var languages: [
    { value: "en", label: "English" },
    { value: "it", label: "Italian" },
    { value: "es", label: "Spanish" },
    { value: "fr", label: "French" },
    { value: "de", label: "German" }
  ]
  property string targetLanguage: defaultLanguage()
  property string error: ""
  property string errorAction: ""
  property bool copied: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function defaultLanguage() {
    var locale = Qt.locale().name.substring(0, 2).toLowerCase()
    for (var i = 0; i < languages.length; i++)
      if (languages[i].value === locale) return locale
    return "en"
  }

  function improve() {
    if (editor.text.trim() === "" || transform.running) return
    error = ""
    errorAction = ""
    copied = false
    transform.output = ""
    transform.errorOutput = ""
    transform.stdoutDone = false
    transform.stderrDone = false
    transform.resultCode = -1
    transform.payload = JSON.stringify({ text: editor.text, language: targetLanguage })
    transform.running = true
  }

  function recover() {
    if (errorAction === "install")
      Quickshell.execDetached(["xdg-terminal-exec", "bash", "-lc", "omarchy-mise-install claude && claude auth login"])
    else if (errorAction === "login")
      Quickshell.execDetached(["xdg-terminal-exec", "claude", "auth", "login"])
  }

  onOpenedChanged: if (opened) Qt.callLater(function() { editor.forceActiveFocus() })

  Timer {
    id: copyFeedbackTimer
    interval: 4000
    onTriggered: root.copied = false
  }

  Process {
    id: transform
    property string payload: ""
    property string output: ""
    property string errorOutput: ""
    property int resultCode: -1
    property bool stdoutDone: false
    property bool stderrDone: false

    stdinEnabled: true
    command: [root.helper]

    function finishIfReady() {
      if (resultCode < 0 || !stdoutDone || !stderrDone) return

      var result = output.trim()
      if (resultCode === 0 && result !== "") {
        editor.text = result
        Quickshell.execDetached(["omarchy-clipboard-paste-text", "--copy-only", result])
        root.copied = true
        copyFeedbackTimer.restart()
        Qt.callLater(function() {
          editor.forceActiveFocus()
          editor.selectAll()
        })
      } else {
        var failure = errorOutput.trim()
        if (failure.indexOf("CLAUDE_NOT_INSTALLED") !== -1) {
          root.error = "Claude Code is not installed yet. Install it and sign in, then try again."
          root.errorAction = "install"
        } else if (failure.indexOf("CLAUDE_NOT_AUTHENTICATED") !== -1) {
          root.error = "Claude Code needs you to sign in before it can improve text."
          root.errorAction = "login"
        } else {
          root.error = failure || "Could not improve the text"
        }
      }
    }

    onStarted: {
      write(payload + "\n")
      payload = ""
    }
    onExited: function(exitCode) {
      resultCode = exitCode
      finishIfReady()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        transform.output = String(text || "")
        transform.stdoutDone = true
        transform.finishIfReady()
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        transform.errorOutput = String(text || "")
        transform.stderrDone = true
        transform.finishIfReady()
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        Image {
          id: proofreaderIcon
          anchors.centerIn: parent
          width: Style.space(16)
          height: width
          source: Qt.resolvedUrl("assets/proofreader.svg")
          sourceSize.width: width * 2
          sourceSize.height: height * 2
          visible: false
        }
        MultiEffect {
          anchors.fill: proofreaderIcon
          source: proofreaderIcon
          colorization: 1
          colorizationColor: root.foreground
        }
      }
    }
    tooltipText: "Proofread or translate text"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: editor
    contentWidth: fittedContentWidth(Style.space(420))
    contentHeight: fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      anchors.fill: parent
      blocked: editor.activeFocus || languageDropdown.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Controls.TextArea {
          id: editor
          width: parent.width
          implicitHeight: Style.space(180)
          enabled: !transform.running
          placeholderText: "Paste or write a short message..."
          wrapMode: TextEdit.Wrap
          selectByMouse: true
          color: root.foreground
          selectionColor: Style.selectionFillFor(root.foreground, Color.accent)
          selectedTextColor: root.foreground
          placeholderTextColor: Qt.darker(root.foreground, 1.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          leftPadding: Style.spacing.controlPaddingX + Style.space(8)
          rightPadding: Style.spacing.controlPaddingX + Style.space(8)
          topPadding: Style.spacing.controlPaddingY + Style.space(8)
          bottomPadding: Style.spacing.controlPaddingY + Style.space(8)
          Accessible.name: "Text to proofread or translate"

          background: BorderSurface {
            color: Style.controlFill(editor.activeFocus, editor.hovered, root.foreground, Color.accent)
            borderSpec: Border.controlSpec(editor.activeFocus ? "focus" : (editor.hovered ? "hover-cursor" : "normal"), root.foreground, Color.accent)
            radius: Style.cornerRadius
          }

          Keys.onPressed: function(event) {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && (event.modifiers & Qt.ControlModifier)) {
              root.improve()
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              root.close()
              event.accepted = true
            }
          }
        }

        Dropdown {
          id: languageDropdown
          width: parent.width
          label: "Target language"
          value: root.targetLanguage
          options: root.languages
          foreground: root.foreground
          fontFamily: root.fontFamily
          enabled: !transform.running
          onChanged: function(value) { root.targetLanguage = value }
        }

        Column {
          visible: root.error !== ""
          width: parent.width
          spacing: Style.space(8)

          Text {
            width: parent.width
            text: root.error
            color: Color.urgent
            wrapMode: Text.WordWrap
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Button {
            visible: root.errorAction !== ""
            text: root.errorAction === "install" ? "Install and sign in" : "Sign in to Claude"
            foreground: root.foreground
            fontFamily: root.fontFamily
            focusable: true
            bordered: true
            onClicked: root.recover()
          }
        }

        Row {
          spacing: Style.space(10)

          Button {
            text: transform.running ? "Improving..." : (root.copied ? "Copied!" : "Improve")
            enabled: editor.text.trim() !== "" && !transform.running
            foreground: root.foreground
            fontFamily: root.fontFamily
            focusable: true
            bordered: true
            onClicked: root.improve()
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Ctrl+Enter"
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
