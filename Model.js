.pragma library

// Pure helpers for the Agent Launch panel. No QML imports, so this file runs
// under plain node for tests (see tests/model.test.js).

var DEFAULT_HARNESSES = [
  {
    id: "claude",
    label: "Claude",
    template: "claude --model {model} --effort {effort}",
    models: ["claude-opus-5-5", "claude-fable-5-2", "claude-sonnet-5-5", "claude-haiku-5-5"],
    efforts: ["low", "medium", "high", "xhigh", "max"],
    defaultEffort: "high"
  },
  {
    id: "codex",
    label: "Codex",
    template: "codex -m {model} -c model_reasoning_effort={effort}",
    models: ["gpt-6-astra", "gpt-6.1-sol", "gpt-6.1-terra", "gpt-6-luna", "gpt-5.6-sol"],
    efforts: ["low", "medium", "high", "xhigh", "max", "ultra"],
    defaultEffort: "high"
  },
  {
    id: "pi",
    label: "Pi",
    template: "pi --model {model} --thinking {effort}",
    models: ["ollama-cloud/minimax-m3.1-flash", "ollama-cloud/glm-5.3", "ollama-cloud/kimi-k3",
             "ollama-cloud/deepseek-v4-pro:0813", "ollama-a9max/qwen3.8:27b-moe"],
    efforts: ["off", "minimal", "low", "medium", "high", "xhigh", "max"],
    defaultEffort: "medium"
  },
  {
    id: "hermes",
    label: "Hermes",
    template: "hermes --provider ollama-cloud -m {model} --reasoning {effort}",
    models: ["minimax-m3.1-flash", "glm-5.3", "kimi-k3", "deepseek-v4.1-flash"],
    efforts: ["none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra"],
    defaultEffort: "medium"
  }
]

var MAX_HARNESSES = 16
var MAX_OPTIONS = 24
var MAX_LEN = 120

// Only characters that are safe to paste into a shell unquoted. Model ids
// like "ollama-cloud/deepseek-v4-pro:0813" or "claude-opus-4-8[1m]" pass;
// anything with spaces, quotes, $, ;, |, & or backticks is dropped.
var SAFE_TOKEN = /^[A-Za-z0-9._:\/@+=,\[\]-]+$/

function safeToken(value) {
  var s = String(value === undefined || value === null ? "" : value)
  return s.length > 0 && s.length <= MAX_LEN && SAFE_TOKEN.test(s)
}

function cleanList(list) {
  if (!Array.isArray(list)) return []
  var out = []
  for (var i = 0; i < list.length && out.length < MAX_OPTIONS; i++) {
    var v = String(list[i])
    if (safeToken(v) && out.indexOf(v) < 0) out.push(v)
  }
  return out
}

// Validates harness definitions from shell.json, falling back to the
// built-in list when the setting is missing or nothing in it survives.
function normalizeHarnesses(raw) {
  var src = Array.isArray(raw) && raw.length > 0 ? raw : DEFAULT_HARNESSES
  var out = []
  for (var i = 0; i < src.length && out.length < MAX_HARNESSES; i++) {
    var h = src[i]
    if (!h || typeof h !== "object") continue
    var template = String(h.template || "")
    if (template.length === 0 || template.length > 400 || template.indexOf("{model}") < 0) continue
    var models = cleanList(h.models)
    if (models.length === 0) continue
    var efforts = cleanList(h.efforts)
    var id = safeToken(h.id) ? String(h.id) : ("harness" + i)
    out.push({
      id: id,
      label: String(h.label || id).slice(0, 24),
      template: template,
      models: models,
      efforts: efforts,
      defaultEffort: efforts.indexOf(String(h.defaultEffort)) >= 0 ? String(h.defaultEffort) : (efforts[0] || "")
    })
  }
  return out.length > 0 ? out : normalizeHarnesses(DEFAULT_HARNESSES)
}

function indexOfId(harnesses, id) {
  for (var i = 0; i < harnesses.length; i++) if (harnesses[i].id === id) return i
  return 0
}

// Short label for a model button: drops a provider prefix and "claude-".
function modelLabel(model) {
  var s = String(model)
  var slash = s.lastIndexOf("/")
  if (slash >= 0) s = s.slice(slash + 1)
  if (s.indexOf("claude-") === 0) s = s.slice(7)
  return s
}

// Builds the final command. When the harness has no effort levels, or the
// effort is empty, every " ...{effort}" flag group is removed.
function buildCommand(harness, model, effort) {
  if (!harness || !safeToken(model)) return ""
  var cmd = harness.template.split("{model}").join(model)
  if (effort && safeToken(effort)) {
    cmd = cmd.split("{effort}").join(effort)
  } else {
    // "--effort {effort}", "-c key={effort}", "--thinking={effort}" all go.
    cmd = cmd.replace(/\s+(--?[A-Za-z0-9_-]+[ =])?\S*\{effort\}\S*/g, "")
  }
  return cmd.replace(/\s+/g, " ").trim()
}

function wrap(index, delta, length) {
  if (length <= 0) return 0
  return ((index + delta) % length + length) % length
}
