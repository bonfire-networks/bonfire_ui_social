defmodule Bonfire.UI.Social.FeedBlockKeywordsReplyPreviewTest do
  @moduledoc """
  A post matching one of the viewer's filtered keywords is not shown anywhere in the feed, including as the inline preview of the post a reply answers.

  The keywords are stored in the viewer's settings row, as in production.
  """
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Posts
  alias Bonfire.Boundaries.BlockKeywords

  @moduletag :ui

  @spam "Amazing deal on viagra"

  setup do
    # the test default is 2, which would cut the feed's first page short
    Process.put([:bonfire, :default_pagination_limit], 10)

    author = fake_user!("kw_reply_author")
    replier = fake_user!("kw_reply_replier")

    {:ok, spam_post} =
      Posts.publish(
        current_user: author,
        post_attrs: %{post_content: %{html_body: @spam}},
        boundary: "public"
      )

    {:ok, _reply} =
      Posts.publish(
        current_user: replier,
        post_attrs: %{post_content: %{html_body: "A reply to it"}, reply_to: spam_post.id},
        boundary: "public"
      )

    unfiltered = fake_user!("kw_reply_viewer_unfiltered")
    filtered = fake_user!("kw_reply_viewer_filtered")

    {:ok, _} = BlockKeywords.put_block_keywords_settings(["viagra"], current_user: filtered)
    filtered = Bonfire.Common.Repo.preload(filtered, :settings, force: true)

    {:ok, unfiltered: unfiltered, filtered: filtered}
  end

  test "without filtered keywords the feed shows the post and, inline, the reply's original", %{
    unfiltered: viewer
  } do
    conn(user: viewer, account: viewer.account)
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "A reply to it")
    |> assert_has("[data-id=feed]", text: @spam)
    # the reply's inline preview of the post it answers is its own element, with this id prefix
    |> assert_has("[id*=reply_to_activity]", text: @spam)
  end

  test "a post matching a filtered keyword is hidden everywhere, including as a reply's preview",
       %{filtered: viewer} do
    conn(user: viewer, account: viewer.account)
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "A reply to it")
    |> refute_has("[data-id=feed]", text: @spam)
  end
end
