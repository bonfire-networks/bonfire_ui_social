import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const hookUrl = new URL("../lib/components/feeds/feed_live.hooks.js", import.meta.url);
const hookSource = fs.readFileSync(hookUrl, "utf8");

function activity(id, top, bottom, { hidden = false, fresh = false } = {}) {
  const position = { top, bottom };
  const classes = new Set();
  if (fresh) classes.add("fresh_hidden");
  if (hidden) classes.add("hidden");

  return {
    id: `fa_${id}`,
    position,
    classes,
    getBoundingClientRect() {
      // display:none elements report an all-zero rect
      return classes.has("hidden") ? { top: 0, bottom: 0 } : this.position;
    },
  };
}

// the hooks are ES modules, so swap the export for globals the sandbox can hand back
function runnableSource() {
  return hookSource.replace(
    /export\s+\{[^}]+\};\s*$/,
    "globalThis.__FeedScrollTracker = FeedScrollTracker; globalThis.__FeedJumpToTop = FeedJumpToTop;",
  );
}

function flushPromises() {
  return new Promise((resolve) => setImmediate(resolve));
}

function mutableClassList() {
  const values = new Set();

  return {
    add(name) {
      values.add(name);
    },
    remove(name) {
      values.delete(name);
    },
    toggle(name, force) {
      if (force === true) values.add(name);
      else if (force === false) values.delete(name);
      else if (values.has(name)) values.delete(name);
      else values.add(name);
    },
    contains(name) {
      return values.has(name);
    },
  };
}

function loadTracker({
  enabled = true,
  feedName = "my",
  hasNewer = false,
  initialScrollY = 0,
  resumedCursor = "",
  activities = [],
  storedOffset = null,
} = {}) {
  const listeners = new Map();
  const liveEvents = new Map();
  const pushedEvents = [];
  const removedLocalValues = [];
  const savedLocalValues = [];
  const scrollCalls = [];
  const timers = new Map();
  let nextTimerId = 1;

  const el = {
    classList: mutableClassList(),
    dataset: {
      feedName,
      hasNewer: String(hasNewer),
      resumeCursor: resumedCursor,
      savePosition: String(enabled),
    },
    contains(candidate) {
      return activities.includes(candidate);
    },
    querySelector(selector) {
      if (selector === ".fresh_hidden") {
        return activities.find((candidate) => candidate.classes?.has("fresh_hidden")) || null;
      }
      return null;
    },
    querySelectorAll(selector) {
      if (selector === ".activity_wrapper") return activities;
      if (selector === ".activity_wrapper:not(.hidden)") {
        return activities.filter((candidate) => !candidate.classes?.has("hidden"));
      }
      return [];
    },
  };

  const document = {
    getElementById(id) {
      return activities.find((candidate) => candidate.id === id) || null;
    },
  };

  const window = {
    innerHeight: 800,
    scrollY: initialScrollY,
    Bonfire: {
      getBonfireParam(namespace) {
        return namespace === "reading_offset" ? storedOffset : null;
      },
      removeBonfireParam(namespace, key) {
        removedLocalValues.push({ namespace, key });
      },
      setBonfireParam(namespace, key, value, ttl) {
        savedLocalValues.push({ namespace, key, value, ttl });
      },
    },
    addEventListener(name, handler) {
      listeners.set(name, handler);
    },
    removeEventListener(name, handler) {
      if (listeners.get(name) === handler) listeners.delete(name);
    },
    requestAnimationFrame(callback) {
      callback();
    },
    scrollTo({ top }) {
      // browsers clamp the scroll position at the top of the document
      this.scrollY = Math.max(0, top);
      scrollCalls.push(this.scrollY);
    },
  };

  const context = {
    clearTimeout(timerId) {
      timers.delete(timerId);
    },
    Date,
    document,
    Number,
    setTimeout(callback, delay) {
      const timerId = nextTimerId++;
      timers.set(timerId, { callback, delay });
      return timerId;
    },
    window,
  };
  context.globalThis = context;

  vm.runInNewContext(runnableSource(), context, { filename: hookUrl.pathname });

  const tracker = {
    ...context.__FeedScrollTracker,
    el,
    handleEvent(name, handler) {
      liveEvents.set(name, handler);
    },
    pushEventTo(target, name, params) {
      let resolveRequest;
      let rejectRequest;
      const request = new Promise((resolve, reject) => {
        resolveRequest = resolve;
        rejectRequest = reject;
      });

      pushedEvents.push({
        target,
        name,
        params,
        resolve(reply = {}) {
          resolveRequest([{ status: "fulfilled", value: { reply } }]);
        },
        reject(error = new Error("request failed")) {
          rejectRequest(error);
        },
      });

      return request;
    },
  };

  return {
    el,
    listeners,
    liveEvents,
    pushedEvents,
    removedLocalValues,
    savedLocalValues,
    scrollCalls,
    timers,
    tracker,
    window,
    prependActivities(...candidates) {
      activities.unshift(...candidates);
    },
    runTimer(timerId) {
      const timer = timers.get(timerId);
      timers.delete(timerId);
      timer?.callback();
    },
  };
}

