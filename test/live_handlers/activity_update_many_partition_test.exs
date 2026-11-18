defmodule Bonfire.UI.Social.ActivityUpdateManyPartitionTest do
  @moduledoc "One LiveView `update_many` batch can hold the cards of the trending widget and of the dashboard feed. Each card gets the preloads its own assigns ask for, and the Boosts preload when its own `showing_within` allows it. Each test builds one batch by hand with two cards for the same post, one per kind (widget and feed, or messages and feed), with the other kind first. The control runs the feed card alone, to show what the feed card gets when nothing else is in the batch. The last test counts the repo queries of a batch whose cards differ only in `showing_within`, and compares them to a batch whose cards share it."
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  import Bonfire.Common.Testing, only: [count_queries: 1]

  alias Bonfire.Data.Social.Activity
  alias Bonfire.Data.Social.Post
  alias Bonfire.Social.Feeds.LiveHandler

  setup do
    # preload in the calling process, so the result comes back from the call
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)

    account = fake_account!()
    me = fake_user!(account)

    post =
      Bonfire.Posts.Fake.fake_post!(me, "public", %{
        post_content: %{html_body: "in the widget and in the feed"}
      })

    # the dashboard's feed is off unless the user turns it on
    Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :include, :feed], true,
      current_user: me
    )

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, current_user: me}}

    # the preloads the dashboard's feed puts on its cards, as the feed sets them when it loads
    presets = Bonfire.UI.Social.FeedNavigation.list_presets(current_user: me)

    feed_name =
      Bonfire.UI.Social.FeedNavigation.default_feed(presets, current_user: me) || :default

    {_filters, _assigns, preload, postload} =
      LiveHandler.prepare_filters_assigns_preloads_posloads(feed_name, current_user: me)

    {:ok, me: me, post: post, socket: socket, feed_activity_preloads: {preload, postload}}
  end

  # a card for the post, as a component receives it before any postload: the object is read afresh, so its `:peered` is not loaded
  defp card(id, post, socket, extra) do
    object = repo().get!(Post, uid(post))

    {Map.merge(
       %{
         id: id,
         activity: %Activity{id: uid(post), object_id: uid(post), object: object},
         object: object
       },
       Map.new(extra)
     ), socket}
  end

  defp widget_card(post, socket),
    do: card("widget-card", post, socket, showing_within: :widget, activity_preloads: {nil, nil})

  defp feed_card(post, socket, activity_preloads),
    do: card("feed-card", post, socket, activity_preloads: activity_preloads)

  defp find(results, id),
    do:
      Enum.find_value(results, fn
        {%{id: ^id} = assigns, _} -> assigns
        _ -> nil
      end)

  # control: the feed card alone has its postloads, so the next test compares against a known good result
  test "the feed card gets its postloads when it is alone in the batch (control)", %{
    post: post,
    socket: socket,
    feed_activity_preloads: preloads
  } do
    assert {_, [_ | _]} = preloads, "the dashboard feed has postloads to ask for"

    results =
      LiveHandler.activity_update_many([feed_card(post, socket, preloads)],
        caller_module: __MODULE__
      )

    refute match?(
             %Ecto.Association.NotLoaded{},
             find(results, "feed-card").activity.object.peered
           )
  end

  # proves the widget card (no postloads) and the feed card in one batch each get their own `activity_preloads`
  test "the feed card gets its postloads when the widget card is first in the batch", %{
    post: post,
    socket: socket,
    feed_activity_preloads: preloads
  } do
    results =
      LiveHandler.activity_update_many(
        [widget_card(post, socket), feed_card(post, socket, preloads)],
        caller_module: __MODULE__
      )

    refute match?(
             %Ecto.Association.NotLoaded{},
             find(results, "feed-card").activity.object.peered
           )
  end

  # proves a messages card and the feed card in one batch each get the Boosts preload their own `showing_within` allows
  test "the feed card gets its boost state when a messages card is first in the batch", %{
    post: post,
    socket: socket,
    feed_activity_preloads: preloads
  } do
    alone =
      LiveHandler.actions_update_many([feed_card(post, socket, preloads)],
        caller_module: __MODULE__
      )

    assert Map.has_key?(find(alone, "feed-card"), :my_boost), "control: the feed card alone"

    results =
      LiveHandler.actions_update_many(
        [
          card("messages-card", post, socket, showing_within: :messages),
          feed_card(post, socket, preloads)
        ],
        caller_module: __MODULE__
      )

    assert Map.has_key?(find(results, "feed-card"), :my_boost)
  end

  # proves two cards with the same `activity_preloads` and different `showing_within` run as one group: the batch makes as many queries as the same two cards with equal `showing_within`, and both get their postloads
  test "cards with the same activity_preloads and different showing_within run as one group", %{
    post: post,
    socket: socket,
    feed_activity_preloads: preloads
  } do
    pair = fn second_showing_within ->
      [
        card("first-card", post, socket, showing_within: :widget, activity_preloads: preloads),
        card("second-card", post, socket,
          showing_within: second_showing_within,
          activity_preloads: preloads
        )
      ]
    end

    # warm the caches, so the counted calls do the same work
    LiveHandler.activity_update_many(pair.(:widget), caller_module: __MODULE__)

    {equal, equal_queries} =
      count_queries(fn ->
        LiveHandler.activity_update_many(pair.(:widget), caller_module: __MODULE__)
      end)

    {mixed, mixed_queries} =
      count_queries(fn ->
        LiveHandler.activity_update_many(pair.(nil), caller_module: __MODULE__)
      end)

    assert equal_queries > 0, "the control batch queries the database"
    assert mixed_queries == equal_queries

    for results <- [equal, mixed], id <- ["first-card", "second-card"] do
      refute match?(%Ecto.Association.NotLoaded{}, find(results, id).activity.object.peered)
    end
  end
end
