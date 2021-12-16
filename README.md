# Bonfire.UI.Social
![](https://i.imgur.com/XoQvDCW.png)

[Bonfire.UI.Social](http://bonfirenetworks.org/extensions/ui_social.html) is an extension that includes the main User Interfaces (both assembled pages and single components) required to have a fully working federated social network app.

This extension is meant to be used by other extensions like [Bonfire.Social](https://github.com/bonfire-networks/bonfire_social) and [Bonfire.Me](https://github.com/bonfire-networks/bonfire_me), which both provide logic for the UI to work with, and define the routes and top-level views which in turn embed the components from this extension.

It also provides components used by other extensions including: [Bonfire.Common](https://github.com/bonfire-networks/bonfire_common), [Bonfire.Search](https://github.com/bonfire-networks/bonfire_search), [Bonfire.Tag](https://github.com/bonfire-networks/bonfire_tag), [Bonfire.Boundaries](https://github.com/bonfire-networks/bonfire_boundaries). 

### Stack

So far, Bonfire UI extensions are built with the PETALS stack (note that is not a requirement), which means:

- [Phoenix](https://www.phoenixframework.org/)
- [Elixir](https://elixir-lang.org/)
- [TailwindCSS](https://tailwindcss.com/)
- [Alpine.js](https://alpinejs.dev/)
- [LiveView](https://github.com/phoenixframework/phoenix_live_view#readme)
- [Surface](https://surface-ui.org/)

We're currently in the middle of a refactor to convert all components and templates from LiveView to Surface, which is a server-side rendering component library (built on top of Phoenix and LiveView) that inherits a lot of design patterns from popular JS framework like Vue.js and React, while being almost JavaScript-free compared to common SPAs.  

### Scaffolding
The relevant folders are:
- [Components](https://github.com/bonfire-networks/bonfire_ui_social/tree/main/lib/web/components): Surface stateless and stateful components.
- [Layout](https://github.com/bonfire-networks/bonfire_ui_social/tree/main/lib/web/layout): Main app templates, they include guest, logged or specific view templates (eg. the setting layout)
- [Views](https://github.com/bonfire-networks/bonfire_ui_social/tree/main/lib/web/views): The main pages that are rendered when navigating to a specific route
- [Test](https://github.com/bonfire-networks/bonfire_ui_social/tree/main/test): All the unit tests for the specific module.

### Other resources
- [A blog post that introduces the concept of themeable bonfire apps](https://bonfirenetworks.org/posts/let_thousand_bonfires_bloom/)


## Copyright and License

Copyright (c) 2020 Bonfire, and CommonsPub Contributors

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program.  If not, see <https://www.gnu.org/licenses/>.
