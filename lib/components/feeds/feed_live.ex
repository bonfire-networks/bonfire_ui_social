defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.UI.Common.Web, :stateful_component
  use_if_enabled(Bonfire.UI.Common.Web.Native, :stateful_component)
  import Untangle

  alias Bonfire.Social.FeedFilters
  alias Bonfire.UI.Social.ActivityLive
  alias Bonfire.Social.Feeds.LiveHandler

  prop feed_name, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_ids, :any, default: nil
  prop hide_guest_fallback, :boolean, default: false
  prop feed, :any, default: nil
  prop subject_user, :any, default: nil
  prop page_info, :any, default: nil
  prop previous_page_info, :any, default: nil
  prop loading, :boolean, default: true
  prop cache_strategy, :any, default: nil
  prop hide_activities, :any, default: nil

  prop feedback_title, :string, default: nil
  prop feedback_message, :string, default: nil
  prop showing_within, :atom, default: nil
  prop feed_update_mode, :string, default: "append"
  prop hide_load_more, :boolean, default: false
  prop verb_default, :string, default: nil

  prop page_title, :string, default: nil
  prop feed_title, :string, default: nil

  @doc "What LiveHandler and/or event name to send the patch event to for tabs navigation (if any)"
  # "select_tab"
  prop event_handler, :string, default: nil
  # FIXME: should optimise by LinkPatchLive but currently not working
  prop tab_link_component, :atom, default: LinkLive

  prop tab_path_prefix, :string, default: "?tab="
  prop tab_path_suffix, :string, default: nil
  prop hide_tabs, :boolean, default: false
  prop selected_tab, :any, default: nil
  prop top_page, :any, default: nil
  prop show_back_button, :boolean, default: false

  prop tabs_class, :css_class, default: nil

  prop tab_class, :css_class,
    default:
      "flex flex-1 pt-4 px-2 text-base capitalize hover:bg-base-content hover:bg-opacity-10 place-content-center lined_tab"

  prop item_class, :css_class,
    default: "text-base-content/60 text-sm pb-4 border-b-4 border-transparent font-medium"

  prop tab_primary_class, :css_class, default: nil

  prop activity_class, :string, default: nil
  prop feed_filters, :any, default: nil
  # prop time_limit, :any, default: nil
  # prop sort_order, :any, default: false
  prop activity_preloads, :tuple, default: {nil, nil}

  prop hide_fresh, :integer, default: 0
  prop feed_count, :any, default: nil
  prop cute_gif, :any, default: nil
  prop custom_preview, :any, default: nil

  slot bottom_or_empty_feed

  def mount(%Phoenix.LiveView.Socket{} = socket) do
    # FIXME: assigns not available in mount
    # feed_id = e(assigns(socket), :feed_name, nil) || e(assigns(socket), :feed_id, nil) || e(assigns(socket), :id, nil)
    {
      :ok,
      socket
      |> stream_configure(:feed, dom_id: &stream_id("fa", &1))
      |> stream(:feed, [])
      |> assign(cute_gif: maybe_cute_gif())
      #  temporary_assigns: [
      #    feed: []
      #  ]
    }
  end

  # TEMP for LVN
  def mount(socket_or_assigns) do
    {
      :ok,
      socket_or_assigns
      |> assign(cute_gif: maybe_cute_gif())
    }
  end

  defp stream_id(feed_id, entry) do
    "#{feed_id}_#{id(entry) || e(entry, :activity, :id, nil) || e(entry, :object, :id, nil) || e(entry, :edge, :id, nil) || random_dom_id()}"
  end

  # consolidate different kinds of lists/feeds into Activity
  defp get_activity(%{activity: %{id: _} = activity, edge: %{id: _} = edge}),
    do: merge_structs_as_map(activity, edge) |> debug("merged_structs_as_map")

  defp get_activity(%{edge: %{id: _, activity: %{id: _} = activity} = edge}),
    do: merge_structs_as_map(activity, edge) |> debug("merged_structs_as_map")

  defp get_activity(%{activity: %{id: _} = activity}), do: activity
  defp get_activity(%{edge: %{id: _} = activity}), do: activity
  defp get_activity(activity), do: activity

  def tabs(_page, context) do
    # disabled hiding of remote tab because it is also useful to find remote activities that were looked up manually
    # case Bonfire.Social.federating?(current_user(context)) do
    #   true ->
    # if current_user_id(context) do
    if module_enabled?(Bonfire.Social.Pins, context) and
         Bonfire.Common.Settings.get(
           [Bonfire.UI.Social.FeedsLive, :curated],
           false,
           context
         ) do
      [
        my: l("Following"),
        curated: l("Curated"),
        local: l("Local"),
        fediverse: l("Remote")
      ]
    else
      [
        my: l("Following"),
        explore: l("All"),
        local: l("Local"),
        fediverse: l("Remote")
      ]
    end

    # else

    #   [curated: l("Curated"), local: l("Local"), fediverse: l("Remote")]
    # end
  end

  @decorate time()
  def update(assigns, socket)

  def update(%{insert_stream: %{feed: entries}} = assigns, socket) do
    debug("feed stream is being poured into")

    socket
    |> assign(Map.drop(assigns, [:insert_stream]))
    |> LiveHandler.insert_feed(entries, reset: assigns[:reset_stream])
    |> ok_socket()
  end

  # adding new feed item
  def update(%{new_activity: new_activity} = _assigns, socket) when is_map(new_activity) do
    debug("new_activity, add to top of feed")

    {
      :ok,
      socket
      |> assign(hide_fresh: e(assigns(socket), :hide_fresh, 0) + 1)
      # what an ugly way but idk
      |> push_event("js-exec-attr-event", %{
        to: "#show_fresh",
        attr: "phx-show"
      })
      |> LiveHandler.insert_feed(new_activity, at: 0, reset: false)
      #  |> JS.show(to: "#show_fresh") # LV doesn't have this for some reason
    }
  end

  # def update(%{__context__: %{new_activity: new_activity}} = assigns, socket) when is_map(new_activity) do
  #   debug("FeedLive: add new activity from component context")
  #   update(Map.merge(assigns, %{new_activity: new_activity}), socket)
  # end

  def update(_assigns, %{assigns: %{loading: loading?, feed: feed}} = socket)
      when loading? == false and feed != :loading do
    debug("skip replacing feed unless it was loading")
    ok_socket(socket)
  end

  def update(_assigns, %{assigns: %{feed: existing_feed}} = socket)
      when is_list(existing_feed) and length(existing_feed) > 0 do
    # FIXME: doesn't work because of temporary assigns?
    debug("skip replacing already loaded feed")
    ok_socket(socket)
  end

  def update(%{feed: feed, page_info: _page_info} = assigns, socket) when is_list(feed) do
    debug("an initial feed was provided via assigns")
    debug(assigns)

    # debug(assigns(socket), "socket assigns")
    # debug(assigns)
    socket = assign(socket, assigns)
    # debug(socket)

    feed_id_or_ids = e(assigns(socket), :feed_ids, nil) || e(assigns(socket), :feed_id, nil)
    already_pubsub_subscribed = e(assigns(socket), :feed_pubsub_subscribed, nil)

    if already_pubsub_subscribed == feed_id_or_ids do
      debug(already_pubsub_subscribed, "already subscribed to this via pubsub")
    else
      maybe_subscribe(socket)
    end

    ok_socket(
      socket
      |> assign(
        feed_pubsub_subscribed: feed_id_or_ids
        # page_info: page_info,
        # feed: feed
        # |> debug("FeedLive: feed")
      )
    )
  end

  def update(%{feed_id: "user_timeline_"} = assigns, socket) do
    debug("a user feed was NOT provided, fetching one now")

    socket = assign(socket, assigns)
    socket = assign(socket, :feed_component_id, assigns(socket).id)

    socket =
      socket
      |> LiveHandler.feed_assigns_maybe_async(
        assigns(socket)[:feed_name] || assigns(socket)[:feed_id] || assigns(socket)[:id] ||
          :default,
        ...
      )
      |> LiveHandler.insert_feed(socket, ...)

    maybe_subscribe(socket)

    ok_socket(socket)
  end

  def update(%{feed: nil, feed_filters: empty_feed_filters} = assigns, socket)
      when empty_feed_filters == %{} or empty_feed_filters == [] or empty_feed_filters == nil do
    debug("a feed was NOT provided, fetching one now (without filters)")

    socket = assign(socket, assigns)
    socket = assign(socket, :feed_component_id, assigns(socket).id)

    socket =
      socket
      |> LiveHandler.feed_assigns_maybe_async(
        assigns(socket)[:feed_name] || assigns(socket)[:feed_id] || assigns(socket)[:id] ||
          :default,
        ...
      )
      |> LiveHandler.insert_feed(socket, ...)

    maybe_subscribe(socket)

    ok_socket(socket)
  end

  def update(%{feed: nil} = assigns, socket) do
    debug("a feed was NOT provided, fetching one now (with filters)")

    socket = assign(socket, assigns)
    socket = assign(socket, :feed_component_id, assigns(socket).id)

    socket =
      socket
      |> LiveHandler.feed_assigns_maybe_async(
        {assigns(socket)[:feed_name] || assigns(socket)[:feed_id] || assigns(socket)[:id] ||
           :default, assigns(socket)[:feed_filters]},
        ...
      )
      |> LiveHandler.insert_feed(socket, ...)

    maybe_subscribe(socket)

    ok_socket(socket)
  end

  def update(%{feed: :loading} = assigns, socket) do
    debug("a feed is being loaded async")

    ok_socket(assign(socket, assigns))
  end

  def update(%{loading: true} = assigns, socket) do
    debug("a feed is being loaded async")

    ok_socket(assign(socket, assigns))
  end

  def update(_assigns, socket) do
    warn("No feed loaded")
    ok_socket(socket)
  end

  defp ok_socket(socket) do
    # debug(assigns(socket)[:__context__][:current_params], "fsa")

    {:ok,
     socket
     |> assign(
       feed_component_id: assigns(socket)[:id],
       hide_activities:
         assigns(socket)[:hide_activities] ||
           assigns(socket)[:__context__][:current_params]["hide_activities"]
     )}
  end

  def maybe_subscribe(socket) do
    case e(assigns(socket), :feed_ids, nil) || e(assigns(socket), :feed_id, nil) do
      nil ->
        debug("no feed_id known, not subscribing to live updates")

      "user_timeline_" <> feed_id ->
        PubSub.subscribe(feed_id, socket)

      feed_or_feeds ->
        # debug(feed_or_feeds, "live subscribing to")
        PubSub.subscribe(feed_or_feeds, socket)
    end
  end

  # def handle_info({:new_activity, data}, socket) do
  #   debug(feed_live_pubsub_received: data)

  #   # maybe_send_update(Bonfire.UI.Social.FeedLive, "feed", new_activity: data)

  #   {:noreply, socket}
  # end

  # def handle_event("select_tab", attrs, socket) do
  #   tab = maybe_to_atom(e(attrs, "name", nil))

  #   debug(attrs, tab)

  #   {:noreply,
  #    socket
  #    |> assign(selected_tab: tab)
  #    |> LiveHandler.insert_feed(LiveHandler.feed_assigns_maybe_async(tab, socket))}
  # end

  def maybe_widgets(assigns) do
    maybe_widgets(assigns, feed_name(assigns))
  end

  def maybe_widgets(assigns, feed_name) do
    cond do
      feed_name in [:my, :explore, :remote, :local] -> widgets(assigns)
      feed_name in [:curated] -> curated_widgets()
      true -> []
    end
  end

  defp curated_widgets() do
    [
      sidebar_widgets: [
        guests: [
          secondary: [
            {Bonfire.UI.Social.WidgetFeedDescriptionLive, [feed_name: :curated]},
            {Bonfire.Tag.Web.WidgetTagsLive, []}
          ]
        ],
        users: [
          secondary: [
            {Bonfire.UI.Social.WidgetFeedDescriptionLive, [feed_name: :curated]},
            {Bonfire.Tag.Web.WidgetTagsLive, []}
          ]
        ]
      ]
    ]
  end

  defp widgets(assigns) do
    feed_name = e(assigns, :feed_name, nil)

    [
      sidebar_widgets: [
        guests: [
          secondary: [
            {Bonfire.UI.Social.WidgetFeedDescriptionLive, [feed_name: feed_name]}
          ]
        ],
        users: [
          secondary: [
            {Bonfire.UI.Social.WidgetFeedDescriptionLive, [feed_name: feed_name]},
            # {Bonfire.UI.Social.WidgetFeedLive,
            #  [
            #    event_target: "##{e(assigns, :feed_component_id, nil)}",
            #    feed_name: feed_name,
            #    sort_by: e(assigns, :sort_by, nil),
            #    time_limit: e(assigns, :time_limit, nil),
            #    sort_order: e(assigns, :sort_order, nil),
            #    showing_within: e(assigns, :showing_within, nil)
            #  ]},
            {Bonfire.Tag.Web.WidgetTagsLive, []}
          ]
        ]
      ]
    ]
  end

  def feed_name(assigns),
    do:
      assigns[:feed_name] || assigns[:feed_id] || assigns[:id] ||
        :default

  defp set_type_activity(type, value, socket) do
    set_type(:activity_types, :exclude_activity_types, type, value, socket)
  end

  defp set_type_object(type, value, socket) do
    set_type(:object_types, :exclude_object_types, type, value, socket)
  end

  defp set_type_media(type, value, socket) do
    set_type(:media_types, :exclude_media_types, type, value, socket)
  end

  defp set_type(already_selected_field, already_excluded_field, type, value, socket) do
    do_set_type(
      e(assigns(socket), :feed_filters, already_selected_field, []),
      e(assigns(socket), :feed_filters, already_excluded_field, []),
      already_selected_field,
      already_excluded_field,
      Types.maybe_to_atom(type),
      value,
      socket
    )
  end

  defp do_set_type(
         already_selected,
         already_excluded,
         already_selected_field,
         already_excluded_field,
         type,
         "true",
         socket
       ) do
    set_filters(
      %{
        already_selected_field => already_selected ++ [type],
        already_excluded_field => already_excluded |> Enum.reject(&(&1 == type))
      },
      socket,
      true
    )
  end

  defp do_set_type(
         already_selected,
         already_excluded,
         already_selected_field,
         already_excluded_field,
         type,
         "false",
         socket
       ) do
    set_filters(
      %{
        already_selected_field => already_selected |> Enum.reject(&(&1 == type)),
        already_excluded_field => already_excluded ++ [type]
      },
      socket,
      true
    )
  end

  defp do_set_type(
         already_selected,
         already_excluded,
         already_selected_field,
         already_excluded_field,
         type,
         value,
         socket
       ) do
    set_filters(
      %{
        already_selected_field => already_selected |> Enum.reject(&(&1 == type)),
        already_excluded_field => already_excluded |> Enum.reject(&(&1 == type))
      },
      socket,
      true
    )
  end


  def handle_event("set_filter", %{"Elixir.Bonfire.UI.Social.FeedLive" => %{"time_limit" => attrs}}, socket) do
    debug(attrs, "cazz")
    options = %{1 => l("Day"), 7 => l("Week"), 30 => l("Month"), 365 => "Year", 0 => "All time"}
    values =  options |> Map.keys() |> Enum.sort()
    selected_value = find_value_by_index(attrs, values)
    debug(selected_value, "cazzz")
    set_filters(%{time_limit: selected_value}, socket)
  end

  def handle_event(
        "set_filter",
        %{"toggle" => field, "toggle_type" => type} = params,
        socket
      ) do
    # warn(types, "WIP: set_types_filter")
    case field do
      "activity_types" -> set_type_activity(type, params["toggle_value"], socket)
      "object_types" -> set_type_object(type, params["toggle_value"], socket)
      "media_types" -> set_type_media(type, params["toggle_value"], socket)
    end
  end

  def handle_event(
        "set_filter",
        %{"Elixir.Bonfire.Social.Feeds" => %{"include" => types}},
        socket
      ) do
    # warn(types, "WIP: set_types_filter")

    {_include_map, exclude_map} = Map.split_with(types, fn {_, v} -> v == "true" end)

    set_filters(
      %{
        # activity_types: Map.keys(include_map) # TODO?
        exclude_activity_types: Map.keys(exclude_map)
      },
      socket
    )
  end

  def handle_event(
        "set_filter",
        %{"subject_circles" => circle_id} = params,
        socket
      )
      when not is_nil(circle_id) do
    current_circles = e(socket.assigns, :feed_filters, :subject_circles, [])

    updated_circles =
      if circle_id in current_circles do
        List.delete(current_circles, circle_id)
      else
        [circle_id | current_circles]
      end
      |> Enum.uniq()

    set_filters(
      %{
        subject_circles: updated_circles
      },
      socket
    )
  end

  def handle_event(
        "set_filter",
        %{"Elixir.Bonfire.UI.Social.FeedLive" => attrs},
        socket
      ) do
    set_filters(
      attrs,
      socket
    )
  end

  def handle_event(
        "set_filter",
        attrs,
        socket
      ) do
    set_filters(
      attrs,
      socket
    )
  end

  def handle_event(
        "live_select_change",
        %{"text" => text, "id" => live_select_id, "field" => field},
        socket
      ) do
    options =
      case field do
        "subject_circles" ->
          Bonfire.UI.Boundaries.SetBoundariesLive.circles_for_multiselect(
            socket.assigns.__context__,
            :subject_circles,
            text
          )

        _ ->
          []
      end

    send_update(LiveSelect.Component, id: live_select_id, options: options)
    {:noreply, socket}
  end

  def handle_event("toggle_circle_filter", %{"circle_id" => circle_id}, socket) do
    current_circles = e(socket.assigns, :feed_filters, :subject_circles, [])

    updated_circles =
      if circle_id in current_circles do
        List.delete(current_circles, circle_id)
      else
        [circle_id | current_circles] |> Enum.uniq()
      end

    set_filters(
      %{
        "Elixir.Bonfire.UI.Social.FeedLive" => %{
          subject_circles: updated_circles
        }
      },
      socket
    )
  end

  def handle_event("multi_select", %{data: selected}, socket) when is_list(selected) do
    filters =
      Enum.group_by(selected, fn %{} = data -> data["field"] end)
      |> debug()
      |> Enum.reduce(%{}, fn {field, data}, acc ->
        Map.merge(acc, %{
          field =>
            data
            |> Enum.map(&id/1)
            |> Enum.uniq()
        })
      end)
      |> debug()

    set_filters(
      filters,
      socket
    )
  end

  def handle_event(
        "set",
        attrs,
        socket
      ) do
    reload(
      assigns(socket)[:feed_filters],
      socket
      |> Bonfire.UI.Common.LiveHandlers.assign_attrs(attrs)
    )
  end

  def set_filters(
        attrs,
        socket,
        replace_lists \\ false
      ) do
    # debug(attrs, "set_filter")
    case FeedFilters.validate(attrs) do
      {:ok, filters} ->
        reload(
          Enums.merge_to_struct(
            FeedFilters,
            debug(assigns(socket)[:feed_filters] || %{}, "existing filters"),
            filters
            |> debug("validated")
            # replace_lists: replace_lists
          )
          |> debug("merged"),
          socket
        )

      e ->
        error(e)
    end
  end

  def reload(
        feed_filters,
        socket
      ) do
    # need to reload feed so streams are updated

    feed_name = feed_name(assigns(socket))

    # if feed_name in [:my, :explore, :remote, :local], do:
    send_self(widgets(e(assigns(socket), nil)))

    {
      :noreply,
      socket
      |> assign(
        loading: true,
        feed_filters: feed_filters
      )
      # |> assign(:page_header_aside, LiveHandler.page_header_asides(...))
      |> LiveHandler.insert_feed(
        ...,
        LiveHandler.feed_assigns_maybe_async(
          {feed_name, feed_filters},
          ...,
          true,
          true
        )
      )
      # |> debug("seeet")
    }
  end


  def find_value_by_index(index, values) do
    index_int =
      case Integer.parse(to_string(index)) do
        {num, _} -> num
        :error -> 0
      end

    Enum.at(values, index_int, List.first(values))
  end
  #   def handle_event(
  #       "hide_fresh",
  #       attrs,
  #       socket
  #     )do

  #   ok_socket(
  #    socket
  #    |> assign(
  #      hide_fresh: 0
  #    ))
  # end
end