test("only installs global listeners while reading-position tracking is enabled", () => {
  const disabled = loadTracker({ enabled: false });
  disabled.tracker.mounted();
  assert.deepEqual([...disabled.listeners.keys()], []);

  const enabled = loadTracker();
  enabled.tracker.mounted();
  assert.deepEqual([...enabled.listeners.keys()].sort(), ["bonfire:lifecycle:flush", "scroll"]);

  enabled.el.dataset.savePosition = "false";
  enabled.tracker.updated();
  assert.deepEqual([...enabled.listeners.keys()], []);
});

test("a clear event only resets the tracker for the matching feed", () => {
  const marker = "01KTEST0000000000000000000";
  const anchor = activity(marker, 120, 420);
  const state = loadTracker({ activities: [anchor], resumedCursor: marker });

  state.tracker.mounted();
  assert.equal(state.scrollCalls.length, 1);

  state.liveEvents.get("clear_reading_position")({ feed_name: "local" });
  assert.equal(state.tracker.restoredCursor, marker);
  assert.deepEqual(state.removedLocalValues, []);

  state.liveEvents.get("clear_reading_position")({ feed_name: "my" });
  assert.equal(state.tracker.restoredCursor, null);
  assert.deepEqual(
    state.removedLocalValues.map(({ namespace }) => namespace),
    ["reading_pos", "reading_offset"],
  );
});

test("can restore the same cursor again after it was cleared", () => {
  const marker = "01KTEST0000000000000000000";
  const anchor = activity(marker, 120, 420);
  const state = loadTracker({ activities: [anchor], resumedCursor: marker });

  state.tracker.mounted();
  state.liveEvents.get("clear_reading_position")({ feed_name: "my" });
  state.el.dataset.resumeCursor = marker;
  state.tracker.updated();

  assert.equal(state.scrollCalls.length, 2);
  assert.equal(state.tracker.restoredCursor, marker);
});

test("waits for upward scroll before loading newer entries after restoring", () => {
  const marker = "01KTEST0000000000000000000";
  const anchor = activity(marker, -100, 250);
  const state = loadTracker({
    activities: [anchor],
    hasNewer: true,
    initialScrollY: 1000,
    resumedCursor: marker,
    storedOffset: { cursor: marker, offset: -100 },
  });

  state.tracker.mounted();

  assert.equal(state.pushedEvents.some(({ name }) => name === "load_newer"), false);

  state.window.scrollY = 900;
  state.listeners.get("scroll")();

  assert.equal(state.pushedEvents.filter(({ name }) => name === "load_newer").length, 1);
});

