let FeedScrollTracker = {
  mounted() {

    this.feedName = this.el.dataset.feedName;
    this.enabled = this.el.hasAttribute("data-save-position");
    this.ttl = parseInt(this.el.dataset.positionTtl, 10) || 172800000;

    console.log("[FeedScrollTracker] mounted, feedName=" + this.feedName + " enabled=" + this.enabled);

    this.saveTimer = null;
    this.hasScrolled = false;
    this.initialSaved = false;
    this.previousID = null;

    // Server tells us to clear the reading position (on resume or jump to newest)
    this.handleEvent("clear_reading_position", ({ feed_name }) => {
      console.log("[FeedScrollTracker] clearing " + feed_name);
      window.Bonfire.removeBonfireParam("reading_pos", feed_name);
      this.hasScrolled = false;
      clearTimeout(this.saveTimer);
    });

    // Only track position for named feeds with standard presets (no filters/custom sort)
    if (!this.enabled || !this.feedName) return;

    // Save position on scroll (debounced)
    this.scrollHandler = () => {
      this.hasScrolled = true;
      this.debouncedSave();
    };
    window.addEventListener("scroll", this.scrollHandler, { passive: true });
  },

  updated() {
    const newFeedName = this.el.dataset.feedName; 
    if (!this.enabled || !newFeedName) return;
    if (newFeedName && newFeedName !== this.feedName) {
      console.log("[FeedScrollTracker] switched feed: " + newFeedName);
      this.feedName = newFeedName;
      this.hasScrolled = false;
      this.initialSaved = false;
    }
    // Save initial position once items are in the DOM
    if (!this.initialSaved && this.el.querySelector(".activity_wrapper")) {
      this.initialSaved = true;
      this.debouncedSave();
    }
  },

  // Collect activity elements currently visible in the viewport.
  // Returns { items, isTop } where:
  //   items  – element refs for visible activities (used by savePosition to pick the cursor)
  //   isTop  – true when no activities are scrolled above the viewport,
  //            meaning the user is viewing the very beginning of the feed
  findVisible() {
    const items = [];
    const viewportBottom = window.innerHeight;
    let isTop = true;
    for (const el of this.el.querySelectorAll(".activity_wrapper")) {
      const top = el.getBoundingClientRect().top;
      // Activities scrolled above viewport (small tolerance for partial pixels)
      if (top < -10) { isTop = false; continue; }
      // Past the bottom edge — remaining items are off-screen, stop early
      if (top > viewportBottom) break;
      if (el.id) items.push(el);
    }
    return { items, isTop };
  },

  savePosition() {
    if (!this.feedName) return;
    const { items, isTop } = this.findVisible();
    if (!items.length) return;
    // If viewing from the very top of the feed, skip first item
    // so resuming always has newer items above the cursor
    const idx = isTop ? Math.min(1, items.length - 1) : 0;
    const id = items[idx].id.replace(/^fa_/, "");
    if (id && id != this.previousID) {
      console.log("[FeedScrollTracker] saving position for " + this.feedName + ": " + id);
      window.Bonfire.setBonfireParam("reading_pos", this.feedName, id, this.ttl);
      // Also push to server so it's fresh on live navigations (because connect_params only sends positions on initial socket connect)
      this.pushEvent("Bonfire.Social.Feeds:reading_position_updated", { feed_name: this.feedName, cursor: id });
      this.previousID = id;
    }
  },

  debouncedSave() {
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => this.savePosition(), 1000);
  },

  destroyed() {
    clearTimeout(this.saveTimer);
    if (this.hasScrolled) this.savePosition();
    if (this.scrollHandler) window.removeEventListener("scroll", this.scrollHandler);
  },
};

export { FeedScrollTracker };
