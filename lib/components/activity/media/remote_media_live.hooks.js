export default {
  mounted() {
    const media = this.el.querySelector('video, audio');
    const fallback = this.el.querySelector('[data-role="media-fallback"]');

    if (!media || !fallback) return;

    this.media = media;
    this.fallback = fallback;
    this.mediaReady = false;

    // Listen for successful metadata load
    media.addEventListener('loadedmetadata', () => {
      this.mediaReady = true;
    }, { once: true });

    // Listen for errors (CORS, network, format issues)
    media.addEventListener('error', () => {
      this.showFallback();
    }, { once: true });

    // Also catch stalled events that may indicate CORS blocking
    media.addEventListener('stalled', () => {
      // Give it a moment, then check if we have any data
      this.stalledTimeout = setTimeout(() => {
        if (!this.mediaReady && media.networkState === 3) {
          this.showFallback();
        }
      }, 3000);
    }, { once: true });
  },

  destroyed() {
    if (this.stalledTimeout) {
      clearTimeout(this.stalledTimeout);
    }
  },

  showFallback() {
    if (this.media && this.fallback) {
      this.media.style.display = 'none';
      this.fallback.style.display = 'block';
    }
  }
};
