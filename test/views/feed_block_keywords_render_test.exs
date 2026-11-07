defmodule Bonfire.UI.Social.FeedBlockKeywordsRenderTest do
  @moduledoc """
  A post matching one of the viewer's filtered keywords shows as "[Content blocked by filters]" wherever the UI shows it (a feed card, a quote or reply preview, a thread, a live update), with nothing of its title, content warning or text. A viewer without that keyword sees it as usual.

  The keywords are stored in the viewer's settings row, as the settings page does.
  """
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Posts
  alias Bonfire.Boundaries.BlockKeywords

  @moduletag :ui

  @placeholder "[Content blocked by filters]"

  setup do
    # the test default is 2, which would cut the feed's first page short
    Process.put([:bonfire, :default_pagination_limit], 10)

    author = fake_user!("kw_render_author")

    filtered_account = fake_account!()
    filtered = fake_user!(filtered_account)
    {:ok, _} = BlockKeywords.put_block_keywords_settings(["viagra"], current_user: filtered)

    unfiltered_account = fake_account!()
    unfiltered = fake_user!(unfiltered_account)

    {:ok,
     author: author,
     filtered: conn(user: filtered, account: filtered_account),
     unfiltered: conn(user: unfiltered, account: unfiltered_account)}
  end

  defp publish!(author, post_content, opts \\ []) do
    {:ok, post} =
      Posts.publish(
        current_user: author,
        post_attrs: Map.merge(%{post_content: post_content}, Map.new(opts)),
        boundary: "public"
      )

    post
  end

  # the page's HTML, attributes included (an edit-title input carries the title in its `value`)
  defp page_html(%{view: view}), do: Phoenix.LiveViewTest.render(view)

  test "a matching post's card shows the placeholder, not its text", %{
    author: author,
    filtered: filtered,
    unfiltered: unfiltered
  } do
    publish!(author, %{html_body: "Amazing deal on viagra"})
    publish!(author, %{html_body: "Just a regular post"})

    unfiltered
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "Amazing deal on viagra")
    |> assert_has("[data-id=feed] .translate-btn-server", count: 2)

    filtered
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "Just a regular post")
    |> assert_has("[data-id=feed]", text: @placeholder)
    |> refute_has("[data-id=feed]", text: "Amazing deal on viagra")
    # translating loads the post itself, so the placeholder offers no translation
    |> assert_has("[data-id=feed] .translate-btn-server", count: 1)
  end

  test "a post whose title matches hides its title and text, in the card and in the page", %{
    author: author,
    filtered: filtered,
    unfiltered: unfiltered
  } do
    publish!(author, %{name: "Cheap viagra here", html_body: "an innocent body"})

    unfiltered
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "an innocent body")

    session =
      filtered
      |> visit("/feed/local")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: @placeholder)
      |> refute_has("[data-id=feed]", text: "an innocent body")

    html = page_html(session)
    refute html =~ "Cheap viagra here"
    refute html =~ "an innocent body"
  end

  test "a quoted post that matches shows the placeholder, the quoting post its text", %{
    author: author,
    filtered: filtered,
    unfiltered: unfiltered
  } do
    original = publish!(author, %{html_body: "Amazing deal on viagra"})
    original_url = Bonfire.Common.URIs.canonical_url(original, preload_if_needed: true)

    # quoting one's own post needs no approval from the quoted author
    publish!(author, %{html_body: "look at this #{original_url}"})

    unfiltered
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has(".quote-preview")
    |> assert_has(".quote-preview", text: "Amazing deal on viagra")

    filtered
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "look at this")
    |> assert_has(".quote-preview", text: @placeholder)
    |> refute_has(".quote-preview", text: "Amazing deal on viagra")
  end

  test "in a thread, a matching reply shows the placeholder, the others their text", %{
    author: author,
    filtered: filtered,
    unfiltered: unfiltered
  } do
    op = publish!(author, %{html_body: "A normal opening post"})
    publish!(author, %{html_body: "Buy viagra now"}, reply_to_id: op.id)
    publish!(author, %{html_body: "A thoughtful reply"}, reply_to_id: op.id)

    unfiltered
    |> visit("/discussion/#{op.id}")
    |> assert_has("[data-id='comment']", count: 2)
    |> assert_has("[data-id='comment']", text: "Buy viagra now")

    filtered
    |> visit("/discussion/#{op.id}")
    |> assert_has("[data-id='comment']", count: 2)
    |> assert_has("[data-id='comment']", text: "A thoughtful reply")
    |> assert_has("[data-id='comment']", text: @placeholder)
    |> refute_has("[data-id='comment']", text: "Buy viagra now")
  end

  test "in a thread whose opening post matches, the opening post shows the placeholder and the replies their text",
       %{author: author, filtered: filtered} do
    op = publish!(author, %{html_body: "Opening post selling viagra"})
    publish!(author, %{html_body: "A thoughtful reply"}, reply_to_id: op.id)

    filtered
    |> visit("/discussion/#{op.id}")
    |> assert_has("[data-id='comment']", text: "A thoughtful reply")
    |> assert_has("#thread_main_object", text: @placeholder)
    |> refute_has("body", text: "Opening post selling viagra")
  end

  test "a matching post arriving live shows as the placeholder, not missing", %{
    author: author,
    filtered: filtered
  } do
    session = visit(filtered, "/feed/local")

    Task.start(fn -> publish!(author, %{html_body: "Live deal on viagra"}) end)

    session
    |> assert_has("[data-id=feed]", text: @placeholder, timeout: 3000)
    |> refute_has("[data-id=feed]", text: "Live deal on viagra")
  end
end
