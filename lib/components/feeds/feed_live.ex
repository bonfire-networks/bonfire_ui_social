defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.UI.Common.Web, :stateful_component
  use_if_enabled(Bonfire.UI.Common.Web.Native, :stateful_component)
  import Untangle

  alias Bonfire.Social.FeedFilters
  alias Bonfire.UI.Social.ActivityLive
  alias Bonfire.Social.Feeds.LiveHandler
  alias Bonfire.UI.Common.LoadMoreLive

  prop feed_name, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_ids, :any, default: nil
  prop feed, :any, default: nil
  prop subject_user, :any, default: nil

  prop page_info, :any, default: nil
  prop previous_page_info, :any, default: nil
  prop hide_guest_fallback, :boolean, default: false

  prop loading, :boolean, default: true
  prop reloading, :boolean, default: true

  prop cache_strategy, :any, default: nil
  prop hide_activities, :any, default: nil
  prop hide_actions, :any, default: false

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

  prop current_url, :any, default: nil
  prop tab_path_prefix, :string, default: "?tab="
  prop tab_path_suffix, :string, default: nil
  prop hide_filters, :boolean, default: false
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
  prop deferred_join_multiply_limit, :any, default: nil
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
    entry_id =
      id(entry) || e(entry, :activity, :id, nil) || e(entry, :object, :id, nil) ||
        e(entry, :edge, :id, nil)

    # Ensure we always have a deterministic ID, fallback to hash of entry content if no ID
    final_id =
      if entry_id,
        do: entry_id,
        else: :erlang.phash2(entry, 1_000_000)

    "#{feed_id}_#{final_id}"
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
           context: context,
           name: l("Show Curated Tab"),
           description: l("Show a curated feed tab on the feed page.")
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

    maybe_subscribe(socket)
    # |> assign(
    # page_info: page_info,
    # feed: feed
    # |> debug("FeedLive: feed")
    # )
    |> ok_socket()
  end

  # def update(%{feed_id: "user_timeline_"} = assigns, socket) do
  #   debug("a user feed was NOT provided, fetching one now")

  #   socket = assign(socket, assigns)
  #   socket = assign(socket, :feed_component_id, assigns(socket).id)

  #   socket =
  #     socket
  #     |> LiveHandler.feed_assigns_maybe_async(
  #       assigns(socket)[:feed_name] || assigns(socket)[:feed_id] || assigns(socket)[:id] ||
  #         :default,
  #       ...
  #     )
  #     |> LiveHandler.insert_feed(socket, ...)

  #   ok_socket(maybe_subscribe(socket))
  # end

  def update(
        %{feed: nil, feed_count: feed_count} = assigns,
        %{assigns: %{feed_count: feed_count}} = socket
      )
      when not is_nil(feed_count) do
    debug("a feed was NOT provided, but we have a feed_count")

    ok_socket(socket)
  end

  def update(%{feed: nil, feed_count: feed_count} = assigns, socket)
      when not is_nil(feed_count) do
    debug("a feed was NOT provided, but feed_count was passed")

    ok_socket(socket)
  end

  def update(%{feed: nil, feed_filters: empty_feed_filters} = assigns, socket)
      when empty_feed_filters == %{} or empty_feed_filters == [] or empty_feed_filters == nil do
    socket = assign(socket, assigns)
    socket = assign(socket, :feed_component_id, assigns(socket).id)

    if user_socket_connected?(socket) || !current_user_id(socket) ||
         LiveHandler.force_static?(socket) do
      # if LiveHandler.maybe_load_async?(socket) do

      debug("a feed was NOT provided, fetching one now (without filters)")

      socket =
        socket
        |> assign(:feed_count, 0)
        |> LiveHandler.feed_assigns_maybe_async(
          assigns(socket)[:feed_name] || assigns(socket)[:feed_id] || assigns(socket)[:id] ||
            :default,
          ...
        )
        |> LiveHandler.insert_feed(socket, ...)

      maybe_subscribe(socket)
      |> ok_socket()
    else
      debug(
        "a feed was NOT provided, but we don't have a user socket connected, so we just pass assigns and wait for the socket to connect"
      )

      ok_socket(socket)
    end
  end

  def update(%{feed: nil} = assigns, socket) do
    socket = assign(socket, assigns)
    socket = assign(socket, :feed_component_id, assigns(socket).id)

    if user_socket_connected?(socket) || !current_user_id(socket) ||
         LiveHandler.force_static?(socket) do
      # if LiveHandler.maybe_load_async?(socket) do
      debug("a feed was NOT provided, fetching one now (with filters)")

      socket =
        socket
        |> assign(:feed_count, 0)
        |> LiveHandler.feed_assigns_maybe_async(
          {assigns(socket)[:feed_name] || assigns(socket)[:feed_id],
           assigns(socket)[:feed_filters]},
          ...
        )
        |> LiveHandler.insert_feed(socket, ...)

      maybe_subscribe(socket)
      |> ok_socket()
    else
      debug(
        "a feed was NOT provided, but we don't have a user socket connected, so we just pass assigns and wait for the socket to connect"
      )

      ok_socket(socket)
    end
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
       hide_actions:
         assigns(socket)[:hide_actions] ||
           (Settings.get(
              [
                Bonfire.UI.Social.Activity.ActionsLive,
                :feed,
                :hide_until_hovered
              ],
              nil,
              current_user: current_user(socket),
              name: l("Hide Activity Actions"),
              description:
                l("Hide actions (such a like or boost) in feeds until users hover over them.")
            ) && "until_hovered"),
       hide_activities:
         assigns(socket)[:hide_activities] ||
           assigns(socket)[:__context__][:current_params]["hide_activities"]
     )}
  end

  def maybe_subscribe(socket) do
    case e(assigns(socket), :feed_ids, nil) || e(assigns(socket), :feed_id, nil) do
      nil ->
        debug("no feed_id known, not subscribing to live updates")
        socket

      # "user_timeline_" <> feed_id ->
      #   PubSub.subscribe(feed_id, socket)

      feed_or_feeds ->
        already_pubsub_subscribed = e(assigns(socket), :feed_pubsub_subscribed, nil)

        if already_pubsub_subscribed == feed_or_feeds do
          debug(already_pubsub_subscribed, "already subscribed to this via pubsub")

          socket
        else
          # debug(feed_or_feeds, "live subscribing to")
          PubSub.subscribe(feed_or_feeds, socket)

          socket
          |> assign(feed_pubsub_subscribed: feed_or_feeds)
        end
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
      feed_name in [:my, :explore, :remote, :local] ->
        widgets(assigns)

      feed_name in [:curated] ->
        curated_widgets()

      feed_name in [:notifications] ->
        [
          page_header_aside: [
            {Bonfire.UI.Social.HeaderAsideNotificationsSeenLive,
             [
               feed_id: :notifications,
               feed_name: "notifications"
             ]}
            # {Bonfire.UI.Social.HeaderAsideFeedFiltersLive, [feed_name: "notifications"]}
          ]
        ]

      true ->
        [
          # page_header_aside: [
          #   {Bonfire.UI.Social.HeaderAsideFeedFiltersLive, [feed_name: feed_name]}
          # ]
        ]
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

  def widgets(assigns) do
    feed_name = e(assigns, :feed_name, nil)

    [
      # page_header_aside: [
      #   {Bonfire.UI.Social.HeaderAsideFeedFiltersLive, [feed_name: feed_name]}
      # ],
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

  def handle_event(
        "set_filter",
        %{"Elixir.Bonfire.UI.Social.FeedLive" => attrs},
        socket
      ) do
    handle_event(
      "set_filter",
      attrs,
      socket
    )
  end

  def handle_event(
        "set_filter",
        %{"time_limit" => time_limit} = attrs,
        socket
      ) do
    assigns = assigns(socket)

    # time_limit = LiveHandler.extract_time_limit(assigns, time_limit)

    socket
    |> assign(LiveHandler.prepare_time_limit(assigns, time_limit))
    |> assign(
      # time_limit: time_limit,
      deferred_join_multiply_limit:
        e(attrs, "multiply_limit", nil) |> Types.maybe_to_integer(nil) ||
          e(assigns, :multiply_limit, nil) || 1
    )
    # |> set_filters(%{time_limit: time_limit}, ...)
    |> reload()
  end

  def handle_event(
        "set_filter",
        %{"time_limit_idx" => time_limit_idx},
        socket
      ) do
    # special handling for range input control
    selected_value =
      Bonfire.UI.Social.TimeControlLive.find_value_by_index(time_limit_idx)
      |> debug("selected value at index #{time_limit_idx}")

    set_filters(%{time_limit: selected_value}, socket)
  end

  def handle_event(
        "set_filter",
        %{"toggle" => field, "toggle_type" => type} = params,
        socket
      ) do
    # Check if we're NOT using the lite controls AND this is a tab mode click
    if params["tab_mode"] == "true" do
      # Tab behavior for tab filter buttons
      if params["toggle_value"] == "true" do
        # Set this tab as the only active filter
        set_filters(
          %{
            # Clear all possible filter types, then set only the clicked one
            object_types: if(field == "object_types", do: [maybe_to_atom(type)], else: []),
            media_types: if(field == "media_types", do: [maybe_to_atom(type)], else: []),
            activity_types: if(field == "activity_types", do: [maybe_to_atom(type)], else: []),
            # Also clear all exclude lists
            exclude_object_types: [],
            exclude_media_types: [],
            exclude_activity_types: []
          },
          socket,
          true
        )
      else
        # toggle_value is nil or "false" - clicking active tab, so show all
        set_filters(
          %{
            # Clear all filters to show everything
            object_types: [],
            media_types: [],
            activity_types: [],
            exclude_object_types: [],
            exclude_media_types: [],
            exclude_activity_types: []
          },
          socket,
          true
        )
      end
    else
      # Regular behavior for standard controls
      set_type(
        maybe_to_atom(field),
        maybe_to_atom("exclude_#{field}"),
        type,
        params["toggle_value"],
        socket
      )
    end
  end

  def handle_event(
        "mobile_filter_change",
        %{} = params,
        socket
      ) do
    value = params["filter_select"] || ""

    case value do
      "" ->
        # Empty value selected, delegate to set_filter to show all
        handle_event(
          "set_filter",
          %{
            "toggle" => "object_types",
            "toggle_type" => "post",
            "toggle_value" => nil,
            "tab_mode" => "true"
          },
          socket
        )

      _ ->
        case String.split(value, ":") do
          [field, type] when field != "" and type != "" ->
            # Delegate to existing set_filter handler with tab_mode
            handle_event(
              "set_filter",
              %{
                "toggle" => field,
                "toggle_type" => type,
                "toggle_value" => "true",
                "tab_mode" => "true"
              },
              socket
            )

          _ ->
            # Invalid format, ignore
            {:noreply, socket}
        end
    end
  end

  def handle_event(
        "set_filter",
        %{"include" => types},
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
        attrs,
        socket
      ) do
    set_filters(
      attrs,
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

  def handle_event(
        "live_select_change",
        %{"text" => text, "id" => live_select_id, "field" => field},
        socket
      ) do
    options =
      case field do
        "subject_circles" ->
          Bonfire.UI.Boundaries.SetBoundariesLive.circles_for_multiselect(
            assigns(socket)[:__context__],
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

  def set_filters(
        attrs,
        socket,
        replace_lists \\ false
      ) do
    # debug(attrs, "set_filter")
    case FeedFilters.validate(attrs) do
      {:ok, filters} ->
        reload(
          # Enums.merge_to_struct(
          #   FeedFilters,
          Enums.merge_as_map(
            debug(assigns(socket)[:feed_filters] || %{}, "existing filters"),
            filters
            |> debug("validated")
            # replace_lists: replace_lists
          )
          |> debug("merged"),
          socket,
          Config.env() == :test
        )

      e ->
        error(e)
    end
  end

  def reload(
        feed_filters \\ nil,
        socket,
        reset \\ true
      ) do
    # need to reload feed so streams are updated

    assigns = assigns(socket)

    feed_filters = feed_filters || e(assigns, :feed_filters, %{})

    feed_name = feed_name(assigns)

    if is_nil(feed_name) or feed_name in [:my, :explore, :remote, :local, :custom],
      do: send_self(widgets(assigns))

    socket =
      socket
      |> assign(
        loading: reset,
        reloading: !reset,
        page_info: nil,
        previous_page_info: nil,
        feed_filters: feed_filters
      )

    # |> assign(:page_header_aside, LiveHandler.page_header_asides(...))

    feed_assigns =
      LiveHandler.feed_assigns_maybe_async(
        {feed_name, feed_filters},
        socket,
        true,
        true
      )
      |> debug("reload with feed_assigns")

    {
      :noreply,
      socket
      |> LiveHandler.insert_feed(feed_assigns, reset: reset)
      # |> debug("socket_assigned")
      # |> debug("seeet")
    }
  end

  defp set_type(include_field, exclude_field, type, value, socket) do
    do_set_type(
      List.wrap(ed(assigns(socket), :feed_filters, include_field, [])),
      List.wrap(ed(assigns(socket), :feed_filters, exclude_field, [])),
      include_field,
      exclude_field,
      Types.maybe_to_atom(type),
      value,
      socket
    )
  end

  defp do_set_type(
         already_selected,
         already_excluded,
         include_field,
         exclude_field,
         type,
         "true",
         socket
       ) do
    set_filters(
      %{
        include_field => already_selected ++ [type],
        exclude_field => already_excluded |> Enum.reject(&(&1 == type))
      }
      |> debug(),
      socket,
      true
    )
  end

  defp do_set_type(
         already_selected,
         already_excluded,
         include_field,
         exclude_field,
         type,
         "false",
         socket
       ) do
    set_filters(
      %{
        include_field => already_selected |> Enum.reject(&(&1 == type)),
        exclude_field => already_excluded ++ [type]
      }
      |> debug(),
      socket,
      true
    )
  end

  defp do_set_type(
         already_selected,
         already_excluded,
         include_field,
         exclude_field,
         type,
         _value,
         socket
       ) do
    set_filters(
      %{
        include_field => already_selected |> Enum.reject(&(&1 == type)),
        exclude_field => already_excluded |> Enum.reject(&(&1 == type))
      }
      |> debug(),
      socket,
      true
    )
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
