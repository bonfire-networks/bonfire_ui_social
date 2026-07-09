defmodule Bonfire.UI.Social.EventsLive do
  @moduledoc """
  The `/events` discovery page: a category filter bar (FEP-8a8e) over the standard
  events feed.

  The feed itself is the shared `Bonfire.UI.Social.FeedLive` component rendering the
  `:events` preset (exactly like `/feed/events`) — it owns loading, pagination and
  rendering the standard event card. This view only adds the category chip bar.

  The selected category lives in the URL (`?category=MUSIC`): a chip navigates there,
  and `handle_params/3` scopes the feed via the `object_categories` filter and marks
  the active chip. Navigation remounts the feed fresh, so it always reflects the URL —
  and the filter is shareable/bookmarkable. No changes to the shared feed component are
  needed.
  """
  use Bonfire.UI.Common.Web, :surface_live_view

  alias Bonfire.Social.Events.Categories
  alias Bonfire.UI.Social.EventCategories
  alias Bonfire.Social.Feeds.LiveHandler

  declare_nav_link(l("Events"),
    icon: "ph:calendar-blank-fill",
    page: "events",
    href: "/events"
  )

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.LoadCurrentUser,
              Bonfire.UI.Me.LivePlugs.LoadCurrentUserCircles
            ]}

  @doc "All FEP-8a8e category keys, in display order, for the filter bar."
  def categories, do: Categories.all()

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page: "events",
       page_title: l("Discover Events"),
       page_header_icon: "ph:calendar-blank-fill",
       no_index: true,
       back: true,
       selected_category: nil,
       feed: nil,
       page_info: nil,
       loading: true,
       feed_id: nil,
       feed_component_id: nil,
       feed_filters: %{},
       feedback_title: l("No events found"),
       feedback_message:
         l(
           "Events from people you follow and federated platforms like Mobilizon will appear here."
         ),
       sidebar_widgets: [
         users: [secondary: [{Bonfire.Tag.Web.WidgetTagsLive, []}]],
         guests: [secondary: [{Bonfire.Tag.Web.WidgetTagsLive, []}]]
       ]
     )}
  end

  def handle_params(params, _uri, socket) do
    selected =
      case params["category"] do
        c when is_binary(c) and c != "" -> Categories.normalize(c)
        _ -> nil
      end

    {:noreply,
     socket
     |> assign(selected_category: selected)
     |> assign(feed: nil, page_info: nil, loading: true)
     |> assign(LiveHandler.feed_default_assigns({:events, category_filters(selected)}, socket))}
  end

  # a chip navigates to the category's URL (a full remount → the feed loads fresh, filtered)
  def handle_event("select_category", %{"category" => category}, socket) do
    {:noreply, push_navigate(socket, to: "/events?category=#{Categories.normalize(category)}")}
  end

  def handle_event("clear_category", _params, socket) do
    {:noreply, push_navigate(socket, to: "/events")}
  end

  defp category_filters(nil), do: %{}
  defp category_filters(category), do: %{object_categories: [category]}

  @doc "Localised label for a category key."
  defdelegate category_label(key), to: EventCategories, as: :label
end
