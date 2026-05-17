defmodule Bonfire.UI.Social.Feeds.AutoPaginationShortFeedTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  use Bonfire.Common.Config
  alias Bonfire.Common.Settings
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

  describe "group feed with fewer entries than viewport" do
    test "infinite-scroll mode does not pull in unrelated activities", %{
      account: account,
      me: me
    } do
      Settings.put([:ui, :infinite_scroll], true, current_user: me, scope: :user)

      group =
        Simulate.fake_group!(me, %{
          name: "Tiny Group",
          membership: "local:members",
          visibility: "nonfederated",
          participation: "anyone"
        })

      Simulate.fake_post_in_group!(me, group, "<p>tiny group post A</p>")
      Simulate.fake_post_in_group!(me, group, "<p>tiny group post B</p>")

      for n <- 1..15 do
        {:ok, _} =
          Posts.publish(
            current_user: me,
            post_attrs: %{post_content: %{html_body: "<p>foreign post #{n}</p>"}},
            boundary: "public"
          )
      end

      conn = conn(user: me, account: account)

      conn
      |> visit("/&#{group.character.username}")
      |> wait_async()
      |> assert_has_or_open_browser("article", text: "tiny group post A")
      |> assert_has("article", text: "tiny group post B")
      |> refute_has_or_open_browser("article", text: "foreign post")
    end

    test "preload mode does not pull in unrelated activities either", %{
      account: account,
      me: me
    } do
      Settings.put([:ui, :infinite_scroll], :preload, current_user: me, scope: :user)

      group =
        Simulate.fake_group!(me, %{
          name: "Tiny Preload Group",
          membership: "local:members",
          visibility: "nonfederated",
          participation: "anyone"
        })

      Simulate.fake_post_in_group!(me, group, "<p>preload group post 1</p>")
      Simulate.fake_post_in_group!(me, group, "<p>preload group post 2</p>")

      for n <- 1..15 do
        {:ok, _} =
          Posts.publish(
            current_user: me,
            post_attrs: %{post_content: %{html_body: "<p>foreign preload post #{n}</p>"}},
            boundary: "public"
          )
      end

      conn = conn(user: me, account: account)

      conn
      |> visit("/&#{group.character.username}")
      |> wait_async()
      |> assert_has("article", text: "preload group post 1")
      |> assert_has("article", text: "preload group post 2")
      |> refute_has("article", text: "foreign preload post")
    end
  end

  describe "Show older activities LoadMore" do
    test "uses dom_id_suffix rather than context" do
      source =
        __DIR__
        |> Path.join("../../../lib/components/feeds/feed_live.sface")
        |> Path.expand()
        |> File.read!()

      assert source =~ ~s|dom_id_suffix="show_older"|
      refute source =~ ~s|context="show_older"|
    end
  end
end
