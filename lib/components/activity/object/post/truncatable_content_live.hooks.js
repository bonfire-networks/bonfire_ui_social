export default {
  mounted() {
    // Use idle callback to avoid blocking navigation
    if (window.requestIdleCallback) {
      requestIdleCallback(() => {
        this.checkTruncation()
        this.setupObservers()
        this.setupClickHandlers()
      }, { timeout: 150 })
    } else {
      // Fallback for browsers without requestIdleCallback
      setTimeout(() => {
        this.checkTruncation()
        this.setupObservers()
        this.setupClickHandlers()
      }, 100)
    }
  },
  
  updated() {
    // Use idle callback to avoid blocking navigation
    if (window.requestIdleCallback) {
      requestIdleCallback(() => {
        this.checkTruncation()
        this.removeClickHandlers()
        this.setupClickHandlers()
      }, { timeout: 150 })
    } else {
      // Fallback for browsers without requestIdleCallback
      setTimeout(() => {
        this.checkTruncation()
        this.removeClickHandlers()
        this.setupClickHandlers()
      }, 100)
    }
  },
  
  destroyed() {
    // Clean up observers
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    // Clean up click handlers
    this.removeClickHandlers()
  },
  
  checkTruncation() {
    // Skip truncation in specific contexts where it's not needed
    const showingWithin = this.el.dataset.showingWithin
    const viewingMainObject = this.el.dataset.viewingMainObject === 'true'
    
    if (viewingMainObject || ['smart_input'].includes(showingWithin)) {
      this.hideControls()
      return
    }
    
    // Find the content element
    const contentEl = this.el.querySelector('#expandable_note_' + this.extractId())
    if (!contentEl) return
    
    // Determine if controls are needed
    const hasTruncateClass = contentEl.classList.contains('previewable_truncate')
    const isExpanded = contentEl.classList.contains('previewable_expanded')
    const isOverflowing = contentEl.scrollHeight > contentEl.clientHeight
    
    // Show controls if content is truncated and overflowing OR already expanded
    const needsControls = (hasTruncateClass && isOverflowing) || isExpanded
    
    // Update controls visibility
    const controls = this.el.querySelector('.read-more-controls')
    if (controls) {
      controls.style.display = needsControls ? 'block' : 'none'
    }
  },
  
  setupObservers() {
    // Monitor content size changes
    if (typeof ResizeObserver !== 'undefined') {
      const contentEl = this.el.querySelector('#expandable_note_' + this.extractId())
      if (!contentEl) return
      
      this.resizeObserver = new ResizeObserver(() => {
        this.checkTruncation()
      })
      
      this.resizeObserver.observe(contentEl)
    }
    
    // Handle lazy-loaded images
    const images = this.el.querySelectorAll('img')
    images.forEach(img => {
      if (!img.complete) {
        img.addEventListener('load', () => this.checkTruncation(), { once: true })
      }
    })
  },
  
  hideControls() {
    const controls = this.el.querySelector('.read-more-controls')
    if (controls) {
      controls.style.display = 'none'
    }
  },
  
  extractId() {
    // Extract the ID suffix from the hook element ID
    const match = this.el.id.match(/truncation_detector_(.+)/)
    return match ? match[1] : ''
  },
  
  setupClickHandlers() {
    const readMoreBtn = this.el.querySelector('.read-more-btn')
    const readLessBtn = this.el.querySelector('.read-less-btn')
    
    if (readMoreBtn) {
      this.readMoreHandler = () => this.toggleContent(true)
      readMoreBtn.addEventListener('click', this.readMoreHandler)
    }
    
    if (readLessBtn) {
      this.readLessHandler = () => this.toggleContent(false)
      readLessBtn.addEventListener('click', this.readLessHandler)
    }
  },
  
  removeClickHandlers() {
    const readMoreBtn = this.el.querySelector('.read-more-btn')
    const readLessBtn = this.el.querySelector('.read-less-btn')
    
    if (readMoreBtn && this.readMoreHandler) {
      readMoreBtn.removeEventListener('click', this.readMoreHandler)
    }
    
    if (readLessBtn && this.readLessHandler) {
      readLessBtn.removeEventListener('click', this.readLessHandler)
    }
    
    // Clear references to prevent memory leaks
    this.readMoreHandler = null
    this.readLessHandler = null
  },
  
  toggleContent(expand) {
    const id = this.extractId()
    const contentEl = this.el.querySelector('#expandable_note_' + id)
    const readMoreBtn = this.el.querySelector('.read-more-btn')
    const readLessBtn = this.el.querySelector('.read-less-btn')
    
    if (contentEl) {
      contentEl.classList.toggle('previewable_truncate', !expand)
      contentEl.classList.toggle('previewable_expanded', expand)
    }
    
    if (readMoreBtn) {
      readMoreBtn.style.display = expand ? 'none' : 'block'
    }
    
    if (readLessBtn) {
      readLessBtn.style.display = expand ? 'block' : 'none'
    }
  }
}