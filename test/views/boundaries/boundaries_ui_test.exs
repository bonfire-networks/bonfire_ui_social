defmodule Bonfire.Social.Activities.BoundariesUITest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Follows
  import Bonfire.Common.Enums


  test "As a user I can switch from 'public' to 'local' when creating a new post" do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)

    # login
    conn = conn(user: me, account: account)
    {:ok, view, _html} = live(conn, "/feed")

    # Open the composer
    assert view
    |> element("button[data-role=composer_button]")
    |> open_browser()
    |> render_click() =~ "Share your thoughts"

  end

  test "As a user I can add a circle to the composer boundaries when I create a new post " do

  end

  test "As a user I can add a user to the composer boundaries when I create a new post" do

  end

  test "As a user I can remove a previously added user and circle from the composer boundaries when I create a new post" do

  end

  test "As a user I can switch from 'public' to 'mention only' when creating a new post" do

  end

  test "As a user I can switch from 'public' to 'custom' when creating a new post" do

  end

  test "As a user I can switch from 'public' to a custom boundary previously created when creating a new post" do

  end


end
