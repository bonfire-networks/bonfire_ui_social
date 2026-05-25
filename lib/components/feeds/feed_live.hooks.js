let FeedScrollTracker = {
  mounted() {
    this.readState();

    this.saveTimer = null;
    this.hasScrolled = false;
    this.cleared = false;
    this.previousID = null;

    this.handleEvent("clear_reading_position", () => {
      this.hasScrolled = false;
      this.cleared = true;
      clearTimeout(this.saveTimer);
    });

    // LiveView can update data-save-position after hook mount.
    this.attachScrollHandler();
  },

  updated() {
    const oldFeedName = this.feedName;
    const oldEnabled = this.enabled;

    this.readState();

    if (!this.shouldTrack()) {
      clearTimeout(this.saveTimer);
      this.hasScrolled = false;
      return;
    }

    if (!oldEnabled || oldFeedName !== this.feedName) {
      this.hasScrolled = false;
      this.cleared = false;
    }

    this.attachScrollHandler();
  },

  readState() {
    this.feedName = this.el.dataset.feedName;
    this.enabled = this.el.dataset.savePosition === "true";
  },

  shouldTrack() {
    return this.enabled && this.feedName;
  },

  attachScrollHandler() {
    if (this.scrollHandler) return;

    this.scrollHandler = () => {
      this.hasScrolled = true;
      this.cleared = false;
      this.debouncedSave();
    };

    window.addEventListener("scroll", this.scrollHandler, { passive: true });
  },

  detachScrollHandler() {
    if (!this.scrollHandler) return;

    window.removeEventListener("scroll", this.scrollHandler);
    this.scrollHandler = null;
  },

  findVisible() {
    const items = [];
    const viewportBottom = window.innerHeight;
    let isTop = true;
    for (const el of this.el.querySelectorAll(".activity_wrapper")) {
      const top = el.getBoundingClientRect().top;
      if (top < -10) { isTop = false; continue; }
      if (top > viewportBottom) break;
      if (el.id) items.push(el);
    }
    return { items, isTop };
  },

  savePosition() {
    this.readState();
    if (!this.shouldTrack() || this.cleared) return;
    const { items, isTop } = this.findVisible();
    if (!items.length) return;
    if (isTop) return;
    const idx = 0;
    const id = items[idx].id.replace(/^fa_/, "");
    if (id && id != this.previousID) {
      this.pushEventTo(this.el, "Bonfire.Social.Feeds:reading_position_updated", {
        feed_name: this.feedName,
        cursor: id,
      });
      this.previousID = id;
    }
  },

  debouncedSave() {
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => this.savePosition(), 1000);
  },

  destroyed() {
    clearTimeout(this.saveTimer);
    if (this.hasScrolled && !this.cleared) this.savePosition();
    this.detachScrollHandler();
  },
};

export { FeedScrollTracker };
