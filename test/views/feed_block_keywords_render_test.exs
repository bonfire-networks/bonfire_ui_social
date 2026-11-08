defmodule Bonfire.UI.Social.FeedBlockKeywordsRenderTest do
  @moduledoc """
  A post matching one of the keywords the viewer hides completely (their `reject` list) is gone wherever the UI would show it, as if deleted: no feed card, no quote or reply preview, no live update. In a thread it leaves the note a deleted post leaves, so the replies under it keep their place. Nothing of its title, content warning or text is in the page. A viewer without that keyword sees it as usual.

  The keywords are stored in the viewer's settings row, as the settings page does.
  """
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Posts
  alias Bonfire.Boundaries.BlockKeywords

  @moduletag :ui

  @placeholder "[Content blocked by filters]"
  # what a deleted post leaves in a thread
  @gone "may have been deleted"

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

  test "a matching post has no card, and nothing of it is in the page", %{
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

    session =
      filtered
      |> visit("/feed/local")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "Just a regular post")
      |> refute_has("[data-id=feed]", text: @placeholder)
      |> assert_has("[data-id=feed] .translate-btn-server", count: 1)

    refute page_html(session) =~ "Amazing deal on viagra"
  end

  test "a post whose title matches is gone too, title included", %{
    author: author,
    filtered: filtered,
    unfiltered: unfiltered
  } do
    publish!(author, %{name: "Cheap viagra here", html_body: "an innocent body"})
    publish!(author, %{html_body: "Just a regular post"})

    unfiltered
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "an innocent body")

    session =
      filtered
      |> visit("/feed/local")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "Just a regular post")

    html = page_html(session)
    refute html =~ "Cheap viagra here"
    refute html =~ "an innocent body"
  end

  test "a quoted post that matches has no preview, the quoting post its text", %{
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
    |> assert_has(".quote-preview", text: "Amazing deal on viagra")

    session =
      filtered
      |> visit("/feed/local")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "look at this")
      |> refute_has(".quote-preview")

    refute page_html(session) =~ "Amazing deal on viagra"
  end

  test "in a thread, a matching reply leaves the note a deleted post leaves, and the replies under it stay",
       %{author: author, filtered: filtered, unfiltered: unfiltered} do
    op = publish!(author, %{html_body: "A normal opening post"})
    spam = publish!(author, %{html_body: "Buy viagra now"}, reply_to_id: op.id)
    publish!(author, %{html_body: "A reply to the spam"}, reply_to_id: spam.id)
    publish!(author, %{html_body: "A thoughtful reply"}, reply_to_id: op.id)

    unfiltered
    |> visit("/discussion/#{op.id}")
    |> assert_has("[data-id='comment']", text: "Buy viagra now")
    |> assert_has("[data-id='comment']", text: "A reply to the spam")

    session =
      filtered
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-id='comment']", text: "A thoughtful reply")
      |> assert_has("[data-id='comment']", text: "A reply to the spam")
      # (a LiveView page has no `body` element to scope to: an assertion on one finds nothing)
      |> assert_has("[data-role=comment-unavailable]", text: @gone)
      |> refute_has("[data-id='comment']", text: @placeholder)

    refute page_html(session) =~ "Buy viagra now"
  end

  test "in a thread whose opening post matches, it leaves the note a deleted post leaves, and the replies stay",
       %{author: author, filtered: filtered} do
    op = publish!(author, %{html_body: "Opening post selling viagra"})
    publish!(author, %{html_body: "A thoughtful reply"}, reply_to_id: op.id)

    session =
      filtered
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-id='comment']", text: "A thoughtful reply")
      |> assert_has("#thread_main_object", text: @gone)

    refute page_html(session) =~ "Opening post selling viagra"
  end

  describe "keywords the viewer hides behind a warning" do
    setup do
      warned_account = fake_account!()
      warned = fake_user!(warned_account)
      {:ok, _} = BlockKeywords.put_warn_keywords_settings(["viagra"], current_user: warned)

      {:ok, warned: conn(user: warned, account: warned_account)}
    end

    test "a matching post shows closed behind \"Hidden by filters\", its text inside", %{
      author: author,
      warned: warned
    } do
      publish!(author, %{html_body: "Amazing deal on viagra"})

      warned
      |> visit("/feed/local")
      |> wait_async()
      |> assert_has("[data-id=feed] [data-role=cw]", text: "Hidden by filters")
      # the content is there, closed until the warning is opened
      |> assert_has("[data-id=feed] .hidden", text: "Amazing deal on viagra")
      |> refute_has("[data-id=feed]", text: @placeholder)
    end

    test "its title and its own summary are inside too, not on the warning", %{
      author: author,
      warned: warned
    } do
      publish!(author, %{
        name: "Cheap viagra here",
        summary: "the author's own summary",
        html_body: "an innocent body"
      })

      warned
      |> visit("/feed/local")
      |> wait_async()
      |> assert_has("[data-id=feed] [data-role=cw]", text: "Hidden by filters")
      |> refute_has("[data-id=feed] [data-role=cw]", text: "the author's own summary")
      |> assert_has("[data-id=feed] .hidden", text: "Cheap viagra here")
      |> assert_has("[data-id=feed] .hidden", text: "the author's own summary")
      |> assert_has("[data-id=feed] .hidden", text: "an innocent body")
    end
  end

  test "a matching post arriving live doesn't show, while one after it does", %{
    author: author,
    filtered: filtered
  } do
    session = visit(filtered, "/feed/local")

    Task.start(fn ->
      publish!(author, %{html_body: "Live deal on viagra"})
      publish!(author, %{html_body: "A live regular post"})
    end)

    session
    |> assert_has("[data-id=feed]", text: "A live regular post", timeout: 3000)
    |> refute_has("[data-id=feed]", text: "Live deal on viagra")
    |> refute_has("[data-id=feed]", text: @placeholder)
  end
end
