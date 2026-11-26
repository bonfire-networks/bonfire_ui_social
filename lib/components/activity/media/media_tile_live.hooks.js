// A compact audio row in the composer's media picker: plays its preview, one at a time across the picker.
export default {
	mounted() {
		const audio = this.el.querySelector("audio");
		const button = this.el.querySelector("[data-role=media_play]");
		const sync = () => {
			this.el.toggleAttribute("data-playing", !audio.paused);
			button.setAttribute("aria-pressed", String(!audio.paused));
		};

		button.addEventListener("click", () => {
			if (!audio.paused) return audio.pause();
			for (const other of document.querySelectorAll("[data-role=media_row] audio")) {
				if (other !== audio) other.pause();
			}
			audio.play();
		});
		audio.addEventListener("play", sync);
		audio.addEventListener("pause", sync);
	},
};