test("loads newer entries immediately when restoring lands pinned at the top", () => {
  const marker = "01KTEST0000000000000000000";
  // Restore target clamps to 0 (stored offset larger than the marker's current
  // document position), so no upward-scroll event could ever fire.
  const anchor = activity(marker, 100, 400);
  const state = loadTracker({
    activities: [anchor],
    hasNewer: true,
    initialScrollY: 0,
    resumedCursor: marker,
    storedOffset: { cursor: marker, offset: 400 },
  });

  state.tracker.mounted();

  assert.equal(state.window.scrollY, 0);
  assert.equal(state.pushedEvents.filter(({ name }) => name === "load_newer").length, 1);
});

test("keeps loading newer pages after restore while the document stays unscrollable", async () => {
  const marker = "01KTEST0000000000000000000";
  const anchor = activity(marker, 100, 400);
  const state = loadTracker({
    activities: [anchor],
    hasNewer: true,
    initialScrollY: 0,
    resumedCursor: marker,
    storedOffset: { cursor: marker, offset: 400 },
  });

  state.tracker.mounted();

  const firstLoad = state.pushedEvents.find(({ name }) => name === "load_newer");
  assert.ok(firstLoad);

  // The inserted page is too short to give the viewport any scroll room: the
  // anchor's rect is unchanged, so the viewport stays pinned at the top.
  state.prependActivities(activity("01KNEWER100000000000000000", 0, 0, { hidden: true }));
  state.tracker.updated();
  firstLoad.resolve();
  await flushPromises();

  const minimumVisibilityTimer = [...state.timers].find(
    ([, { delay }]) => delay > 0 && delay <= 500,
  );
  assert.ok(minimumVisibilityTimer);
  state.runTimer(minimumVisibilityTimer[0]);

  assert.equal(state.pushedEvents.filter(({ name }) => name === "load_newer").length, 2);

  // Once the server reports nothing newer remains, the chain stops.
  const secondLoad = state.pushedEvents.filter(({ name }) => name === "load_newer")[1];
  state.el.dataset.hasNewer = "false";
  state.tracker.updated();
  secondLoad.resolve();
  await flushPromises();
  const nextTimer = [...state.timers].find(([, { delay }]) => delay > 0 && delay <= 500);
  assert.ok(nextTimer);
  state.runTimer(nextTimer[0]);

  assert.equal(state.pushedEvents.filter(({ name }) => name === "load_newer").length, 2);
});

test("saves the first visible activity and clears only at the true feed top", () => {
  const first = activity("01KFIRST000000000000000000", -100, 250);
  const second = activity("01KSECOND00000000000000000", 260, 610);
  const state = loadTracker({ activities: [first, second] });

  state.tracker.mounted();
  state.tracker.savePosition();

  assert.deepEqual(
    state.savedLocalValues.map(({ namespace }) => namespace),
    ["reading_pos", "reading_offset"],
  );
  assert.equal(state.pushedEvents[0].name, "Bonfire.Social.Feeds:reading_position_updated");
  assert.equal(state.pushedEvents[0].params.cursor, "01KFIRST000000000000000000");

  first.position.top = 0;
  first.position.bottom = 350;
  state.tracker.savePosition();

  assert.equal(state.pushedEvents[1].name, "Bonfire.Social.Feeds:reading_position_cleared");
  assert.equal(state.tracker.cleared, true);
});

test("keeps saving the reading position after hidden fresh activities are prepended", () => {
  const first = activity("01KFIRST000000000000000000", -100, 250);
  const second = activity("01KSECOND00000000000000000", 260, 610);
  const state = loadTracker({ activities: [first, second] });

  state.tracker.mounted();

  // A live-pushed activity lands at the top of the stream, hidden behind
  // the "show new activity" affordance (zero-size rect while display:none).
  state.prependActivities(
    activity("01KFRESH000000000000000000", 0, 0, { hidden: true, fresh: true }),
  );
  state.tracker.savePosition();

  assert.equal(state.pushedEvents[0]?.name, "Bonfire.Social.Feeds:reading_position_updated");
  assert.equal(state.pushedEvents[0]?.params.cursor, "01KFIRST000000000000000000");
  assert.equal(state.tracker.cleared, false);

  // Back at the true top, hidden fresh entries must block clearing (they are
  // newer content the user has not seen yet) without breaking future saves.
  first.position.top = 0;
  first.position.bottom = 350;
  state.tracker.savePosition();

  assert.equal(
    state.pushedEvents.some(({ name }) => name === "Bonfire.Social.Feeds:reading_position_cleared"),
    false,
  );
  assert.equal(state.tracker.cleared, false);
});

