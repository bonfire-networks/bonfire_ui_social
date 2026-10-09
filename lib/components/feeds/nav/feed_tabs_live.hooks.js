// ignore sub-pixel/jitter scrolls (iOS momentum, address-bar resize) when deciding direction
const SCROLL_DIRECTION_SLACK = 8;

export default {
  mounted() {
    this.list = this.el.querySelector("ul");
    this.lastScrollY = window.scrollY;
    this.selected = this.el.dataset.selected;

    this.onClick = (e) => this.handleClick(e);
    this.onScroll = () => this.syncScrollHidden();
    this.onFocusIn = () => this.setScrollHidden(false);

    this.el.addEventListener("click", this.onClick);
    this.el.addEventListener("focusin", this.onFocusIn);
    window.addEventListener("scroll", this.onScroll, { passive: true });

    this.centerActive("instant");
  },

  // re-centre only when the active feed changes, not on every re-render (e.g. a tab pinned)
  updated() {
    if (this.el.dataset.selected === this.selected) return;
    this.selected = this.el.dataset.selected;
    // "auto" defers to the list's CSS `scroll-behavior` (smooth, unless reduced motion)
    this.centerActive("auto");
  },

  // Horizontally scroll the strip so the active tab is centred (no-op when everything fits).
  centerActive(behavior) {
    const active = this.list?.querySelector("[aria-current='page']");
    if (!active) return;

    const listRect = this.list.getBoundingClientRect();
    const tabRect = active.getBoundingClientRect();
    const delta = tabRect.left + tabRect.width / 2 - (listRect.left + listRect.width / 2);
    this.list.scrollBy({ left: delta, behavior });
  },

  // Tapping the tab you're already on goes back to the newest activities instead of re-patching
  // to the same URL: it presses the feed's jump button (reveal fresh activities, forget the
  // reading position, and its own scroll-to-top animation), even while that button is hidden.
  handleClick(e) {
    const link = e.target.closest("a[aria-current='page']");
    if (!link || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;

    e.preventDefault();
    // LiveView's window-level link handler ignores defaultPrevented
    e.stopPropagation();

    const jump = document.querySelector("[data-id='jump_to_top']");
    if (!jump) return window.scrollTo({ top: 0 });

    // the button is `inert` while hidden near the top; its hook resets that on the next scroll
    const inert = jump.inert;
    jump.inert = false;
    jump.click();
    jump.inert = inert;
  },

  syncScrollHidden() {
    const y = window.scrollY;
    const delta = y - this.lastScrollY;
    if (Math.abs(delta) < SCROLL_DIRECTION_SLACK) return;

    this.lastScrollY = y;
    const nearTop = y < this.el.offsetHeight * 2;
    const keepVisible = nearTop || this.el.querySelector(":focus-visible");
    this.setScrollHidden(delta > 0 && !keepVisible);
  },

  setScrollHidden(hidden) {
    this.el.toggleAttribute("data-scroll-hidden", hidden);
  },

  destroyed() {
    this.el.removeEventListener("click", this.onClick);
    this.el.removeEventListener("focusin", this.onFocusIn);
    window.removeEventListener("scroll", this.onScroll);
  },
};
