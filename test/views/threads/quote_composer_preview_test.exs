defmodule Bonfire.UI.Social.QuoteComposerPreview.Test do
  @moduledoc """
  The composer previews what is being quoted. The preview is a card like any other, so it shows the post only from a boundary that says the viewer may read it, which quoting has to load for it.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, me: me, conn: conn(user: me, account: account)}
  end

  test "quoting a post I can read previews it in the composer", %{conn: conn} do
    author = fake_user!()

    {:ok, post} =
      Posts.publish(
        current_user: author,
        post_attrs: %{post_content: %{html_body: "<p>worth quoting</p>"}},
        boundary: "public"
      )

    conn
    |> visit("/post/#{id(post)}")
    |> wait_async()
    |> PhoenixTest.unwrap(fn view ->
      view |> element("[data-role=quote_enabled][phx-value-id='#{id(post)}']") |> render_click()
      # the press reaches the composer as a message to its `PersistentLive`; rendering that child is a synchronous call, so the quote is set up before the composer is read (as `TopicReplyDestinationTest` does for a reply)
      composer = composer_view(view)
      render(composer)
      assert has_element?(composer, "#quote_in_composer", "worth quoting")
      refute has_element?(composer, "#quote_in_composer [data-role^=restricted]")
      # `unwrap` takes the rendered page back, not the view
      render(view)
    end)
  end

  # broadcasting a post opens the composer on it the same way, previewed below as a quote
  test "broadcasting a post previews it in the composer" do
    account = fake_account!()
    admin = fake_admin!(account)
    author = fake_user!()

    {:ok, post} =
      Posts.publish(
        current_user: author,
        post_attrs: %{post_content: %{html_body: "<p>worth broadcasting</p>"}},
        boundary: "public"
      )

    conn(user: admin, account: account)
    |> visit("/post/#{id(post)}")
    |> wait_async()
    |> PhoenixTest.unwrap(fn view ->
      view
      |> element("[data-role=broadcast_enabled][phx-value-id='#{id(post)}']")
      |> render_click()

      composer = composer_view(view)
      render(composer)
      assert has_element?(composer, "#quote_in_composer", "worth broadcasting")
      refute has_element?(composer, "#quote_in_composer [data-role^=restricted]")
      render(view)
    end)
  end
end
