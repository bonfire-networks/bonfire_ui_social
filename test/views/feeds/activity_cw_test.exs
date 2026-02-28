defmodule Bonfire.UI.Social.ActivityCW.Test do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  import Tesla.Mock

  setup do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)

    conn = conn(user: me, account: account)

    mock_global(fn
      %{method: :get, url: "https://example.com/elixir-phoenix"} ->
        %Tesla.Env{status: 200, body: "<title>Web Title Test</title>"}

      _ ->
        %Tesla.Env{status: 404, body: ""}
    end)

    {:ok, conn: conn, account: account, alice: alice, me: me}
  end

  test "content warning hides text content behind CW toggle",
       %{conn: conn, me: me} do
    html_body = "epic html message"
    cw = "new cw"

    attrs = %{
      sensitive: true,
      post_content: %{
        html_body: html_body,
        summary: cw
      }
    }

    {:ok, _post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")

    conn
    |> visit("/feed/local")
    # CW text is displayed
    |> assert_has("[data-role=cw]", text: cw)
    # Body text is in the DOM but inside a hidden wrapper
    |> assert_has("[data-id=activity_note] div.hidden", text: html_body)
    # Show button is visible
    |> assert_has(".show_more_toggle_action", text: "Show")
  end

  test "content warning blurs images behind sensitive overlay",
       %{conn: conn, me: me} do
    media = Fake.upload_media(:images, me)

    attrs = %{
      sensitive: true,
      post_content: %{
        html_body: "post with image",
        summary: "sensitive image"
      },
      uploaded_media: [media]
    }

    {:ok, _post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")

    conn
    |> visit("/feed/local")
    # CW toggle is shown
    |> assert_has("[data-role=cw]", text: "sensitive image")
    # Image has sensitive content overlay button
    |> assert_has("button", text: "Sensitive content")
  end

  test "content warning hides link previews behind CW toggle",
       %{conn: conn, me: me} do
    html_body = "Check out https://example.com/elixir-phoenix"
    cw = "link cw"

    attrs = %{
      sensitive: true,
      post_content: %{
        html_body: html_body,
        summary: cw
      }
    }

    {:ok, _post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")

    conn
    |> visit("/feed/local")
    |> wait_async()
    # CW text is displayed
    |> assert_has("[data-role=cw]", text: cw)
    # Link preview exists but is hidden behind the CW toggle
    |> open_browser()
    |> assert_has_or_open_browser("[data-id=media_link]")
    |> assert_has("div.hidden [data-id=media_link]")
  end

  test "content warning hides quoted posts behind CW toggle",
       %{conn: conn, me: me} do
    # Create a post to quote
    {:ok, original} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "original post"}},
        boundary: "public"
      )

    original_url = Bonfire.Common.URIs.canonical_url(original)

    # Create a post with CW that quotes the original (include URL in body to create quote tag)
    attrs = %{
      sensitive: true,
      post_content: %{
        html_body: "quoting with cw #{original_url}",
        summary: "quote cw"
      }
    }

    {:ok, _post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")

    conn
    |> visit("/feed/local")
    # CW text is displayed
    |> open_browser()
    |> assert_has("[data-role=cw]", text: "quote cw")
    # Quoted post is hidden (inside a wrapper with hidden class)
    |> assert_has("div.hidden .quote-preview")
  end

  test "a quoted post with CW shows its own CW overlay",
       %{conn: conn, me: me} do
    # Create a post with CW
    {:ok, sensitive_post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{
          sensitive: true,
          post_content: %{html_body: "hidden content", summary: "trigger warning"}
        },
        boundary: "public"
      )

    sensitive_url = Bonfire.Common.URIs.canonical_url(sensitive_post)

    # Create a post that quotes the sensitive post (without its own CW)
    attrs = %{
      post_content: %{html_body: "look at this quote #{sensitive_url}"}
    }

    {:ok, _post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")

    conn
    |> visit("/feed/local")
    # The quoting post text is visible
    |> open_browser()
    |> assert_has("[data-id=activity_note]", text: "look at this quote")
    # The quoted post has its own CW toggle
    |> assert_has(".quote-preview [data-role=cw]", text: "trigger warning")
  end
end
