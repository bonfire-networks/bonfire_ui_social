const LOCAL_READING_POSITION_TTL_MS = 30 * 60 * 1000;
const LIFECYCLE_FLUSH_EVENT = "bonfire:lifecycle:flush";
const NEWER_LOADING_CLASS = "feed-newer-loading";
const NEWER_LOADING_MIN_MS = 500;
const NEWER_PREFETCH_VIEWPORTS = 1;
const JUMP_VISIBLE_CLASS = "feed-jump-visible";
// one viewport: the shortcut appears as soon as the activities the feed opened on are gone
const JUMP_VISIBLE_THRESHOLD_VIEWPORTS = 1;
// fixed duration whatever the distance — the native "smooth" behaviour crawls down long feeds
const JUMP_SCROLL_MS = 450;
// the reader's own input overrules the jump-to-top animation (see `scrollToTop`)
const JUMP_INTERRUPT_EVENTS = ["wheel", "touchstart", "keydown"];
// ease-out-quart: leaves immediately (so the tap feels answered) and settles softly at the top
const easeOutQuart = (progress) => 1 - Math.pow(1 - progress, 4);
const READING_POSITION_NAMESPACE = "reading_pos";
const READING_OFFSET_NAMESPACE = "reading_offset";

// What a rejoin needs to bring each feed back in the join itself instead of empty (LiveView clears streamed entries on every join): the feeds on the page and the post each shows, with its offset. Page memory only: a rejoin is this same page, a reload starts over.
const mountedTrackers = new Set();
const rejoinPositions = {};

// Read by bonfire_live.js for every join's params, so the place is the one at the reconnect, not at the drop. Sent on every join: the server uses it only when `_mounts` > 0 (a rejoin), so no client-side "socket dropped" flag is needed, which LiveView's `disconnected` callback could not reliably provide (skipped while the page counts as unloading). A feed at its top maps to "": its first page is the right one.
function feedRejoinParams() {
  const feeds = {};

  for (const tracker of mountedTrackers) {
    if (!tracker.feedName) continue;

    const { items, isTop } = tracker.findVisible();
    if (isTop || !items.length) {
      feeds[tracker.feedName] = "";
      delete rejoinPositions[tracker.feedName];
      continue;
    }

    const cursor = items[0].id.replace(/^fa_/, "");
    rejoinPositions[tracker.feedName] = { cursor, offset: items[0].getBoundingClientRect().top };
    feeds[tracker.feedName] = cursor;
  }

  return Object.keys(feeds).length ? { feed_rejoin: feeds } : {};
}

window.Bonfire = Object.assign(window.Bonfire || {}, { feedRejoinParams });

