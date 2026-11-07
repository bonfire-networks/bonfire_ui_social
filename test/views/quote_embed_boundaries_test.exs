defmodule Bonfire.UI.Social.QuoteEmbedBoundariesTest do
  @moduledoc """
  A quote shows the post it quotes only to readers who may read that post. Someone who may read the quoting post but not the quoted one sees the quoting post as if it quoted nothing: no preview, none of the quoted text.
  """
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Posts

  @moduletag :ui

  @quoted_text "the original words only some may read"

  setup do
    # the test default is 2, which would cut the feed's first page short
    Process.put([:bonfire, :default_pagination_limit], 10)

    author = fake_user!("quote_embed_author")

    excluded_account = fake_account!()
    excluded = fake_user!(excluded_account)

    reader_account = fake_account!()
    reader = fake_user!(reader_account)

    {:ok, original} =
      Posts.publish(
        current_user: author,
        post_attrs: %{post_content: %{html_body: @quoted_text}},
        boundary: "public",
        to_circles: %{excluded.id => "cannot_read"}
      )

    original_url = Bonfire.Common.URIs.canonical_url(original, preload_if_needed: true)

    # quoting one's own post needs no approval from the quoted author
    {:ok, quoting} =
      Posts.publish(
        current_user: author,
        post_attrs: %{post_content: %{html_body: "look at this #{original_url}"}},
        boundary: "public"
      )

    {:ok,
     quoting: quoting,
     excluded: conn(user: excluded, account: excluded_account),
     reader: conn(user: reader, account: reader_account)}
  end

  test "in a feed, a reader who may read the quoted post sees it, one who may not sees only the quoting post",
       %{excluded: excluded, reader: reader} do
    # the positive first
    reader
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has(".quote-preview", text: @quoted_text)

    session =
      excluded
      |> visit("/feed/local")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "look at this")
      |> refute_has(".quote-preview")

    refute page_html(session) =~ @quoted_text
  end

  test "on the quoting post's page, the quoted post is shown only to who may read it", %{
    quoting: quoting,
    excluded: excluded,
    reader: reader
  } do
    reader
    |> visit("/post/#{quoting.id}")
    |> wait_async()
    |> assert_has(".quote-preview", text: @quoted_text)

    session =
      excluded
      |> visit("/post/#{quoting.id}")
      |> wait_async()
      |> assert_has("[data-id=object_body]", text: "look at this")
      |> refute_has(".quote-preview")

    refute page_html(session) =~ @quoted_text
  end

  defp page_html(%{view: view}), do: Phoenix.LiveViewTest.render(view)
end
