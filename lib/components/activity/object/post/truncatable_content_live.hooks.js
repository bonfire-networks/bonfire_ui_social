export default {
  mounted() {
    // Ensure CSS is applied before checking truncation
    requestAnimationFrame(() => {
      this.checkTruncation()
      this.setupObservers()
    })
  },
  
  updated() {
    // Re-check when LiveView updates the content
    requestAnimationFrame(() => {
      this.checkTruncation()
    })
  },
  
  destroyed() {
    // Clean up observers
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  },
  
  checkTruncation() {
    // Skip truncation in specific contexts where it's not needed
    const showingWithin = this.el.dataset.showingWithin
    const viewingMainObject = this.el.dataset.viewingMainObject === 'true'
    
    if (viewingMainObject || ['thread', 'smart_input'].includes(showingWithin)) {
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
  }
}