let FeedScrollTracker = {
  mounted() {
    this.saveTimer = null;
    this.hasScrolled = false;
    this.cleared = false;
    this.previousID = null;
    this.restoredCursor = null;
    this.restoring = false;
    this.loadingNewer = false;
    this.loadingNewerStartedAt = null;
    this.newerRequestSequence = 0;
    this.activeNewerRequestID = null;
    this.newerAnchor = null;
    this.lastScrollY = window.scrollY;
    mountedTrackers.add(this);
    this.readState();

    this.handleEvent("clear_reading_position", ({ feed_name }) => {
      if (feed_name && feed_name !== this.feedName) return;

      this.hasScrolled = false;
      this.cleared = true;
      this.resumedCursor = null;
      this.restoredCursor = null;
      clearTimeout(this.saveTimer);
      this.cancelNewerLoading();
      this.forgetLocalPosition(feed_name || this.feedName);
    });

    // LiveView can update data-save-position after hook mount.
    this.syncHandlers();
    this.restorePosition();
  },

  updated() {
    const oldFeedName = this.feedName;
    const oldResumable = this.shouldResume();
    const oldResumedCursor = this.resumedCursor;

    this.readState();

    if (!this.shouldResume()) {
      clearTimeout(this.saveTimer);
      this.hasScrolled = false;
      this.cancelNewerLoading();
      this.syncHandlers();
      return;
    }

    if (!oldResumable || oldFeedName !== this.feedName) {
      this.hasScrolled = false;
      this.cleared = false;
      this.restoredCursor = null;
      this.cancelNewerLoading();
    }

    if (oldResumedCursor !== this.resumedCursor) this.restoredCursor = null;

    this.syncHandlers();
    if (this.activeNewerRequestID !== null) {
      this.setNewerLoading(true);
    }
    this.restorePosition();

    if (this.hasScrolled && !this.hasNewer) this.debouncedSave();
  },

  readState() {
    this.feedName = this.el.dataset.feedName;
    this.enabled = this.el.dataset.savePosition === "true";
    this.resumedCursor = this.el.dataset.resumeCursor || null;
    this.hasNewer = this.el.dataset.hasNewer === "true";
  },

  shouldTrack() {
    return this.enabled && this.feedName;
  },

  // Restoring a resumed position and loading the activities above it, without saving anything: also on feeds that don't save positions, once a reconnect resumed them (the server sends a resume cursor to those only then).
  shouldResume() {
    return !!this.feedName && (this.enabled || !!this.resumedCursor || this.hasNewer);
  },

  syncHandlers() {
    if (this.shouldResume()) {
      this.attachScrollHandler();
    } else {
      this.detachScrollHandler();
    }

    if (this.shouldTrack()) {
      this.attachLifecycleHandlers();
    } else {
      this.detachLifecycleHandlers();
    }
  },

  attachScrollHandler() {
    if (this.scrollHandler) return;

    this.scrollHandler = () => {
      if (this.restoring) return;

      const currentScrollY = window.scrollY;
      const scrollingUp = currentScrollY < this.lastScrollY;
      this.lastScrollY = currentScrollY;
      this.hasScrolled = true;
      this.cleared = false;
      this.debouncedSave();

      if (scrollingUp) this.maybeLoadNewer();
    };

    window.addEventListener("scroll", this.scrollHandler, { passive: true });
  },

  detachScrollHandler() {
    if (!this.scrollHandler) return;

    window.removeEventListener("scroll", this.scrollHandler);
    this.scrollHandler = null;
  },

  attachLifecycleHandlers() {
    if (this.lifecycleFlushHandler) return;

    this.lifecycleFlushHandler = () => this.savePosition();

    window.addEventListener(LIFECYCLE_FLUSH_EVENT, this.lifecycleFlushHandler);
  },

  detachLifecycleHandlers() {
    if (this.lifecycleFlushHandler) {
      window.removeEventListener(LIFECYCLE_FLUSH_EVENT, this.lifecycleFlushHandler);
      this.lifecycleFlushHandler = null;
    }
  },

  // Hidden entries (`fresh_hidden`/`infinite_scroll_hidden` carry `hidden`) have
  // zero-size rects, which would make the first stream child always look like
  // the viewport top — so position math only ever considers rendered entries.
  renderedActivities() {
    return [...this.el.querySelectorAll(".activity_wrapper:not(.hidden)")];
  },

  findVisible() {
    const items = [];
    const viewportBottom = window.innerHeight;
    const activities = this.renderedActivities();
    const firstActivity = activities[0];
    const isTop =
      !firstActivity || firstActivity.getBoundingClientRect().top >= -10;

    for (const el of activities) {
      const rect = el.getBoundingClientRect();
      if (rect.bottom <= 0) continue;
      if (rect.top > viewportBottom) break;
      if (el.id) items.push(el);
    }

    return { items, isTop };
  },

  maybeLoadNewer() {
    this.readState();
    if (!this.shouldResume() || !this.hasNewer || this.loadingNewer || this.restoring) {
      return;
    }

    const firstActivity = this.renderedActivities()[0];
    if (!firstActivity) return;

    const prefetchBoundary = -window.innerHeight * NEWER_PREFETCH_VIEWPORTS;
    if (firstActivity.getBoundingClientRect().bottom < prefetchBoundary) return;

    const anchor = this.findVisible().items[0];
    if (!anchor) return;

    clearTimeout(this.loadingNewerTimer);
    this.loadingNewerTimer = null;
    this.loadingNewer = true;
    this.loadingNewerStartedAt = Date.now();
    const requestID = ++this.newerRequestSequence;
    this.activeNewerRequestID = requestID;
    this.newerAnchor = {
      id: anchor.id,
      top: anchor.getBoundingClientRect().top,
    };
    this.setNewerLoading(true);

    this.pushEventTo(this.el, "load_newer", {})
      .then((results) => {
        if (requestID !== this.activeNewerRequestID) return;

        if (results.some(({ status }) => status === "fulfilled")) {
          this.restoreNewerAnchor(requestID);
          this.finishNewerLoading(false, requestID);
          // A short page can leave no upward scroll room; continue after anchor restoration, independently of the indicator timer.
          window.requestAnimationFrame(() =>
            window.requestAnimationFrame(() => {
              if (window.scrollY <= 0) this.maybeLoadNewer();
            }),
          );
        } else {
          this.cancelNewerLoading(requestID);
        }
      })
      .catch(() => this.cancelNewerLoading(requestID));
  },

  restoreNewerAnchor(requestID) {
    if (requestID !== this.activeNewerRequestID) return;

    const savedAnchor = this.newerAnchor;
    if (!savedAnchor) return;

    const anchor = document.getElementById(savedAnchor.id);
    this.newerAnchor = null;
    if (!anchor || !this.el.contains(anchor)) return;

    this.restoring = true;
    window.requestAnimationFrame(() => {
      const delta = anchor.getBoundingClientRect().top - savedAnchor.top;
      if (Math.abs(delta) > 0.5) {
        window.scrollTo({ top: window.scrollY + delta, behavior: "auto" });
      }

      window.requestAnimationFrame(() => {
        this.restoring = false;
        this.lastScrollY = window.scrollY;
      });
    });
  },

  setNewerLoading(loading) {
    this.el.classList.toggle(NEWER_LOADING_CLASS, loading);
  },

  finishNewerLoading(force = false, requestID = this.activeNewerRequestID) {
    if (requestID !== this.activeNewerRequestID) return;

    this.loadingNewer = false; // The indicator's minimum duration must not delay another page request.

    const elapsed = Date.now() - this.loadingNewerStartedAt;
    const remaining = NEWER_LOADING_MIN_MS - elapsed;

    if (!force && remaining > 0) {
      clearTimeout(this.loadingNewerTimer);
      this.loadingNewerTimer = setTimeout(
        () => this.finishNewerLoading(true, requestID),
        remaining,
      );
      return;
    }

    clearTimeout(this.loadingNewerTimer);
    this.loadingNewer = false;
    this.loadingNewerStartedAt = null;
    this.loadingNewerTimer = null;
    this.activeNewerRequestID = null;
    this.newerAnchor = null;
    this.setNewerLoading(false);
  },

  cancelNewerLoading(requestID = this.activeNewerRequestID) {
    if (requestID !== this.activeNewerRequestID) return;

    clearTimeout(this.loadingNewerTimer);
    this.loadingNewer = false;
    this.loadingNewerStartedAt = null;
    this.loadingNewerTimer = null;
    this.activeNewerRequestID = null;
    this.newerAnchor = null;
    this.setNewerLoading(false);
  },

  savePosition() {
    if (this.restoring) return;
    this.readState();
    if (!this.shouldTrack() || this.cleared) return;
    const { items, isTop } = this.findVisible();
    if (!items.length) return;

    if (isTop) {
      if (
        !this.hasNewer &&
        !this.el.querySelector(".fresh_hidden") &&
        (this.resumedCursor || this.previousID)
      ) {
        this.clearPosition();
      }
      return;
    }

    const anchor = items[0];
    const id = anchor.id.replace(/^fa_/, "");
    this.rememberLocalPosition(this.feedName, id, anchor.getBoundingClientRect().top);

    if (id && id != this.previousID) {
      this.pushEventTo(this.el, "Bonfire.Social.Feeds:reading_position_updated", {
        feed_name: this.feedName,
        cursor: id,
      });
      this.previousID = id;
    }
  },

  clearPosition() {
    this.forgetLocalPosition(this.feedName);
    this.pushEventTo(this.el, "Bonfire.Social.Feeds:reading_position_cleared", {
      feed_name: this.feedName,
    });
    this.previousID = null;
    this.resumedCursor = null;
    this.restoredCursor = null;
    this.el.dataset.resumeCursor = "";
    this.cleared = true;
  },

  rememberLocalPosition(feedName, cursor, offset) {
    // bonfire_live.js exposes this before LiveView hooks mount; the guard keeps HMR safe.
    if (!feedName || !cursor || !window.Bonfire?.setBonfireParam) return;
    window.Bonfire.setBonfireParam(
      READING_POSITION_NAMESPACE,
      feedName,
      cursor,
      LOCAL_READING_POSITION_TTL_MS
    );
    window.Bonfire.setBonfireParam(
      READING_OFFSET_NAMESPACE,
      feedName,
      { cursor, offset },
      LOCAL_READING_POSITION_TTL_MS
    );
  },

  forgetLocalPosition(feedName) {
    if (!feedName || !window.Bonfire?.removeBonfireParam) return;
    window.Bonfire.removeBonfireParam(READING_POSITION_NAMESPACE, feedName);
    window.Bonfire.removeBonfireParam(READING_OFFSET_NAMESPACE, feedName);
  },

  restorePosition() {
    if (
      !this.shouldResume() ||
      !this.resumedCursor ||
      this.restoredCursor === this.resumedCursor
    ) {
      return;
    }

    const anchor = document.getElementById(`fa_${this.resumedCursor}`);
    if (!anchor || !this.el.contains(anchor)) return;

    // a reconnect's own record wins, used once; otherwise the saved reading offset
    const rejoined = rejoinPositions[this.feedName]?.cursor === this.resumedCursor;
    const stored = rejoined
      ? rejoinPositions[this.feedName]
      : window.Bonfire?.getBonfireParam?.(READING_OFFSET_NAMESPACE, this.feedName);
    if (rejoined) delete rejoinPositions[this.feedName];
    const offset =
      stored?.cursor === this.resumedCursor && Number.isFinite(stored.offset)
        ? stored.offset
        : 0;

    this.restoredCursor = this.resumedCursor;
    this.previousID = this.resumedCursor;
    this.restoring = true;

    const scrollToAnchor = () => {
      const delta = anchor.getBoundingClientRect().top - offset;
      window.scrollTo({ top: window.scrollY + delta, behavior: "auto" });

      window.requestAnimationFrame(() => {
        this.restoring = false;
        this.lastScrollY = window.scrollY;
        // Newer entries normally load on the first upward scroll, but a restore
        // that lands pinned at the absolute top (short restored window, or the
        // scroll target clamped to 0) can never produce an upward-scroll event,
        // which would strand the newer side of the feed.
        if (window.scrollY <= 0) this.maybeLoadNewer();
      });
    };

    // After a rejoin the new page is already on screen at the old scroll offset, so waiting a frame shows other posts first: scroll in this same task, before the browser paints. A marker restore on first load keeps waiting for layout.
    if (rejoined) scrollToAnchor();
    else window.requestAnimationFrame(scrollToAnchor);
  },

  debouncedSave() {
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => this.savePosition(), 1000);
  },

  destroyed() {
    mountedTrackers.delete(this);
    clearTimeout(this.saveTimer);
    this.cancelNewerLoading();
    if (this.hasScrolled && !this.cleared) this.savePosition();
    this.detachScrollHandler();
    this.detachLifecycleHandlers();
  },
};

