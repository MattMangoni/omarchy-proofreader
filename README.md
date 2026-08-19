# Proofreader - Omarchy bar widget

A small [Omarchy](https://omarchy.org/) shell plugin for proofreading and
translating short messages with the Claude Code CLI.

The plugin improves spelling, grammar, and awkward phrasing while preserving
the sender's meaning and tone. Questions and requests are rewritten for their
intended recipient, never answered by the model. Successful results replace
the original text and are copied to the clipboard automatically.

## Requirements

- Omarchy with the Quickshell-based shell (`omarchy-shell`)
- An installed and authenticated `claude` CLI

## Install

```bash
omarchy plugin add https://github.com/MattMangoni/omarchy-proofreader.git --enable
```

The widget appears in the right section of the bar by default.

## Usage

1. Click the proofreader icon in the bar.
2. Paste or write a short message.
3. Choose the target language.
4. Click **Improve** or press `Ctrl+Enter`.

The improved text is selected and copied to the clipboard. The button shows
**Copied!** when it is ready to paste.

Supported target languages:

- English
- Italian
- Spanish
- French
- German

The target defaults to the OS language when supported, or English otherwise.

## Remove

```bash
omarchy plugin remove mttmng.proofreader
```
