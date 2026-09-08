defmodule Bonfire.UI.Social.Threads.FediverseReactionsTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes

  setup do
    account = fake_account!()
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    {:ok, post} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "<p>An original post</p>"}},
        boundary: "public"
      )

    {:ok, conn: conn(user: alice, account: account), alice: alice, bob: bob, post: post}
  end

  test "shows all reaction totals at zero without modal links", %{conn: conn, post: post} do
    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("[data-role=boosts_summary]", text: "0 Boosts")
    |> assert_has("[data-role=likes_summary]", text: "0 Likes")
    |> refute_has("[data-role=quotes_summary]")
    |> refute_has("[data-role=fediverse_reactions] button")
    |> refute_has("[data-role=replies_summary]")
  end

  test "keeps the likes and boosts modals separate on the post view", %{
    conn: conn,
    alice: alice,
    bob: bob,
    post: post
  } do
    assert {:ok, _} = Likes.like(bob, post)
    assert {:ok, _} = Boosts.boost(alice, post)

    conn
    |> visit("/post/#{post.id}")
    |> assert_has("[data-role=likes_summary]", text: "1 Like")
    |> click_button("[data-role=likes_summary] button", "1 Like")
    |> assert_has("[data-role=liker]", text: bob.profile.name)
    |> refute_has("[data-role=liker]", text: alice.profile.name)
    |> click_button("[data-role=close-modal]", "Close")
    |> click_button("[data-role=boosts_summary] button", "1 Boost")
    |> assert_has("[role=dialog]", text: "Boosted by")
    |> assert_has("[data-role=booster]", text: alice.profile.name)
    |> refute_has("[data-role=booster]", text: bob.profile.name)
  end

  @tag skip: "Quote counters are temporarily disabled pending production query performance work"
  test "opens quote authors and omits the reply counter", %{conn: conn, bob: bob, post: post} do
    publish_quote(bob, post)

    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("[data-role=quotes_summary]", text: "1 Quote")
    |> refute_has("[data-role=replies_summary]")
    |> refute_has("[data-role=quoter_list]")
    |> click_button("[data-role=quotes_summary] button", "1 Quote")
    |> assert_has("[role=dialog]", text: "Quoted by")
    |> assert_has("[data-role=quoter]", text: bob.profile.name)
    |> assert_has("[data-role=quoter] a[href='#{path(bob)}']")
    |> click_button("[data-role=close-modal]", "Close")
    |> refute_has(".modal-open")
  end

  @tag skip: "Quote counters are temporarily disabled pending production query performance work"
  test "quote totals and authors exclude hidden posts and deduplicate authors", %{
    conn: conn, alice: alice, bob: bob, post: post
  } do
    {:ok, reply} = Posts.publish(
      current_user: alice,
      post_attrs: %{post_content: %{html_body: Faker.Lorem.sentence()}, reply_to_id: post.id},
      boundary: "public"
    )
    publish_quote(bob, post)
    publish_quote(bob, reply)
    carol = fake_user!()
    publish_quote(carol, post, "mentions")

    conn
    |> visit("/post/#{post.id}")
    |> assert_has("[data-role=quotes_summary]", text: "2 Quotes")
    |> refute_has("[data-role=replies_summary]")
    |> click_button("[data-role=quotes_summary] button", "2 Quotes")
    |> assert_has("[data-role=quoter]", count: 1)
    |> assert_has("[data-role=quoter]", text: bob.profile.name)
    |> refute_has("[data-role=quoter]", text: carol.profile.name)
  end

  @tag skip: "Quote counters are temporarily disabled pending production query performance work"
  test "deduplicates authors across quote pages", %{conn: conn, alice: alice, bob: bob, post: post} do
    publish_quote(bob, post)
    for _ <- 1..19, do: publish_quote(alice, post)
    publish_quote(bob, post)

    conn
    |> visit("/discussion/#{post.id}")
    |> click_button("[data-role=quotes_summary] button", "21 Quotes")
    |> assert_has("[data-role=quoter]", count: 2)
    |> click_button("[data-role=quoter_list] button", "Load more")
    |> assert_has("[data-role=quoter]", count: 2)
    |> assert_has("[data-role=quoter]", text: bob.profile.name)
    |> assert_has("[data-role=quoter]", text: alice.profile.name)
    |> refute_has("[data-role=quoter_list] button", text: "Load more")
  end

  for {context, action, role, label, title} <- [
        {Boosts, :boost, "booster", "Boost", "Boosted by"},
        {Likes, :like, "liker", "Like", "Liked by"}
      ] do
    test "#{action} modal exposes the next page and appends its people", %{conn: conn, post: post} do
      people = for _ <- 1..21, do: fake_user!()
      for person <- people, do: assert({:ok, _} = apply(unquote(context), unquote(action), [person, post]))
      oldest_person = List.first(people)

      conn
      |> visit("/discussion/#{post.id}")
      |> click_button("[data-role=#{unquote(action)}s_summary] button", "21 #{unquote(label)}s")
      |> assert_has("[data-role=#{unquote(role)}]", count: 20)
      |> refute_has("[data-role=#{unquote(role)}]", text: oldest_person.profile.name)
      |> click_button("[data-role=#{unquote(role)}_list] button", "Load more")
      |> assert_has("[data-role=#{unquote(role)}]", count: 21)
      |> assert_has("[data-role=#{unquote(role)}]", text: oldest_person.profile.name)
      |> refute_has("[data-role=#{unquote(role)}_list] button", text: "Load more")
    end

    test "#{action} totals and people exclude replies on both discussion routes", %{conn: conn, alice: alice, bob: bob, post: post} do
      carol = fake_user!()
      {:ok, reply} = Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: Faker.Lorem.sentence()}, reply_to_id: post.id},
        boundary: "public"
      )
      assert {:ok, _} = apply(unquote(context), unquote(action), [bob, reply])
      assert {:ok, _} = apply(unquote(context), unquote(action), [carol, reply])

      for route <- ["/discussion/#{post.id}", "/post/#{post.id}"] do
        conn
        |> visit(route)
        |> assert_has("[data-role=#{unquote(action)}s_summary]", text: "0 #{unquote(label)}s")
        |> refute_has("[data-role=#{unquote(action)}s_summary] button")
      end

      assert {:ok, _} = apply(unquote(context), unquote(action), [bob, post])

      for route <- ["/discussion/#{post.id}", "/post/#{post.id}"] do
        conn
        |> visit(route)
        |> click_button("[data-role=#{unquote(action)}s_summary] button", "1 #{unquote(label)}")
        |> assert_has("[data-role=#{unquote(role)}]", count: 1)
        |> assert_has("[data-role=#{unquote(role)}]", text: bob.profile.name)
        |> refute_has("[data-role=#{unquote(role)}]", text: carol.profile.name)
        |> refute_has("[data-role=#{unquote(role)}_list] button", text: "Load more")
      end
    end

    test "#{action} opens its people list on demand and closes", %{conn: conn, bob: bob, post: post} do
      avatar_url = "https://example.org/avatars/#{bob.id}.png"
      {:ok, icon} = Bonfire.Files.Media.insert(bob, avatar_url, %{media_type: "image/png", size: 0}, %{url: avatar_url})
      {:ok, bob} = Bonfire.Me.Profiles.set_profile_image(:icon, bob, icon)
      assert {:ok, _} = apply(unquote(context), unquote(action), [bob, post])
      role = unquote(role)
      summary = "[data-role=#{unquote(action)}s_summary]"

      conn
      |> visit("/discussion/#{post.id}")
      |> refute_has("[data-role=#{role}_list]")
      |> click_button("#{summary} button", "1 #{unquote(label)}")
      |> assert_has("[role=dialog]", text: unquote(title))
      |> assert_has("[data-role=#{role}]", text: bob.profile.name)
      |> assert_has("[data-role=#{role}] a[href='#{path(bob)}']")
      |> assert_has("[data-role=#{role}] img[src='#{avatar_url}']")
      |> refute_has("[data-role=#{role}_list] button", text: "Load more")
      |> click_button("[data-role=close-modal]", "Close")
      |> refute_has(".modal-open")
    end

    test "#{action} lists each author once and excludes other threads", %{conn: conn, alice: alice, bob: bob, post: post} do
      carol = fake_user!()
      {:ok, reply} = Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: Faker.Lorem.sentence()}, reply_to_id: post.id},
        boundary: "public"
      )
      {:ok, other_post} = Posts.publish(
        current_user: carol,
        post_attrs: %{post_content: %{html_body: Faker.Lorem.sentence()}},
        boundary: "public"
      )
      assert {:ok, _} = apply(unquote(context), unquote(action), [bob, post])
      assert {:ok, _} = apply(unquote(context), unquote(action), [bob, reply])
      assert {:ok, _} = apply(unquote(context), unquote(action), [carol, other_post])
      role = unquote(role)

      conn
      |> visit("/discussion/#{post.id}")
      |> click_button("[data-role=#{unquote(action)}s_summary] button", unquote(label))
      |> assert_has("[data-role=#{role}]", count: 1)
      |> assert_has("[data-role=#{role}]", text: bob.profile.name)
      |> refute_has("[data-role=#{role}]", text: carol.profile.name)
    end
  end

  for {context, action} <- [{Boosts, :boost}, {Likes, :like}] do
    test "#{action} queries advance the cursor without repeating records", %{alice: alice, bob: bob, post: post} do
      assert {:ok, first} = apply(unquote(context), unquote(action), [alice, post])
      assert {:ok, second} = apply(unquote(context), unquote(action), [bob, post])
      opts = [current_user: alice, limit: 1, preload: :subject]
      page = unquote(context).list_paginated([objects: post.id], opts)
      next_page = unquote(context).list_paginated([objects: post.id], opts ++ [after: page.page_info.end_cursor])

      assert Enum.map(page.edges ++ next_page.edges, & &1.id) == [second.id, first.id]
      assert next_page.page_info.end_cursor == nil
    end
  end

  defp publish_quote(user, quoted, boundary \\ "public") do
    {:ok, post} = Posts.publish(
      current_user: user,
      post_attrs: %{post_content: %{html_body: Faker.Lorem.sentence()}},
      quotes: [quoted],
      boundary: boundary
    )
    if user.id == quoted.created.creator_id do
      post
    else
      {:ok, accepted} = Bonfire.Social.Quotes.accept_quote(post, quoted, current_user: quoted.created.creator_id)
      accepted
    end
  end
end