// Floating shortcut back to the newest activities. The server decides whether there IS newer
// content (so the button only exists then); this only decides whether the reader has scrolled
// far enough away from the top for the shortcut to be worth showing.
let FeedJumpToTop = {
  mounted() {
    this.scrollHandler = () => this.syncVisibility();

    this.clickHandler = () => this.scrollToTop();

    window.addEventListener("scroll", this.scrollHandler, { passive: true });
    this.el.addEventListener("click", this.clickHandler);
    this.syncVisibility();
  },

  updated() {
    this.syncVisibility();
  },

  scrollToTop() {
    const from = window.scrollY;
    if (from <= 0) return;

    if (this.prefersReducedMotion()) {
      window.scrollTo({ top: 0, behavior: "auto" });
      return;
    }

    this.cancelScroll();
    // scroll anchoring moves scrollY too, so position can't tell the reader from the page: the reader's own input is what overrules the animation
    this.inputHandler = () => this.cancelScroll();
    for (const name of JUMP_INTERRUPT_EVENTS)
      window.addEventListener(name, this.inputHandler, { passive: true });
    let startedAt = null;

    const step = (now) => {
      if (startedAt === null) startedAt = now;

      const progress = Math.min(1, (now - startedAt) / JUMP_SCROLL_MS);
      // the click's own side effects (revealing fresh entries, a feed reload) can shift the
      // page mid-animation via scroll anchoring — so take the smaller of the live position
      // and the planned one (never pushing the reader back down) and always land on 0
      const target =
        progress < 1
          ? Math.min(
              window.scrollY,
              Math.round(from * (1 - easeOutQuart(progress))),
            )
          : 0;
      window.scrollTo({ top: target, behavior: "auto" });

      if (progress < 1) this.scrollFrame = window.requestAnimationFrame(step);
      else this.cancelScroll();
    };

    this.scrollFrame = window.requestAnimationFrame(step);
  },

  cancelScroll() {
    if (this.scrollFrame) window.cancelAnimationFrame(this.scrollFrame);
    this.scrollFrame = null;
    if (this.inputHandler)
      for (const name of JUMP_INTERRUPT_EVENTS)
        window.removeEventListener(name, this.inputHandler);
    this.inputHandler = null;
  },

  prefersReducedMotion() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches === true;
  },

  syncVisibility() {
    const visible =
      window.scrollY > window.innerHeight * JUMP_VISIBLE_THRESHOLD_VIEWPORTS;

    this.el.classList.toggle(JUMP_VISIBLE_CLASS, visible);
    // it is only hidden by opacity, so it also has to leave the tab order and the a11y tree
    // (the markup ships inert, which is what keeps it out of reach without JS too)
    this.el.inert = !visible;
    this.el.tabIndex = visible ? 0 : -1;
  },

  destroyed() {
    this.cancelScroll();
    window.removeEventListener("scroll", this.scrollHandler);
    this.el.removeEventListener("click", this.clickHandler);
  },
};

export { FeedScrollTracker, FeedJumpToTop };
