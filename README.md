# Agent Launch — Omarchy bar widget

A small Omarchy (Quattro) bar widget that builds the launch command for an AI coding-agent
harness and copies it to the clipboard. Pick a **harness**, a **model** and a **reasoning effort**,
then paste the command into any terminal.

- Plugin ID: `nik.agent-launch`
- Kind: `bar-widget` (default section: `right`)
- License: MIT

## Features

- **Harness selector** — Claude Code, Codex, Pi and Hermes out of the box; replace or extend the
  list in your shell config.
- **Model selector** — per-harness model list, with short labels (provider prefixes and `claude-`
  are dropped on the buttons).
- **Reasoning-effort selector** — per-harness effort levels. Harnesses without effort levels hide
  the row, and the effort flag is removed from the command.
- **Live command preview** and a **Copy command** button (`wl-copy`).
- **Remembers your choice** per harness (last model + effort) and the last harness used.
- **Right-click** the bar icon to copy the last-used command without opening the panel.
- **Keyboard driven** — Up/Down move between rows, Left/Right change the choice, Enter copies,
  Esc closes.
- **Shell-safe** — model and effort tokens are restricted to `[A-Za-z0-9._:/@+=,[]-]` (max 120
  chars); anything containing spaces, quotes, `$`, `;`, `|`, `&` or backticks is dropped. The
  clipboard is written via an argv call (`wl-copy -- <command>`), never through a shell.

Default commands it produces:

| Harness | Template |
|---|---|
| Claude | `claude --model {model} --effort {effort}` |
| Codex  | `codex -m {model} -c model_reasoning_effort={effort}` |
| Pi     | `pi --model {model} --thinking {effort}` |
| Hermes | `hermes --provider ollama-cloud -m {model} --reasoning {effort}` |

The built-in model lists reflect the author's setup. Override them with the `harnesses` setting
below to match yours.

## Requirements

- Omarchy Quattro shell (plugin `schemaVersion` 1).
- `wl-copy` from `wl-clipboard` (installed by default on Omarchy).
- The harness CLIs themselves are **not** required by the widget — it only builds and copies text.

## Install

```bash
omarchy plugin add https://github.com/Gleinkaa/omarchy-agent-launch.git --enable
```

The widget lands in the right section of the bar. Toggle it from a keybinding with
`omarchy-shell nik.agent-launch toggle`.

## Remove

```bash
omarchy plugin remove nik.agent-launch
```

## Configuration

Settings live on the widget's entry in the bar config (`~/.config/omarchy/shell.json`).

| Key | Type | Default | Description |
|---|---|---|---|
| `closeOnCopy` | boolean | `true` | Close the panel ~0.5 s after copying. Exposed in the widget settings UI. |
| `harnesses` | array | built-in list | Replace the harness list (advanced; edit the JSON directly). |

Each `harnesses` item:

| Field | Required | Description |
|---|---|---|
| `id` | no | Stable id (used to remember selections). Falls back to `harness<N>`. |
| `label` | no | Button label (max 24 chars). Defaults to `id`. |
| `template` | yes | Command template; must contain `{model}`, may contain `{effort}` (max 400 chars). |
| `models` | yes | Model ids (max 24, shell-safe tokens only; unsafe ones are dropped). |
| `efforts` | no | Effort levels (max 24). Empty → effort row hidden, effort flag stripped. |
| `defaultEffort` | no | Initial effort; must be one of `efforts`. |

Example entry:

```json
{
  "id": "nik.agent-launch",
  "closeOnCopy": false,
  "harnesses": [
    {
      "id": "claude",
      "label": "Claude",
      "template": "claude --model {model} --effort {effort}",
      "models": ["claude-opus-5-5", "claude-sonnet-5-5"],
      "efforts": ["low", "medium", "high"],
      "defaultEffort": "high"
    },
    {
      "id": "aider",
      "label": "Aider",
      "template": "aider --model {model}",
      "models": ["ollama/qwen3:8b"]
    }
  ]
}
```

Harness entries that fail validation are skipped; if none survive, the built-in list is used.

The widget also stores its own state on the same entry — `lastHarness` and `selection`
(last model/effort per harness). It never writes anything else.

## Development

```bash
omarchy plugin validate .     # manifest schema check
node tests/model.test.js      # pure-JS tests for Model.js (needs Node.js)
```

`Model.js` has no QML imports, so the command-building and sanitising logic runs under plain
Node. `Panel.qml` is the bar widget and panel UI; `i18n/en.json` holds the strings.

## License

MIT — see [LICENSE](LICENSE).
