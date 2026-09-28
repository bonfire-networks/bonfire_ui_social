import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = fs.readFileSync(new URL("../lib/components/activity/subject/join_request_actions_live.hooks.js", import.meta.url), "utf8");
function setup() {
  const focused = [];
  const body = {};
  const nodes = {};
  const document = { body, activeElement: body, getElementById: (id) => nodes[id] };
  const button = (id) => ({ id, getClientRects: () => [{}], focus: () => { focused.push(id); document.activeElement = nodes[id]; } });
  const approve = button("approve");
  const next = button("next");
  const listeners = {};
  const el = {
    // as the template renders them: data-request-error is always the string "true" or "false"
    id: "current", dataset: { requestStatus: "pending", requestError: "false" },
    contains: (element) => element === approve, querySelector: () => approve,
    closest: () => feed,
    addEventListener: (type, callback) => { listeners[type] = callback; },
    removeEventListener: (type) => { delete listeners[type]; },
  };
  const nextControl = { id: "next-control", querySelector: () => next };
  const feed = { id: "feed", querySelectorAll: () => [el, nextControl], focus: () => focused.push("feed") };
  Object.assign(nodes, { approve, next, current: el, "next-control": nextControl, feed });
  const sandbox = { document };
  vm.runInNewContext(source.replace("export { JoinRequestFocus };", "this.hook = JoinRequestFocus;"), sandbox);
  const hook = { ...sandbox.hook, el };
  hook.mounted();
  document.activeElement = approve;
  listeners.submit({});
  return { hook, el, document, focused, nodes, listeners };
}

test("declining focuses the remaining approval action", () => {
  const { hook, el, document, focused } = setup();
  el.dataset.requestStatus = "declined";
  document.activeElement = document.body;
  hook.updated();
  assert.deepEqual(focused, ["approve"]);
});
test("approval focuses the next request only once", () => {
  const { hook, el, document, focused } = setup();
  el.dataset.requestStatus = "approved";
  document.activeElement = document.body;
  hook.updated();
  hook.destroyed();
  assert.deepEqual(focused, ["next"]);
});
test("removing the last request focuses the feed and cleans up", () => {
  const { hook, document, focused, nodes, listeners } = setup();
  delete nodes["next-control"];
  document.activeElement = document.body;
  hook.destroyed();
  assert.deepEqual(focused, ["feed"]);
  assert.equal(listeners.submit, undefined);
});
test("a delayed decision does not steal focus", () => {
  const { hook, el, document, focused } = setup();
  document.activeElement = { id: "elsewhere" };
  el.dataset.requestStatus = "declined";
  hook.updated();
  assert.deepEqual(focused, []);
});
test("a failed decision retains the current focus", () => {
  const { hook, el, document, focused } = setup();
  el.dataset.requestError = "true";
  hook.updated();
  document.activeElement = document.body;
  hook.destroyed();
  assert.deepEqual(focused, []);
});