test("preloads consecutive newer pages and ignores unrelated updates until each request resolves", async () => {
  const firstLoaded = activity("01KFIRST000000000000000000", -1100, -700);
  const visibleAnchor = activity("01KVISIBLE0000000000000000", 100, 400);
  const state = loadTracker({
    activities: [firstLoaded, visibleAnchor],
    hasNewer: true,
    initialScrollY: 2000,
  });

  state.tracker.mounted();
  state.window.scrollY = 1900;
  state.listeners.get("scroll")();

  const loadEvent = state.pushedEvents.find(({ name }) => name === "load_newer");
  assert.ok(loadEvent);
  assert.equal(state.el.classList.contains("feed-newer-loading"), true);

  state.window.scrollY = 1800;
  state.listeners.get("scroll")();
  assert.equal(state.pushedEvents.filter(({ name }) => name === "load_newer").length, 1);

  // A generic LiveView update must not complete the in-flight request.
  state.tracker.updated();
  assert.ok(state.tracker.newerAnchor);
  assert.equal(state.scrollCalls.length, 0);

  const newerFirst = activity("01KNEWER100000000000000000", -700, -400);
  const newerSecond = activity("01KNEWER200000000000000000", -390, -100);
  state.prependActivities(newerFirst, newerSecond);
  visibleAnchor.position.top = 500;
  visibleAnchor.position.bottom = 800;
  state.tracker.updated();
  assert.equal(state.scrollCalls.length, 0);

  loadEvent.resolve();
  await flushPromises();

  assert.deepEqual(
    state.el.querySelectorAll(".activity_wrapper").map(({ id }) => id),
    [newerFirst.id, newerSecond.id, firstLoaded.id, visibleAnchor.id],
  );
  assert.equal(state.scrollCalls.at(-1), 2200);

  assert.equal(state.el.classList.contains("feed-newer-loading"), true);

  const minimumVisibilityTimer = [...state.timers].find(
    ([, { delay }]) => delay > 0 && delay <= 500,
  );
  assert.ok(minimumVisibilityTimer);
  state.runTimer(minimumVisibilityTimer[0]);
  assert.equal(state.el.classList.contains("feed-newer-loading"), false);

  state.window.scrollY = 2100;
  state.listeners.get("scroll")();
  const secondLoadEvent = state.pushedEvents.filter(({ name }) => name === "load_newer")[1];
  assert.ok(secondLoadEvent);

  const newestFirst = activity("01KNEWEST10000000000000000", -700, -400);
  const newestSecond = activity("01KNEWEST20000000000000000", -390, -100);
  state.prependActivities(newestFirst, newestSecond);
  visibleAnchor.position.top = 700;
  visibleAnchor.position.bottom = 1000;
  state.el.dataset.hasNewer = "false";
  state.tracker.updated();
  secondLoadEvent.resolve();
  await flushPromises();

  assert.deepEqual(
    state.el.querySelectorAll(".activity_wrapper").map(({ id }) => id),
    [
      newestFirst.id,
      newestSecond.id,
      newerFirst.id,
      newerSecond.id,
      firstLoaded.id,
      visibleAnchor.id,
    ],
  );
  assert.equal(state.scrollCalls.at(-1), 2300);
});

