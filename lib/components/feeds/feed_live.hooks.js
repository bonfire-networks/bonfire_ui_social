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
// ease-out-quart: leaves immediately (so the tap feels answered) and settles softly at the top
const easeOutQuart = (progress) => 1 - Math.pow(1 - progress, 4);
const READING_POSITION_NAMESPACE = "reading_pos";
const READING_OFFSET_NAMESPACE = "reading_offset";

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
    const oldEnabled = this.enabled;
    const oldResumedCursor = this.resumedCursor;

    this.readState();

    if (!this.shouldTrack()) {
      clearTimeout(this.saveTimer);
      this.hasScrolled = false;
      this.cancelNewerLoading();
      this.syncHandlers();
      return;
    }

    if (!oldEnabled || oldFeedName !== this.feedName) {
      this.hasScrolled = false;
      this.cleared = false;
      this.restoredCursor = null;
      this.cancelNewerLoading();
    }

    if (oldResumedCursor !== this.resumedCursor) this.restoredCursor = null;

    this.syncHandlers();
    if (this.loadingNewer) {
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

  syncHandlers() {
    if (this.shouldTrack()) {
      this.attachScrollHandler();
      this.attachLifecycleHandlers();
    } else {
      this.detachScrollHandler();
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
    if (!this.shouldTrack() || !this.hasNewer || this.loadingNewer || this.restoring) {
      return;
    }

    const firstActivity = this.renderedActivities()[0];
    if (!firstActivity) return;

    const prefetchBoundary = -window.innerHeight * NEWER_PREFETCH_VIEWPORTS;
    if (firstActivity.getBoundingClientRect().bottom < prefetchBoundary) return;

    const anchor = this.findVisible().items[0];
    if (!anchor) return;

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
    if (!this.loadingNewer || requestID !== this.activeNewerRequestID) return;

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

    // If the inserted page still doesn't make the document scrollable, the
    // viewport stays pinned at the top and no upward-scroll event can request
    // the next page — keep loading until there's scroll room or nothing newer
    // remains. Double rAF so the anchor-restore scroll has settled first.
    window.requestAnimationFrame(() =>
      window.requestAnimationFrame(() => {
        if (window.scrollY <= 0) this.maybeLoadNewer();
      }),
    );
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
      !this.shouldTrack() ||
      !this.resumedCursor ||
      this.restoredCursor === this.resumedCursor
    ) {
      return;
    }

    const anchor = document.getElementById(`fa_${this.resumedCursor}`);
    if (!anchor || !this.el.contains(anchor)) return;

    const stored = window.Bonfire?.getBonfireParam?.(
      READING_OFFSET_NAMESPACE,
      this.feedName
    );
    const offset =
      stored?.cursor === this.resumedCursor && Number.isFinite(stored.offset)
        ? stored.offset
        : 0;

    this.restoredCursor = this.resumedCursor;
    this.previousID = this.resumedCursor;
    this.restoring = true;

    window.requestAnimationFrame(() => {
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
    });
  },

  debouncedSave() {
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => this.savePosition(), 1000);
  },

  destroyed() {
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

    let startedAt = null;
    // the reader can always overrule the animation: if the page moved anywhere we didn't put
    // it (a flick-scroll, a jump to an anchor), stop rather than yanking them back
    let expected = from;

    const step = (now) => {
      if (Math.abs(window.scrollY - expected) > 1) return this.cancelScroll();
      if (startedAt === null) startedAt = now;

      const progress = Math.min(1, (now - startedAt) / JUMP_SCROLL_MS);
      expected = Math.round(from * (1 - easeOutQuart(progress)));
      window.scrollTo({ top: expected, behavior: "auto" });

      this.scrollFrame =
        progress < 1 ? window.requestAnimationFrame(step) : null;
    };

    this.scrollFrame = window.requestAnimationFrame(step);
  },

  cancelScroll() {
    if (this.scrollFrame) window.cancelAnimationFrame(this.scrollFrame);
    this.scrollFrame = null;
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
