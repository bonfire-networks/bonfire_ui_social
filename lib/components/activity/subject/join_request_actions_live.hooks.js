const JoinRequestFocus = {
  mounted() {
    this.onSubmit = () => {
      if (!this.el.contains(document.activeElement)) return;
      const feed = this.el.closest('[data-id="feed"]');
      const controls = Array.from(feed?.querySelectorAll('[data-request-status]') || []);
      this.pendingFocus = {
        status: this.el.dataset.requestStatus,
        nextIds: controls.slice(controls.indexOf(this.el) + 1).map((control) => control.id),
        feed,
      };
    };
    this.el.addEventListener('submit', this.onSubmit);
  },

  restoreFocus(removed = false) {
    const pending = this.pendingFocus;
    if (!pending) return;
    const status = this.el.dataset.requestStatus;
    if (!removed && status === pending.status) return;
    this.pendingFocus = null;
    // A slow response must not steal focus after the reviewer has moved elsewhere.
    if (document.activeElement !== document.body && !this.el.contains(document.activeElement)) return;
    if (!removed && status === 'declined') {
      this.el.querySelector('button[value="approve"]')?.focus();
      return;
    }
    for (const id of pending.nextIds) {
      const control = document.getElementById(id);
      const button = control?.querySelector('button:not([disabled])');
      if (button && button.getClientRects().length) {
        button.focus();
        return;
      }
    }
    pending.feed?.focus();
  },

  updated() {
    if (this.el.dataset.requestError === 'true') {
      this.pendingFocus = null;
      return;
    }
    this.restoreFocus();
  },

  destroyed() {
    this.restoreFocus(true);
    this.el.removeEventListener('submit', this.onSubmit);
  },
};

export { JoinRequestFocus };
