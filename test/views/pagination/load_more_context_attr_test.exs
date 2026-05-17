defmodule Bonfire.UI.Social.Feeds.LoadMoreContextAttrTest do
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
      group =
        Simulate.fake_group!(me, %{
          name: "Scope Group",
          membership: "local:members",
          visibility: "nonfederated",
          participation: "anyone"
        })

      Simulate.fake_post_in_group!(me, group, "<p>group post 1</p>")
      Simulate.fake_post_in_group!(me, group, "<p>group post 2</p>")

      for n <- 1..10 do
        {:ok, _} =
          Posts.publish(
            current_user: me,
            post_attrs: %{post_content: %{html_body: "<p>unrelated #{n}</p>"}},
            boundary: "public"
          )
      end

      conn(user: me, account: account)
      |> visit("/&#{group.character.username}")
      |> wait_async()
      |> assert_has("article", text: "group post 1")
      |> assert_has("article", text: "group post 2")
      |> refute_has("article", text: "unrelated")
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
