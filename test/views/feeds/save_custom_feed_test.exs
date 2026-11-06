defmodule Bonfire.UI.Social.SaveCustomFeedTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  test "save is hidden until preferences change and hides again after reset" do
    conn(user: fake_user!())
    |> visit("/feed/local")
    |> wait_async()
    |> refute_has("[data-role=save_custom_feed]")
    |> uncheck("Replies")
    |> wait_async()
    |> assert_has("[data-role=save_custom_feed] summary", text: "Save as custom feed")
    |> check("Replies")
    |> wait_async()
    |> refute_has("[data-role=save_custom_feed]")
    |> PhoenixTest.select("Sort", option: "Oldest first")
    |> wait_async()
    |> assert_has("[data-role=save_custom_feed]")
    |> click_button("Reset feed preferences")
    |> wait_async()
    |> refute_has("[data-role=save_custom_feed]")
  end

  # the saved filters, not the URL nor the base's defaults, must be what the reopened feed shows: Local shows replies by default, so a reply missing after reopening comes from the saved "Replies" off
  test "a saved feed reopens with its saved filters" do
    me = fake_user!()
    author = fake_user!()

    root =
      Bonfire.Posts.Fake.fake_post!(author, "public", %{
        post_content: %{html_body: "a root post for the saved feed"}
      })

    Bonfire.Posts.Fake.fake_post!(author, "public", %{
      reply_to_id: root.id,
      post_content: %{html_body: "a reply hidden by the saved feed"}
    })

    name = "saved-replies-" <> to_string(System.unique_integer([:positive]))

    conn(user: me)
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("[data-id=feed] article", text: "a reply hidden by the saved feed")
    |> uncheck("Replies")
    |> wait_async()
    |> fill_in("Feed title", with: name)
    |> click_button("Save feed")
    |> visit("/feed/my")
    |> wait_async()
    |> visit(Bonfire.UI.Social.FeedNavigation.build_path(name))
    |> wait_async()
    |> assert_has("#feed-description-title", text: name)
    |> assert_has("[data-id=feed] article", text: "a root post for the saved feed")
    |> assert_has("input[name='scope[replies]']:not(:checked)")
    |> refute_has("[data-id=feed] article", text: "a reply hidden by the saved feed")
  end

  for show_in_nav <- [true, false], set_as_default <- [true, false] do
    test "save with navbar=#{show_in_nav} and default=#{set_as_default}" do
      name =
        "saved-" <> Faker.Lorem.word() <> "-" <> to_string(System.unique_integer([:positive]))

      session =
        conn(user: fake_user!())
        |> visit("/feed/local")
        |> wait_async()
        |> uncheck("Boosts")
        |> wait_async()
        |> assert_has("[data-role=save_custom_feed]")
        |> fill_in("Feed title", with: name)
        |> fill_in("Feed description", with: "My saved preferences")

      session =
        if unquote(show_in_nav),
          do: session,
          else: uncheck(session, "Show in feeds navbar")

      session =
        if unquote(set_as_default),
          do: check(session, "Set as default feed"),
          else: session

      session =
        session
        |> click_button("Save feed")
        |> visit(Bonfire.UI.Social.FeedNavigation.build_path(name))
        |> wait_async()
        |> assert_has("#feed-description-title", text: name)
        |> assert_has("input[name='scope[boosts]']:not(:checked)")
        # the open feed keeps its tab, so check from another feed
        |> visit("/feed/local")
        |> wait_async()

      # the user's default feed keeps its tab even when it isn't pinned
      session =
        if unquote(show_in_nav) or unquote(set_as_default),
          do: assert_has(session, "#feed-tabs a", text: name),
          else: refute_has(session, "#feed-tabs a", text: name)

      session
      |> click_link("#sidebar-feeds-link", "Feeds")
      |> assert_path(if(unquote(set_as_default), do: "/feed/#{name}", else: "/feed/my"))
      # whether it was pinned, read from its pin switch, as the tab alone can't tell for the default feed
      |> visit("/settings/user/feeds")
      |> wait_async()
      |> assert_has("#pin-feed-preset-#{name}[aria-pressed=#{unquote(show_in_nav)}]")
    end
  end

  # only filters carry over to a saved feed, so a feed whose preset has its own query (`base_query_fun`) offers no save. Bookmarks is the one such preset today, and it hides the widget, so the test adds one that shows it. A function can't be stored in user settings (JSON), so it goes in the process's config override, which `Settings.get` reads first in tests
  defp put_own_query_preset do
    presets =
      Bonfire.Common.Config.get([Bonfire.Social.Feeds, :feed_presets], [])
      |> Keyword.put(:own_query_test, %{
        name: "Own query test",
        built_in: true,
        filters: %Bonfire.Social.FeedFilters{activity_types: [:bookmark]},
        parameterized: %{subjects: [:me]},
        current_user_required: true,
        base_query_fun: &Bonfire.Social.Bookmarks.base_query/0
      })

    Process.put([:bonfire_social, Bonfire.Social.Feeds, :feed_presets], presets)
  end

  # a preset's `parameterized` filters hold the reader (`subjects: [:me]` becomes their user), which the feed controls compare once a preference changes
  test "a feed whose preset has parameterized filters keeps working when a preference changes" do
    put_own_query_preset()

    conn(user: fake_user!())
    |> visit("/feed/own_query_test")
    |> wait_async()
    |> assert_has("[data-role=feed_advanced_filters]")
    |> uncheck("Replies")
    |> wait_async()
    |> assert_has("[data-role=feed_advanced_filters]")
    |> assert_has("input[name='scope[replies]']:not(:checked)")
  end

  test "the save control is hidden on a feed whose preset has its own query" do
    put_own_query_preset()

    conn(user: fake_user!())
    |> visit("/feed/local")
    |> wait_async()
    |> uncheck("Replies")
    |> wait_async()
    |> assert_has("[data-role=save_custom_feed]")
    |> visit("/feed/own_query_test")
    |> wait_async()
    |> assert_has("[data-role=feed_advanced_filters]")
    |> uncheck("Replies")
    |> wait_async()
    |> refute_has("[data-role=save_custom_feed]")
  end

  defp saved_name, do: "saved-base-" <> to_string(System.unique_integer([:positive]))

  # saves the open feed with "Replies" off, then reopens it from another page
  defp save_and_reopen(session, path, name \\ saved_name()) do
    session
    |> visit(path)
    |> wait_async()
    |> uncheck("Replies")
    |> wait_async()
    |> fill_in("Feed title", with: name)
    |> click_button("Save feed")
    |> visit("/settings/user/feeds")
    |> visit(Bonfire.UI.Social.FeedNavigation.build_path(name))
    |> wait_async()
    |> assert_has("#feed-description-title", text: name)
  end

  defp public_post!(author, text),
    do: Bonfire.Posts.Fake.fake_post!(author, "public", %{post_content: %{html_body: text}})

  describe "a saved feed keeps the feed it came from" do
    test "saved from Local, it shows local posts and not remote ones" do
      me = fake_user!()
      public_post!(fake_user!(), "a local post for the saved Local")
      {_remote_post, _} = Bonfire.Social.Fake.create_test_content(:remote, me, fake_user!())

      conn(user: me)
      |> save_and_reopen("/feed/local")
      |> assert_has("[data-id=feed] article", text: "a local post for the saved Local")
      |> refute_has("[data-id=feed] article", text: "content from fediverse")
    end

    test "saved from Following, it shows the people I follow and not a stranger, and someone I follow later" do
      me = fake_user!()
      followed = fake_user!()
      {:ok, _} = Bonfire.Social.Graph.Follows.follow(me, followed)
      public_post!(followed, "a post by someone I follow")
      public_post!(fake_user!(), "a post by a stranger")

      name = saved_name()

      session =
        conn(user: me)
        |> save_and_reopen("/feed/my", name)
        |> assert_has("[data-id=feed] article", text: "a post by someone I follow")
        |> refute_has("[data-id=feed] article", text: "a post by a stranger")

      later = fake_user!()
      {:ok, _} = Bonfire.Social.Graph.Follows.follow(me, later)
      public_post!(later, "a post by someone I followed after saving")

      session
      |> visit(Bonfire.UI.Social.FeedNavigation.build_path(name))
      |> wait_async()
      |> assert_has("[data-id=feed] article", text: "a post by someone I followed after saving")
    end

    test "saved from Explore, it shows local and remote posts" do
      me = fake_user!()
      public_post!(fake_user!(), "a local post for the saved Explore")
      {_remote_post, _} = Bonfire.Social.Fake.create_test_content(:remote, me, fake_user!())

      conn(user: me)
      |> save_and_reopen("/feed/explore")
      |> assert_has("[data-id=feed] article", text: "a local post for the saved Explore")
      |> assert_has("[data-id=feed] article", text: "content from fediverse")
    end
  end
end
