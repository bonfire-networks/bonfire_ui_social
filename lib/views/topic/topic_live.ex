defmodule Bonfire.UI.Social.TopicLive do
  use Bonfire.UI.Common.Web, :surface_live_view


  alias Bonfire.UI.Me.LivePlugs

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      # LivePlugs.LoadCurrentUserCircles,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  defp mounted(params, _session, socket) do

      {:ok,
       assign(
         socket,
         page: "topics",
         object_type: nil,
         feed: nil,
         back: true,
         selected_tab: :timeline,
         tab_id: nil,
         page_title: l("Topic"),
         interaction_type: l("follow"),
         sidebar_widgets: [
           users: [
            secondary: [
              {Bonfire.UI.Topic.WidgetAboutLive, [title: "About topic x", group: "Welcome", group_link: "/welcome", about: "A sub for ALL parents, step parents, parents-to-be, guardians, caretakers, and anyone else who prefers to base their parenting choices on actual, evidence-backed scientific research.", date: "16 Feb"]},
              {Bonfire.UI.Groups.WidgetMembersLive, [mods: [], members: []]}
            ]
           ],
           guests: [
             secondary: nil
           ]
         ]
       )}
    end

  def tab(selected_tab) do
    case maybe_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> :timeline
    end

    # |> debug
  end

  def do_handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["posts", "boosts", "timeline"] do
    Bonfire.Social.Feeds.LiveHandler.user_feed_assign_or_load_async(
      tab,
      e(socket.assigns, :category, nil),
      params,
      socket
    )
  end

  def do_handle_params(%{"tab" => tab, "tab_id" => tab_id}, _url, socket) do
    # debug(id)
    {:noreply,
     assign(socket,
       selected_tab: tab,
       tab_id: tab_id
     )}
  end

  def do_handle_params(%{"tab_id" => "suggestions" = tab_id} = params, _url, socket) do
    {:noreply,
     assign(
       socket,
       Bonfire.Social.Feeds.LiveHandler.load_user_feed_assigns(
         "submitted",
         e(socket.assigns, :category, :character, :notifications_id, nil),
         Map.put(
           params,
           :exclude_feed_ids,
           e(socket.assigns, :category, :character, :outbox_id, nil)
         ),
         socket
       )
     )}
  end

  def do_handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["followers"] do
    {:noreply,
     assign(
       socket,
       Bonfire.Social.Feeds.LiveHandler.load_user_feed_assigns(
         tab,
         e(socket.assigns, :category, nil),
         params,
         socket
       )
     )}
  end

  def do_handle_params(%{"tab" => tab}, _url, socket) do
    {:noreply,
     assign(socket,
       selected_tab: tab
     )}

    # nothing defined
  end

  def do_handle_params(params, _url, socket) do
    # default tab
    do_handle_params(
      Map.merge(params || %{}, %{"tab" => "timeline"}),
      nil,
      socket
    )
  end

  def handle_params(params, uri, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_params(
        params,
        uri,
        socket,
        __MODULE__,
        &do_handle_params/3
      )

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
