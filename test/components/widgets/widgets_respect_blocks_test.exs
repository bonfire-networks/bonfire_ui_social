defmodule Bonfire.UI.Social.WidgetsRespectBlocksTest do
  @moduledoc "Widgets show their cached activities to each viewer minus the authors that viewer silenced or was ghosted by, from the next render on, without waiting for the cache to expire."
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Boundaries.Blocks
  alias Bonfire.Social.Pins

  setup do
    Process.put(:federating, false)
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)

    account = fake_account!()
    me = fake_user!(account)
    admin = fake_admin!(fake_account!())
    author = fake_user!(fake_account!())

    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: author,
        post_attrs: %{post_content: %{html_body: "widget post by the author"}},
        boundary: "public"
      )

    Pins.pin(admin, post, :instance)

    # a control by someone nobody blocks: it must still show after a block, so a `refute_has` can't pass just because the whole widget went away
    bystander = fake_user!(fake_account!())

    {:ok, control_post} =
      Bonfire.Posts.publish(
        current_user: bystander,
        post_attrs: %{post_content: %{html_body: "widget post by a bystander"}},
        boundary: "public"
      )

    Pins.pin(admin, control_post, :instance)
    Pins.list_spotlight_activities(cache: :reset)

    on_exit(fn -> Pins.list_spotlight_activities(cache: :reset) end)

    reset_trending_discussions_cache(me)

    {:ok, conn: conn(user: me, account: account), me: me, author: author, post: post}
  end

  defp dashboard(conn) do
    conn
    |> visit("/dashboard")
    |> wait_async()
  end

  test "top discussions and the spotlight drop a post once I silence its author", %{
    conn: conn,
    me: me,
    author: author
  } do
    # the positive first, which also fills the caches
    dashboard(conn)
    |> assert_has("[data-id=trending_discussions]", text: "widget post by the author")
    |> assert_has("[data-id=instance_pinned_widget]", text: "widget post by the author")

    Blocks.block(author, :silence, current_user: me)

    dashboard(conn)
    |> assert_has("[data-id=trending_discussions]", text: "widget post by a bystander")
    |> assert_has("[data-id=instance_pinned_widget]", text: "widget post by a bystander")
    |> refute_has("[data-id=trending_discussions]", text: "widget post by the author")
    |> refute_has("[data-id=instance_pinned_widget]", text: "widget post by the author")
  end

  test "top discussions and the spotlight drop a post once its author ghosts me", %{
    conn: conn,
    me: me,
    author: author
  } do
    dashboard(conn)
    |> assert_has("[data-id=trending_discussions]", text: "widget post by the author")
    |> assert_has("[data-id=instance_pinned_widget]", text: "widget post by the author")

    Blocks.block(me, :ghost, current_user: author)

    dashboard(conn)
    |> assert_has("[data-id=trending_discussions]", text: "widget post by a bystander")
    |> assert_has("[data-id=instance_pinned_widget]", text: "widget post by a bystander")
    |> refute_has("[data-id=trending_discussions]", text: "widget post by the author")
    |> refute_has("[data-id=instance_pinned_widget]", text: "widget post by the author")
  end

  # the carousel hides a slide with CSS (`:has([hidden])`), which this harness doesn't apply, so this checks the card renders the `hidden` root that rule matches, rather than a restricted-content placeholder
  test "a hidden card renders a `hidden` root, not a placeholder", %{
    conn: conn,
    me: me,
    author: author
  } do
    Blocks.block(author, :silence, current_user: me)

    # the spotlight's cache has no viewer, so its card is always loaded and has to be hidden at render
    dashboard(conn)
    |> assert_has(
      "[data-id=instance_pinned_widget] [data-carousel-card] [data-id=activity_not_visible][hidden]"
    )
    |> refute_has("[data-id=instance_pinned_widget] [data-role=restricted_cover]")
  end

  # top discussions and the spotlight are cached once for guests and once for everyone signed in (`Bonfire.Boundaries.Circles.query_as_circle/1`), not once per user
  test "top discussions share one cache entry for everyone signed in, and another for guests", %{
    me: me
  } do
    other = fake_user!(fake_account!())

    assert Bonfire.Social.Threads.trending_cache_key(me, 5) ==
             Bonfire.Social.Threads.trending_cache_key(other, 5)

    refute Bonfire.Social.Threads.trending_cache_key(me, 5) ==
             Bonfire.Social.Threads.trending_cache_key(nil, 5)
  end

  test "a pinned local-only post shows in the spotlight to signed-in users, not to guests", %{
    conn: conn
  } do
    admin = fake_admin!(fake_account!())

    {:ok, local_post} =
      Bonfire.Posts.publish(
        current_user: admin,
        post_attrs: %{post_content: %{html_body: "local-only spotlight post"}},
        boundary: "local"
      )

    Pins.pin(admin, local_post, :instance)
    Pins.list_spotlight_activities(cache: :reset)

    dashboard(conn)
    |> assert_has("[data-id=instance_pinned_widget]", text: "widget post by a bystander")
    |> assert_has("[data-id=instance_pinned_widget]", text: "local-only spotlight post")

    conn()
    |> visit("/")
    |> wait_async()
    |> assert_has("#guest-spotlight [data-role=pinned_card]", text: "widget post by a bystander")
    |> refute_has("#guest-spotlight", text: "local-only spotlight post")
    # not even a restricted card, which would show its name, summary and cover to someone who may not see it
    |> refute_has("#guest-spotlight [data-id=restricted_content]")
    # only the two public pins from the setup, so no card at all for the local-only one, however it would be marked
    |> assert_has("#guest-spotlight [data-role=pinned_card]", count: 2)
  end

  test "recent articles drop an article once I silence its author, and keep the others", %{
    conn: conn,
    me: me,
    author: author
  } do
    bystander = fake_user!(fake_account!())

    for {user, name} <- [{author, "Article by the author"}, {bystander, "Article by a bystander"}] do
      {:ok, _} =
        Bonfire.Posts.publish(
          current_user: user,
          schema: Bonfire.Articles.Article,
          post_attrs: %{post_content: %{name: name, html_body: "a long-form body"}},
          boundary: "public"
        )
    end

    # cached once for everyone signed in, so one test's list would otherwise be read by the next
    reset = fn ->
      for viewer <- [me, nil], do: Bonfire.Articles.list_recent(viewer, 5, cache: :reset)
    end

    reset.()
    on_exit(reset)

    # the positive first, which also fills the cache
    dashboard(conn)
    |> assert_has("[data-id=recent_articles]", text: "Article by the author")
    |> assert_has("[data-id=recent_articles]", text: "Article by a bystander")

    Blocks.block(author, :silence, current_user: me)

    dashboard(conn)
    |> assert_has("[data-id=recent_articles]", text: "Article by a bystander")
    |> refute_has("[data-id=recent_articles]", text: "Article by the author")
  end

  describe "who to follow" do
    setup %{author: author} do
      Bonfire.Boundaries.Circles.list_suggested_profiles(cache: :reset)
      on_exit(fn -> Bonfire.Boundaries.Circles.list_suggested_profiles(cache: :reset) end)

      {:ok, _} =
        Bonfire.Boundaries.Circles.add_to_circles(
          author,
          Bonfire.Boundaries.Scaffold.Instance.suggested_profiles_circle()
        )

      Bonfire.Boundaries.Circles.list_suggested_profiles(cache: :reset)
      :ok
    end

    test "drops a suggested profile once I silence them", %{conn: conn, me: me, author: author} do
      name = e(author, :profile, :name, nil)

      dashboard(conn)
      |> assert_has("#suggested-profiles-carousel", text: name)

      Blocks.block(author, :silence, current_user: me)

      dashboard(conn)
      |> refute_has("#suggested-profiles-carousel", text: name)
    end
  end

  test "someone I didn't block still sees the post, and so does a guest" do
    other_account = fake_account!()
    other = fake_user!(other_account)

    conn(user: other, account: other_account)
    |> dashboard()
    |> assert_has("[data-id=trending_discussions]", text: "widget post by the author")
    |> assert_has("[data-id=instance_pinned_widget]", text: "widget post by the author")

    # guests get the spotlight on the home page, not the dashboard
    conn()
    |> visit("/")
    |> wait_async()
    |> assert_has("#guest-spotlight [data-role=pinned_card]", text: "widget post by the author")
  end
end
