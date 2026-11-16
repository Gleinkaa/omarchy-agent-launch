// Run: node tests/model.test.js
const fs = require("fs"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(".pragma library", "")
const M = new Function(src + "; return {DEFAULT_HARNESSES, normalizeHarnesses, buildCommand, modelLabel, safeToken, wrap, indexOfId}")()

const hs = M.normalizeHarnesses(undefined)
const by = id => hs[M.indexOfId(hs, id)]
assert.strictEqual(M.buildCommand(by("claude"), "claude-opus-5-5", "max"), "claude --model claude-opus-5-5 --effort max")
assert.strictEqual(M.buildCommand(by("codex"), "gpt-6-astra", "xhigh"), "codex -m gpt-6-astra -c model_reasoning_effort=xhigh")
assert.strictEqual(M.buildCommand(by("pi"), "ollama-cloud/deepseek-v4-pro:0813", "high"), "pi --model ollama-cloud/deepseek-v4-pro:0813 --thinking high")
assert.strictEqual(M.buildCommand(by("hermes"), "glm-5.3", "low"), "hermes --provider ollama-cloud -m glm-5.3 --reasoning low")
// No effort: the whole flag group disappears.
assert.strictEqual(M.buildCommand(by("claude"), "claude-opus-5-5", ""), "claude --model claude-opus-5-5")
assert.strictEqual(M.buildCommand(by("codex"), "gpt-6-astra", ""), "codex -m gpt-6-astra")
// Shell metacharacters never reach the command.
for (const bad of ["x; rm -rf ~", "$(id)", "`id`", "a b", "a|b", "a&b", "<img src=x>", "'q'"]) {
  assert.strictEqual(M.safeToken(bad), false, bad)
  assert.strictEqual(M.buildCommand(by("claude"), bad, "high"), "")
  assert.strictEqual(M.buildCommand(by("claude"), "claude-opus-5-5", bad), "claude --model claude-opus-5-5")
}
const custom = M.normalizeHarnesses([{ id: "x", template: "x {model}", models: ["ok", "bad;one"], efforts: [] }])
assert.deepStrictEqual(custom[0].models, ["ok"])
assert.strictEqual(M.buildCommand(custom[0], "ok", ""), "x ok")
assert.strictEqual(M.normalizeHarnesses([{ id: "y", template: "no placeholder", models: ["a"] }]).length, hs.length) // falls back
assert.strictEqual(M.modelLabel("ollama-cloud/kimi-k3"), "kimi-k3")
assert.strictEqual(M.modelLabel("claude-fable-5-2"), "fable-5-2")
assert.strictEqual(M.wrap(0, -1, 4), 3)
console.log("ok: all model tests passed")