test("clears the loading state when the newer-page request fails", async () => {
  const firstLoaded = activity("01KFIRST000000000000000000", -700, -400);
  const visibleAnchor = activity("01KVISIBLE0000000000000000", 100, 400);
  const state = loadTracker({
    activities: [firstLoaded, visibleAnchor],
    hasNewer: true,
    initialScrollY: 2000,
  });

  state.tracker.mounted();
  state.window.scrollY = 1900;
  state.listeners.get("scroll")();

  const loadEvent = state.pushedEvents.find(({ name }) => name === "load_newer");
  loadEvent.reject();
  await flushPromises();

  assert.equal(state.tracker.loadingNewer, false);
  assert.equal(state.el.classList.contains("feed-newer-loading"), false);
  assert.equal(state.tracker.newerAnchor, null);
});

test("does not preload before the threshold or when no newer page remains", () => {
  const firstLoaded = activity("01KFIRST000000000000000000", -1300, -900);
  const visibleAnchor = activity("01KVISIBLE0000000000000000", 100, 400);
  const state = loadTracker({
    activities: [firstLoaded, visibleAnchor],
    hasNewer: true,
    initialScrollY: 2000,
  });

  state.tracker.mounted();
  state.window.scrollY = 1900;
  state.listeners.get("scroll")();
  assert.equal(state.pushedEvents.some(({ name }) => name === "load_newer"), false);

  firstLoaded.position.bottom = -700;
  state.el.dataset.hasNewer = "false";
  state.window.scrollY = 1800;
  state.listeners.get("scroll")();
  assert.equal(state.pushedEvents.some(({ name }) => name === "load_newer"), false);
});

function loadJumpToTop({ initialScrollY = 0, reducedMotion = null } = {}) {
  const listeners = new Map();
  const elementListeners = new Map();
  const scrollCalls = [];
  // frames are driven by the test with explicit timestamps, so the scroll animation is
  // deterministic instead of racing a real clock
  const frames = new Map();
  let lastFrameId = 0;

  const el = {
    classList: mutableClassList(),
    inert: true,
    tabIndex: -1,
    addEventListener(name, handler) {
      elementListeners.set(name, handler);
    },
    removeEventListener(name, handler) {
      if (elementListeners.get(name) === handler) elementListeners.delete(name);
    },
  };

  const window = {
    innerHeight: 800,
    scrollY: initialScrollY,
    addEventListener(name, handler) {
      listeners.set(name, handler);
    },
    removeEventListener(name, handler) {
      if (listeners.get(name) === handler) listeners.delete(name);
    },
    cancelAnimationFrame(id) {
      frames.delete(id);
    },
    requestAnimationFrame(callback) {
      frames.set(++lastFrameId, callback);
      return lastFrameId;
    },
    scrollTo({ top }) {
      this.scrollY = Math.max(0, top);
      scrollCalls.push(this.scrollY);
      // browsers fire scroll events for programmatic scrolling too
      listeners.get("scroll")?.();
    },
  };

  // left undefined unless the test asks for it, so the no-matchMedia fallback gets exercised
  if (reducedMotion !== null) {
    window.matchMedia = () => ({ matches: reducedMotion });
  }

  const context = {
    clearTimeout() {},
    Date,
    document: { getElementById: () => null },
    Number,
    setTimeout() {},
    window,
  };
  context.globalThis = context;

  vm.runInNewContext(runnableSource(), context, { filename: hookUrl.pathname });

  return {
    el,
    elementListeners,
    listeners,
    scrollCalls,
    window,
    hook: { ...context.__FeedJumpToTop, el },
    pendingFrames: () => frames.size,
    runFrame(timestamp) {
      const [id, callback] = frames.entries().next().value ?? [];
      if (id === undefined) return;

      frames.delete(id);
      callback(timestamp);
    },
  };
}

