export default {
	timeAgo(input) {
		const locale =
			navigator.languages && navigator.languages.length
				? navigator.languages[0]
				: navigator.language; // TODO: use app local instead of browser locale
		const date = input instanceof Date ? input : new Date(input);
		const formatter = new Intl.RelativeTimeFormat(locale);
		const ranges = {
			years: 3600 * 24 * 365,
			months: 3600 * 24 * 30,
			weeks: 3600 * 24 * 7,
			days: 3600 * 24,
			hours: 3600,
			minutes: 60,
			seconds: 1,
		};
		const secondsElapsed = (date.getTime() - Date.now()) / 1000;
		for (let key in ranges) {
			if (ranges[key] < Math.abs(secondsElapsed)) {
				const delta = secondsElapsed / ranges[key];
				return formatter.format(Math.round(delta), key);
			}
		}
	},
	setTimeAgo(el, the_date) {
		var date_ago = this.timeAgo(the_date);
		// console.log(date_ago)

		if (date_ago) {
			this.el.innerHTML = date_ago;

			setTimeout(() => {
				this.setTimeAgo(el, the_date);
			}, 60_000);
		}
	},
	mounted() {
		var the_date = this.el.getAttribute("data-date");
		// console.log(the_date)
		if (the_date) {
			setTimeout(() => {
				this.setTimeAgo(this.el, the_date);
			}, 60_000);
		}
	},
};
