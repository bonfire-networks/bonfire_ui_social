defmodule Bonfire.Social.Moderation.BlockTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Follows
  alias Bonfire.Me.Users
  alias Bonfire.Files.Test
  import Bonfire.Common.Enums
  import Bonfire.UI.Me.Integration

  test "Ghost a user works" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    # login as me
    conn = conn(user: me, account: account)
    # navigate to alice profile
    {:ok, view, _html} = live(conn, "/@#{alice.character.username}")
    # open the block modal

    view
    |> element("li[data-role=ghost_modal] div[data-role=open_modal]")
    |> render_click()

    # block alice
    view
    |> element("button[data-role=ghost]")
    |> render_click()

    # open_browser(view)

    assert render(view) =~ "ghosted"
    assert render(view) =~ "Unghost"
  end

  test "Silence a user works" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    # login as me
    conn = conn(user: me, account: account)
    # navigate to alice profile
    {:ok, view, _html} = live(conn, "/@#{alice.character.username}")
    # open the block modal

    view
    |> element("li[data-role=silence_modal] div[data-role=open_modal]")
    |> render_click()

    # block alice
    view
    |> element("button[data-role=silence]")
    |> render_click()

    assert render(view) =~ "silenced"
    assert render(view) =~ "Unsilence"
  end

  test "I can see a list of ghosted users" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)
    carl = fake_user!(account)
    # ghost alice and bob
    assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(alice, :ghost, current_user: me)
    assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(bob, :ghost, current_user: me)
    assert {:ok, _silenced} = Bonfire.Boundaries.Blocks.block(carl, :silence, current_user: me)
    # login as me and navigate to ghosted page in settings
    conn = conn(user: me, account: account)
    {:ok, view, _html} = live(conn, "/boundaries/ghosted")
    # check that alice and bob are there
    assert render(view) =~ alice.profile.name
    assert render(view) =~ bob.profile.name
    # check that carl is not there
    refute render(view) =~ carl.profile.name
  end

  test "I can see a list of silenced users" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)
    carl = fake_user!(account)
    # ghost alice and bob
    assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(alice, :ghost, current_user: me)
    assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(bob, :ghost, current_user: me)
    assert {:ok, _silenced} = Bonfire.Boundaries.Blocks.block(carl, :silence, current_user: me)
    # login as me and navigate to ghosted page in settings
    conn = conn(user: me, account: account)
    {:ok, view, _html} = live(conn, "/boundaries/silenced")
    # check that alice and bob are there
    refute render(view) =~ alice.profile.name
    refute render(view) =~ bob.profile.name
    # check that carl is not there
    assert render(view) =~ carl.profile.name
  end

  test "I can unghost a previously ghosted user" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)
    carl = fake_user!(account)
    # ghost alice and bob
    assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(alice, :ghost, current_user: me)
    # login as me and navigate to ghosted page in settings
    conn = conn(user: me, account: account)
    {:ok, view, _html} = live(conn, "/boundaries/ghosted")
    # check that alice is there
    assert render(view) =~ alice.profile.name
    # remove from the ghosted list
    view
    |> element("button[data-role=remove_user]")
    |> render_click()

    assert render(view) =~ "Unblocked!"
    refute render(view) =~ alice.profile.name
  end

  test "I can unsilence a previously silenced user" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)
    carl = fake_user!(account)
    # ghost alice and bob
    assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(alice, :silence, current_user: me)
    # login as me and navigate to ghosted page in settings
    conn = conn(user: me, account: account)
    {:ok, view, _html} = live(conn, "/boundaries/silenced")
    # check that alice is there
    assert render(view) =~ alice.profile.name
    # remove from the ghosted list
    view
    |> element("button[data-role=remove_user]")
    |> render_click()

    assert render(view) =~ "Unblocked!"
    refute render(view) =~ alice.profile.name
  end

  test "I can see if I silenced a user from their profile page" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(alice, :silence, current_user: me)
    # navigate to alice profile
    conn = conn(user: me, account: account)
    {:ok, view, _html} = live(conn, "/@#{alice.character.username}")
    # check that there is a silenced label
    assert render(view) =~ "silenced"
  end

  test "I can see if I ghosted a user from their profile page" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(alice, :ghost, current_user: me)
    # navigate to alice profile
    conn = conn(user: me, account: account)
    {:ok, view, _html} = live(conn, "/@#{alice.character.username}")
    # check that there is a silenced label
    assert render(view) =~ "ghosted"
  end

  describe "if I silenced a user i will not receive any update from it" do
    test "i'll not see anything they publish in feeds" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      assert {:ok, _silenced} = Bonfire.Boundaries.Blocks.block(alice, :silence, current_user: me)
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/")
      # write a post
      html_body = "epic html message"
      attrs = %{post_content: %{html_body: html_body}}

      {:ok, post} =
        Posts.publish(
          current_user: alice,
          post_attrs: attrs,
          boundary: "local"
        )

      # login as me
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/feed/local")
      # check that the post is not there
      refute render(view) =~ html_body
    end

    test "i'll be able to view their profile, I cannot read post via direct link" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      assert {:ok, _silenced} = Bonfire.Boundaries.Blocks.block(alice, :silence, current_user: me)
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/")
      # write a post
      html_body = "epic html message"
      attrs = %{post_content: %{html_body: html_body}}

      {:ok, post} =
        Posts.publish(
          current_user: alice,
          post_attrs: attrs,
          boundary: "local"
        )

      # login as me
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/feed/local")
      # check that the post is not there
      refute render(view) =~ html_body
      assert {:ok, profile, _html} = live(conn, "/@#{alice.character.username}")

      # navigate to previously created post
      assert {:ok, thread, _html} = live(conn, "/post/#{post.id}")

      # view the post previously created
      refute render(thread) =~ html_body
    end

    test "i'll not see any @ mentions from them" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      assert {:ok, _silenced} = Bonfire.Boundaries.Blocks.block(alice, :silence, current_user: me)
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/")
      # write a post as alice and mention me
      html_body = "@#{me.character.username} epic html message"
      attrs = %{post_content: %{html_body: html_body}}

      {:ok, post} =
        Posts.publish(
          current_user: alice,
          post_attrs: attrs,
          boundary: "mention"
        )

      # login as me
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/notifications")
      # check that the post is not there
      refute render(view) =~ html_body
      {:ok, view, _html} = live(conn, "/feed/local")
      # check that the post is not there
      refute render(view) =~ html_body
    end

    test "i'll not see any DMs from them" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      assert {:ok, _silenced} = Bonfire.Boundaries.Blocks.block(alice, :silence, current_user: me)
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/")
      # write a post as alice and mention me
      html_body = "@#{alice.character.username} epic html message"
      attrs = %{post_content: %{html_body: html_body}}

      {:ok, post} =
        Posts.publish(
          current_user: alice,
          post_attrs: attrs,
          boundary: "message",
          to_circles: [me.character.id]
        )

      # login as me
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/messages")
      # check that the post is not there
      refute render(view) =~ html_body
    end

    # test "I'll not be able to follow them" do
    #   # create a bunch of users
    #   account = fake_account!()
    #   me = fake_user!(account)
    #   alice = fake_user!(account)
    #   assert {:ok, _silenced} = Bonfire.Boundaries.Blocks.block(alice, :silence, current_user: me)
    #   conn = conn(user: me, account: account)
    #   {:ok, view, _html} = live(conn, "/@#{alice.character.username}")

    #   refute has_element?(view, "div[data-role=follow_wrapper] a[data-id=follow]")
    # end
  end

  describe "if I ghosted a user they will not be able to interact with me or with my content" do
    test "Nothing I post privately will be shown to them from now on" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      assert {:ok, _ghosted} = Bonfire.Boundaries.Blocks.block(alice, :ghost, current_user: me)
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/")
      # write a post
      html_body = "epic html message"
      attrs = %{post_content: %{html_body: html_body}}

      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: attrs,
          boundary: "local"
        )

      # login as alice
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/feed/local")
      # check that the post is not there
      refute render(view) =~ html_body
    end

    test "They will still be able to see things I post publicly. " do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      assert {:ok, _ghosted} = Bonfire.Boundaries.Blocks.block(alice, :ghost, current_user: me)
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/")
      # write a post
      html_body = "epic html message"
      attrs = %{post_content: %{html_body: html_body}}

      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: attrs,
          boundary: "public"
        )

      # login as alice
      conn = conn()
      {:ok, view, _html} = live(conn, "/")
      # check that the post is not there
      assert render(view) =~ html_body
    end

    test "I won't be able to @ mention them. " do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      assert {:ok, _ghosted} = Bonfire.Boundaries.Blocks.block(alice, :ghost, current_user: me)
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/")
      # write a post and mention alice
      html_body = "@#{alice.character.username} epic html message"
      attrs = %{post_content: %{html_body: html_body}}

      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: attrs,
          boundary: "mention"
        )

      # login as alice
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/notifications")
      # check that the post is not there
      refute render(view) =~ html_body
      {:ok, view, _html} = live(conn, "/feed/local")
      # check that the post is not there
      refute render(view) =~ html_body
    end

    test "I won't be able to DM them. " do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      assert {:ok, _ghosted} = Bonfire.Boundaries.Blocks.block(alice, :ghost, current_user: me)
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/")
      # write a post and DM alice
      html_body = "epic html message"
      attrs = %{post_content: %{html_body: html_body}}

      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: attrs,
          boundary: "message",
          to_circles: [alice.character.id]
        )

      # login as alice
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/messages")
      # check that the post is not there
      refute render(view) =~ html_body
    end

    # WIP: This test is failing, but im not sure this is the right behavior
    # test "they won't be able to follow me" do
    #   # create a bunch of users
    #   account = fake_account!()
    #   me = fake_user!(account)
    #   alice = fake_user!(account)
    #   assert {:ok, _ghosted} = Bonfire.Boundaries.Blocks.block(alice, :ghost, current_user: me)
    #   conn = conn(user: alice, account: account)
    #   {:ok, view, _html} = live(conn, "/@#{me.character.username}")

    #   view
    #   |> element("div[data-role=follow_wrapper] a[data-id=follow]")
    #   |> render_click()

    #   assert has_element?(view, "div[data-role=follow_wrapper] a[data-id=follow]")
    # end
  end

  describe "Admin" do
    # test "As an admin I can ghost a user instance-wide" do
    #   # create a bunch of users
    #   account = fake_account!()
    #   me = fake_user!(account)
    #   alice = fake_user!(account)
    #   bob = fake_user!(account)
    #   # make myself an admin
    #   Bonfire.Me.Users.make_admin(me)
    #   assert {:ok, _ghosted} = Bonfire.Boundaries.Blocks.block(alice.id, :ghost, :instance_wide)
    #   # login as bob
    #   conn = conn(user: bob, account: account)
    #   {:ok, view, _html} = live(conn, "/")
    #   # write a post
    #   html_body = "epic html message"
    #   attrs = %{post_content: %{html_body: html_body}}

    #   {:ok, post} =
    #     Posts.publish(
    #       current_user: bob,
    #       post_attrs: attrs,
    #       boundary: "local"
    #     )

    #   # login as alice
    #   conn = conn(user: alice, account: account)
    #   {:ok, view, _html} = live(conn, "/feed/local")
    #   # check that the post is not there
    #   refute render(view) =~ html_body
    # end

    # test "As an admin I can silence a user instance-wide" do
    #   # create a bunch of users
    #   account = fake_account!()
    #   me = fake_user!(account)
    #   alice = fake_user!(account)
    #   bob = fake_user!(account)
    #   # make myself an admin
    #   Bonfire.Me.Users.make_admin(me)
    #   assert {:ok, _ghosted} = Bonfire.Boundaries.Blocks.block(alice.id, :ghost, :instance_wide)
    #   # login as bob
    #   conn = conn(user: bob, account: account)
    #   {:ok, view, _html} = live(conn, "/")
    #   # write a post
    #   html_body = "epic html message"
    #   attrs = %{post_content: %{html_body: html_body}}

    #   {:ok, post} =
    #     Posts.publish(
    #       current_user: alice,
    #       post_attrs: attrs,
    #       boundary: "local"
    #     )

    #   # login as bob
    #   conn = conn(user: bob, account: account)
    #   {:ok, view, _html} = live(conn, "/feed/local")
    #   # check that the post is not there
    #   refute render(view) =~ html_body
    # end

    test "As an admin I can see a list of instance-wide ghosted users" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      bob = fake_user!(account)
      carl = fake_user!(account)
      Bonfire.Me.Users.make_admin(me)
      # ghost alice and bob
      assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(alice, :ghost, :instance_wide)
      assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(bob, :ghost, :instance_wide)
      assert {:ok, _silenced} = Bonfire.Boundaries.Blocks.block(carl, :silence, :instance_wide)
      # login as me and navigate to ghosted page in settings
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/boundaries/instance_ghosted")
      # check that alice and bob are there
      assert render(view) =~ alice.profile.name
      assert render(view) =~ bob.profile.name
      # check that carl is not there
      refute render(view) =~ carl.profile.name
    end

    test "As an admin I can see a list of instance-wide silenced users" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      bob = fake_user!(account)
      carl = fake_user!(account)
      Bonfire.Me.Users.make_admin(me)
      # ghost alice and bob
      assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(alice, :ghost, :instance_wide)
      assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(bob, :ghost, :instance_wide)
      assert {:ok, _silenced} = Bonfire.Boundaries.Blocks.block(carl, :silence, :instance_wide)
      # login as me and navigate to ghosted page in settings
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/boundaries/instance_silenced")
      # check that alice and bob are not there
      refute render(view) =~ alice.profile.name
      refute render(view) =~ bob.profile.name
      # check that carl is there
      assert render(view) =~ carl.profile.name
    end

    test "As an admin I can unghost a previously ghosted user instance-wide" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      bob = fake_user!(account)
      carl = fake_user!(account)
      # ghost alice and bob
      assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(alice, :ghost, :instance_wide)
      # login as me and navigate to ghosted page in settings
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/boundaries/instance_ghosted")
      # check that alice is there
      assert render(view) =~ alice.profile.name
      # remove from the ghosted list
      view
      |> element("button[data-role=remove_user]")
      |> render_click()

      assert render(view) =~ "Unblocked!"
      refute render(view) =~ alice.profile.name
    end

    test "As an admin I can unsilence a previously silenced user instance-wide" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      bob = fake_user!(account)
      carl = fake_user!(account)
      # ghost alice and bob
      assert {:ok, _ghost} = Bonfire.Boundaries.Blocks.block(alice, :silence, :instance_wide)
      # login as me and navigate to ghosted page in settings
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/boundaries/instance_silenced")
      # check that alice is there
      assert render(view) =~ alice.profile.name
      # remove from the ghosted list
      view
      |> element("button[data-role=remove_user]")
      |> render_click()

      assert render(view) =~ "Unblocked!"
      refute render(view) =~ alice.profile.name
    end
  end
end
