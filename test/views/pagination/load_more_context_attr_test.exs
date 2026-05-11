defmodule Bonfire.UI.Social.Feeds.LoadMoreContextAttrTest do
  @moduledoc """
  Regression tests for the `phx-value-context` attribute on LoadMoreLive
  when fired into `Bonfire.Social.Feeds.LiveHandler`.

  The 2023 `%{"context" => feed_id}` clause in
  `feeds_live_handler.ex:42` was written when `context` was expected to
  be a real feed UID. Over time, call sites began using `context` as a
  UI label (tab name, `"show_older"`, etc.). When a LoadMoreLive with a
  label-style `context` triggers in the Feeds handler, the stale clause
  misroutes the request: the label is passed as `feed_name` to
  `FeedLoader.feed/3`, clobbers `feed_filters.feed_name`, and falls
  through to an unfiltered query in `feed_query/3` (since
  `Types.uid_or_uids("show_older")` returns nil).

  The user-visible bug: a group feed page showing 3 entries auto-triggered
  the "Show older activities" LoadMore (because the 3 items did not fill
  the viewport), the load_more event arrived with
  `context: "show_older"`, and the unfiltered query returned ~12
  unrelated activities from other groups.

  Fix: the "Show older" LoadMore in `feed_live.sface` now uses
  `dom_id_suffix="show_older"` instead of `context="show_older"`, so no
  `phx-value-context` is sent and the fallback handler (which uses
  `feed_filters` from socket assigns) runs correctly.

  These tests guard against the stale 2023 clause re-introducing the bug
  if another non-UID `context` value ever leaks into a Feeds load_more
  event.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  use Bonfire.Common.Config
  alias Bonfire.Posts
  alias Bonfire.Classify.Simulate

  setup do
    original_deferred = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
    Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], false)

    on_exit(fn ->
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_deferred)
    end)

    repo().delete_all(Bonfire.Data.Social.FeedPublish)

    account = fake_account!()
    me = fake_user!(account)

    %{account: account, me: me}
  end

  describe "Show older LoadMore on a group page" do
    test "does not leak unrelated activities into a short group feed", %{
      account: account,
      me: me
    } do
      # Group with only 2 of its own posts.
      group = Simulate.fake_group!(me, %{name: "Scope Group"})
      Simulate.fake_post_in_group!(me, group, "<p>group post 1</p>")
      Simulate.fake_post_in_group!(me, group, "<p>group post 2</p>")

      # Many unrelated posts in the user's local feed; these would be
      # returned by the unfiltered fallback query if load_more were ever
      # misrouted again.
      for n <- 1..10 do
        {:ok, _} =
          Posts.publish(
            current_user: me,
            post_attrs: %{post_content: %{html_body: "<p>unrelated #{n}</p>"}},
            boundary: "public"
          )
      end

      # Regression: group feed must not leak unrelated activities even when
      # the "Show older" LoadMore auto-triggers (the original bug surfaced
      # via context="show_older" misrouting through the 2023 stale clause).
      conn(user: me, account: account)
      |> visit("/&#{group.character.username}")
      |> wait_async()
      |> assert_has_or_open_browser("article", text: "group post 1")
      |> assert_has("article", text: "group post 2")
      |> refute_has_or_open_browser("article", text: "unrelated")
    end
  end

  describe "Other live_handlers that legitimately use `context`" do
    test "Follows.LiveHandler.handle_event/3 stays available" do
      # The Follows handler pattern-matches on specific tab values rather
      # than treating `context` as a feed UID — keep that contract intact.
      assert function_exported?(
               Bonfire.Social.Graph.Follows.LiveHandler,
               :handle_event,
               3
             )
    end
  end
end
