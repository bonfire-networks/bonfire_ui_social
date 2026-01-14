export default {
  RATIOS: {
    PORTRAIT_TALL: 0.5625,  // 9:16
    PORTRAIT: 0.8,          // 4:5
    SQUARE: 1.0,            // 1:1
    LANDSCAPE: 1.333,       // 4:3
    LANDSCAPE_WIDE: 1.778,  // 16:9
  },

  mounted() {
    this.container = this.el;
    this.items = this.container.querySelectorAll('[data-carousel-slide]');

    if (this.items.length === 0) return;

    this.calculateOptimalRatio();
    this.container.addEventListener('scroll', () => this.updateNavigation());
    this.updateNavigation();
  },

  async calculateOptimalRatio() {
    const mediaElements = this.container.querySelectorAll('img, video');
    const dimensionPromises = Array.from(mediaElements).map(el => this.getMediaDimensions(el));
    const dimensions = await Promise.all(dimensionPromises);

    const ratios = dimensions
      .filter(dim => dim && dim.width > 0 && dim.height > 0)
      .map(dim => dim.width / dim.height);

    if (ratios.length === 0) return;

    const minRatio = Math.min(...ratios);
    const optimalRatio = this.snapToRatioBucket(minRatio);
    this.applyRatio(optimalRatio);
  },

  getMediaDimensions(el) {
    return new Promise((resolve) => {
      if (el.tagName === 'IMG') {
        if (el.naturalWidth > 0) {
          resolve({ width: el.naturalWidth, height: el.naturalHeight });
        } else {
          el.addEventListener('load', () => {
            resolve({ width: el.naturalWidth, height: el.naturalHeight });
          }, { once: true });
          el.addEventListener('error', () => resolve(null), { once: true });
          setTimeout(() => resolve(null), 3000);
        }
      } else if (el.tagName === 'VIDEO') {
        if (el.videoWidth > 0) {
          resolve({ width: el.videoWidth, height: el.videoHeight });
        } else {
          el.addEventListener('loadedmetadata', () => {
            resolve({ width: el.videoWidth, height: el.videoHeight });
          }, { once: true });
          el.addEventListener('error', () => resolve(null), { once: true });
          setTimeout(() => resolve(null), 3000);
        }
      } else {
        resolve(null);
      }
    });
  },

  snapToRatioBucket(ratio) {
    const buckets = Object.values(this.RATIOS);
    return buckets.reduce((closest, bucket) =>
      Math.abs(ratio - bucket) < Math.abs(ratio - closest) ? bucket : closest
    );
  },

  applyRatio(ratio) {
    this.container.querySelectorAll('article[data-id="article_media"]').forEach(article => {
      article.style.aspectRatio = `${ratio}`;
    });
  },

  updateNavigation() {
    const scrollLeft = this.container.scrollLeft;
    const maxScroll = this.container.scrollWidth - this.container.clientWidth;
    const wrapper = this.container.closest('.relative');
    if (!wrapper) return;

    const prevBtn = wrapper.querySelector('[data-nav="prev"]');
    const nextBtn = wrapper.querySelector('[data-nav="next"]');
    const atStart = scrollLeft <= 10;
    const atEnd = scrollLeft >= maxScroll - 10;

    if (prevBtn) {
      prevBtn.style.opacity = atStart ? '0.3' : '1';
      prevBtn.style.pointerEvents = atStart ? 'none' : 'auto';
    }

    if (nextBtn) {
      nextBtn.style.opacity = atEnd ? '0.3' : '1';
      nextBtn.style.pointerEvents = atEnd ? 'none' : 'auto';
    }
  },

  navigate(direction) {
    const scrollAmount = this.container.offsetWidth - 40;
    this.container.scrollBy({
      left: direction === 'next' ? scrollAmount : -scrollAmount,
      behavior: 'smooth'
    });
  },
};
