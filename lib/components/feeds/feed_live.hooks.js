let FeedScrollTracker = {
  mounted() {
    this.topVisibleId = null;
    this.saveTimer = null;
    this.hasScrolled = false;
    this.feedName = this.el.dataset.feedName;
    if (!this.feedName) return;

    // Listen for server telling us to clear the reading position
    this.handleEvent("clear_reading_position", ({ feed_name }) => {
      localStorage.removeItem(`reading_pos:${feed_name}`);
      // Reset tracking state so the observer doesn't immediately re-save
      this.hasScrolled = false;
      clearTimeout(this.saveTimer);
      this.topVisibleId = null;
      // Re-arm the scroll listener so saving only resumes after user scrolls
      window.removeEventListener("scroll", this.scrollHandler);
      this.scrollHandler = () => { this.hasScrolled = true; };
      window.addEventListener("scroll", this.scrollHandler, { passive: true, once: true });
    });

    // Mark a reading position as consumed — next reconnect won't send it
    this.handleEvent("reading_position_consumed", ({ feed_name }) => {
      const key = `reading_pos:${feed_name}`;
      try {
        const val = JSON.parse(localStorage.getItem(key));
        if (val && val.id) {
          val.consumed = true;
          localStorage.setItem(key, JSON.stringify(val));
        }
      } catch { /* ignore parse errors */ }
    });

    // Track whether user has actually scrolled (vs initial render)
    this.scrollHandler = () => { this.hasScrolled = true; };
    window.addEventListener("scroll", this.scrollHandler, { passive: true, once: true });

    this.observer = new IntersectionObserver(
      (entries) => {
        let topVisible = null;
        let topY = Infinity;
        for (const entry of entries) {
          if (entry.isIntersecting) {
            const rect = entry.boundingClientRect;
            if (rect.top >= -10 && rect.top < topY) {
              topY = rect.top;
              topVisible = entry.target;
            }
          }
        }
        if (topVisible) {
          const activityId = topVisible.id.replace(/^fa_/, "");
          if (activityId && activityId !== this.topVisibleId) {
            this.topVisibleId = activityId;
            if (this.hasScrolled) {
              this.debouncedSave();
            }
          }
        }
      },
      { root: null, rootMargin: "0px", threshold: 0.3 }
    );

    this.observeItems();
    this.mutationObs = new MutationObserver(() => this.observeItems());
    this.mutationObs.observe(this.el, { childList: true });
  },

  updated() {
    const newFeedName = this.el.dataset.feedName;
    if (newFeedName && newFeedName !== this.feedName) {
      this.feedName = newFeedName;
      this.hasScrolled = false;
    }
  },

  observeItems() {
    for (const el of this.el.querySelectorAll(".activity_wrapper")) {
      if (!el._tracked) {
        this.observer.observe(el);
        el._tracked = true;
      }
    }
  },

  savePosition() {
    if (this.topVisibleId && this.feedName) {
      // Save the *previous* sibling's ID as cursor so that exclusive `after:`
      // pagination naturally includes the item the user was looking at.
      const el = document.getElementById(`fa_${this.topVisibleId}`);
      const prev = el?.previousElementSibling?.closest(".activity_wrapper");
      const cursorId = prev ? prev.id.replace(/^fa_/, "") : null;
      localStorage.setItem(
        `reading_pos:${this.feedName}`,
        JSON.stringify({
          id: cursorId || this.topVisibleId,
          ts: Date.now(),
        }),
      );
    }
  },

  debouncedSave() {
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => this.savePosition(), 1000);
  },

  destroyed() {
    this.observer?.disconnect();
    this.mutationObs?.disconnect();
    clearTimeout(this.saveTimer);
    // Flush any pending position before the hook is torn down
    if (this.hasScrolled) {
      this.savePosition();
    }
    window.removeEventListener("scroll", this.scrollHandler);
  },
};

export { FeedScrollTracker };