test("the jump-to-top shortcut shows once scrolled past the opening viewport", () => {
  // the fake window is 800px tall
  const state = loadJumpToTop();

  state.hook.mounted();
  assert.equal(state.el.classList.contains("feed-jump-visible"), false);

  state.window.scrollY = 700;
  state.listeners.get("scroll")();
  assert.equal(state.el.classList.contains("feed-jump-visible"), false);

  state.window.scrollY = 900;
  state.listeners.get("scroll")();
  assert.equal(state.el.classList.contains("feed-jump-visible"), true);

  state.window.scrollY = 120;
  state.listeners.get("scroll")();
  assert.equal(state.el.classList.contains("feed-jump-visible"), false);
});

test("the jump-to-top shortcut leaves the tab order while it is invisible", () => {
  const state = loadJumpToTop();

  state.hook.mounted();
  assert.equal(state.el.inert, true);
  assert.equal(state.el.tabIndex, -1);

  state.window.scrollY = 900;
  state.listeners.get("scroll")();
  assert.equal(state.el.inert, false);
  assert.equal(state.el.tabIndex, 0);

  state.window.scrollY = 0;
  state.listeners.get("scroll")();
  assert.equal(state.el.inert, true);
  assert.equal(state.el.tabIndex, -1);
});

test("clicking the jump-to-top shortcut eases the page back to the top", () => {
  const state = loadJumpToTop({ initialScrollY: 4000 });

  state.hook.mounted();
  assert.equal(state.el.classList.contains("feed-jump-visible"), true);

  state.elementListeners.get("click")();
  assert.deepEqual(state.scrollCalls, [], "the animation waits for the first frame");

  state.runFrame(1000);
  assert.equal(state.window.scrollY, 4000, "the first frame starts the clock, it doesn't jump");

  // ease-out: most of the distance is covered in the first half of the animation
  state.runFrame(1225);
  assert.ok(state.window.scrollY < 4000 / 2, `covered less than half: ${state.window.scrollY}`);

  state.runFrame(1450);
  assert.equal(state.window.scrollY, 0);
  assert.equal(state.pendingFrames(), 0, "the animation stops once it arrives");
  // it faded out on the way up, from the scroll events its own animation emits
  assert.equal(state.el.classList.contains("feed-jump-visible"), false);
});

test("the scroll animation gives way as soon as the reader scrolls against it", () => {
  const state = loadJumpToTop({ initialScrollY: 4000 });

  state.hook.mounted();
  state.elementListeners.get("click")();
  state.runFrame(1000);
  state.runFrame(1100);

  const interrupted = state.window.scrollY;
  // the reader flicks the page themselves mid-animation
  state.window.scrollY = interrupted + 500;
  state.runFrame(1200);

  assert.equal(state.window.scrollY, interrupted + 500, "the animation let go");
  assert.equal(state.pendingFrames(), 0, "and stopped asking for frames");
});

test("the jump-to-top shortcut skips the animation under reduced motion", () => {
  const state = loadJumpToTop({ initialScrollY: 4000, reducedMotion: true });

  state.hook.mounted();
  state.elementListeners.get("click")();

  assert.deepEqual(state.scrollCalls, [0]);
  assert.equal(state.pendingFrames(), 0, "no animation was scheduled");
});

test("the jump-to-top shortcut does nothing when already at the top", () => {
  const state = loadJumpToTop();

  state.hook.mounted();
  state.elementListeners.get("click")();

  assert.deepEqual(state.scrollCalls, []);
  assert.equal(state.pendingFrames(), 0);
});

test("the jump-to-top shortcut drops its listeners and pending frames when destroyed", () => {
  const state = loadJumpToTop({ initialScrollY: 4000 });

  state.hook.mounted();
  assert.deepEqual([...state.listeners.keys()], ["scroll"]);
  assert.deepEqual([...state.elementListeners.keys()], ["click"]);

  state.elementListeners.get("click")();
  assert.equal(state.pendingFrames(), 1);

  state.hook.destroyed();
  assert.deepEqual([...state.listeners.keys()], []);
  assert.deepEqual([...state.elementListeners.keys()], []);
  // a queued frame would scroll a page this hook no longer belongs to
  assert.equal(state.pendingFrames(), 0);
});
