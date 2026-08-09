// Morphing context header: reveals the compact author bar once the thread's main post
// scrolls out of view; clicking it scrolls back to the top. Works on thread pages and
// in the preview modal (which replaces the main column, so the window still scrolls) —
// lookups are scoped to this component's subtree because the modal has its own sticky
// header and its own copy of the `#thread_main_object` anchor.
const HIDDEN_CLASSES = ["opacity-0", "-translate-y-1", "pointer-events-none"];

let ThreadContextHeader = {
	mounted() {
		this.bar = this.el.querySelector("[data-role='thread-context-bar']");
		const container = this.el.closest("[data-role='object-thread']");
		this.target = container && container.querySelector("#thread_main_object");
		if (!this.bar || !this.target || !("IntersectionObserver" in window))
			return;

		// Stick just below this context's sticky header, measured live (the
		// --spacing-page-header fallback in the inline style is the desktop height;
		// the mobile header is shorter).
		this.setOffset = () => {
			const scope =
				this.el.closest("#the_preview_contents") ||
				document.getElementById("main-content");
			const header = scope && scope.querySelector(":scope > .sticky");
			if (header) this.el.style.top = `${header.offsetHeight}px`;
		};
		this.setOffset();
		window.addEventListener("resize", this.setOffset);

		this.onClick = (e) => {
			e.preventDefault();
			window.scrollTo({ top: 0, behavior: "smooth" });
		};
		this.bar.addEventListener("click", this.onClick);

		this.observer = new IntersectionObserver(
			([entry]) => {
				const rect = entry.boundingClientRect;
				// Only reveal when the post has scrolled UP out of view, never when it
				// simply hasn't been reached yet — and never for a zero-size rect (the
				// hidden main column while a preview modal is open reports 0x0).
				const rootTop = entry.rootBounds ? entry.rootBounds.top : 0;
				const show =
					!entry.isIntersecting && rect.height > 0 && rect.top < rootTop;
				for (const cls of HIDDEN_CLASSES)
					this.bar.classList.toggle(cls, !show);
				this.bar.setAttribute("aria-hidden", show ? "false" : "true");
				this.bar.setAttribute("tabindex", show ? "0" : "-1");
			},
			{ threshold: 0 },
		);
		this.observer.observe(this.target);
	},
	destroyed() {
		if (this.observer) this.observer.disconnect();
		if (this.setOffset) window.removeEventListener("resize", this.setOffset);
		if (this.bar && this.onClick)
			this.bar.removeEventListener("click", this.onClick);
	},
};

export { ThreadContextHeader };
