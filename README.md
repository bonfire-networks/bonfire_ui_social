# Bonfire UI Social
![](https://i.imgur.com/XoQvDCW.png)
[Bonfire:UI:Social](https://github.com/bonfire-networks/bonfire_ui_social) is an extension that includes the main User Interfaces ( both assembled pages and single components ) required to have a fully working federated social network app.

The UI:Social extension is meant to be used in conjunction with the [Bonfire:Social](https://github.com/bonfire-networks/bonfire_social) and [Bonfire:Me](https://github.com/bonfire-networks/bonfire_me) ones, which both provide logic, context and schemas for the UI to work with.
They also define the routes and the views to instanciate using UI:Social components.

UI:Social includes bits from other extensions, included: [Bonfire:Common](https://github.com/bonfire-networks/bonfire_common), [Bonfire:Search](https://github.com/bonfire-networks/bonfire_search), [Bonfire:Tag](https://github.com/bonfire-networks/bonfire_tag), [Bonfire:Boundaries](https://github.com/bonfire-networks/bonfire_boundaries)

### Stack

Current Bonfire UI extensions are built with the PETAL Stack, which in Elixir means:

- [Phoenix](https://www.phoenixframework.org/)
- [Elixir](https://elixir-lang.org/)
- [TailwindCSS](https://tailwindcss.com/)
- [Alpine.js](https://alpinejs.dev/)
- [LiveView](https://hex.pm/packages/phoenix_live_view)

We're currently in the middle of a refactor to convert all the templates from LiveView to [Surface](https://surface-ui.org/).
Surface is a server-side rendering component library for Phoenix, it inherites a lot of design patterns from popular js framework like Vue.js and React, still leveraging upon LiveView to keep the webapp fast and reactive, and almost javascript free compared to common SPA.  

### Scaffolding
The relevant folders are:
- [Components](https://github.com/bonfire-networks/bonfire_ui_social/tree/main/lib/web/components): Surface stateless and stateful components.
- [Layout](https://github.com/bonfire-networks/bonfire_ui_social/tree/main/lib/web/layout): Main app templates, they include guest, logged or specific view templates (eg. the setting layout)
- [Views](https://github.com/bonfire-networks/bonfire_ui_social/tree/main/lib/web/views): The main pages that are rendered when navigating to a specific route
- [Test](https://github.com/bonfire-networks/bonfire_ui_social/tree/main/test): All the unit tests for the specific module.


### TODO
- [x] Port all components over surface
- [x] Localisation
- [ ] Complete all unit tests
- [ ] Port views over surface
- [ ] Setup the component library
- [ ] a11y

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
