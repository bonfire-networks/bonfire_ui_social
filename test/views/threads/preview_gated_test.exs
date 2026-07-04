defmodule Bonfire.UI.Social.PreviewGatedTest do
  @moduledoc """
  The activity PREVIEW modal (opened by clicking a feed card) renders
  `Bonfire.UI.Social.ObjectThreadLive` with the feed's already-loaded object. For a top-of-thread object it must NOT expose the full `html_body` to a viewer who can `:see` (discover) the object but not `:read` it — otherwise see-only gated articles leak their body through the preview.

  PhoenixTest can't fire the JS hook that opens the modal, so (as in `load_object_test.exs`) we render `ObjectThreadLive` directly with the same `modal_assigns` shape that `ActivityLive.thread_preview_modal_assigns/6` produces.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.Objects
  alias Bonfire.UI.Social.ActivityLive

  @teaser "TEASER-VISIBLE-INTRO"
  # placed AFTER a long filler so it only appears when the FULL body renders — the feed
  # card truncates (~280 chars) so a short marker would show even when truncated.
  @filler String.duplicate("filler word blah ", 30)
  @secret "SECRET-DEEP-BODY-xyz"

  defp long_body, do: "<p>#{@teaser} #{@filler}</p><p>#{@secret}</p>"

  setup do
    author = fake_user!(fake_account!())
    # a different local user who can :see but not :read the object below
    viewer_account = fake_account!()
    viewer = fake_user!(viewer_account)
    {:ok, author: author, viewer: viewer, viewer_account: viewer_account}
  end

  # a see-only object: locals (like `viewer`) get :see but not :read; the creator reads.
  defp see_only_post(author) do
    {:ok, post} =
      Posts.publish(
        current_user: author,
        post_attrs: %{post_content: %{html_body: long_body()}},
        boundary: "local:preview"
      )

    # what the feed hands the preview: the fully-loaded object (incl. html_body),
    # preloaded exactly like the feed/`load_object_assigns` would.
    {:ok, full} =
      Objects.read(post.id,
        current_user: author,
        preload: Bonfire.Social.Objects.LiveHandler.default_preloads()
      )

    {post, full}
  end

  defp preview_assigns(full, post) do
    ActivityLive.thread_preview_modal_assigns(
      post.id,
      post.id,
      e(full, :activity, :id, nil),
      e(full, :activity, nil),
      full,
      nil
    )
  end

  # The `:read` re-check the preview relies on: `maybe_check_boundaries` (what
  # `ActivityLive.update_many` runs) nulls `object`/`activity` when the viewer may
  # `:see` but not `:read` it. `current_user` is read from the assigns tuple's
  # `__context__`, not opts.
  defp check_boundaries(assigns, user) do
    assigns = Map.put(assigns, :__context__, %{current_user: user})
    socket = %{assigns: assigns}

    [{gated, _socket}] =
      Bonfire.Boundaries.LiveHandler.maybe_check_boundaries([{assigns, socket}])

    gated
  end

  test "a :see-but-not-:read viewer's preview object is nulled by the :read re-check", %{
    author: author,
    viewer: viewer
  } do
    {post, full} = see_only_post(author)
    gated = preview_assigns(full, post) |> Map.new() |> check_boundaries(viewer)

    assert is_nil(gated[:object])
    assert is_nil(gated[:activity])
  end

  test "the author (who can :read) keeps the object through the :read re-check", %{
    author: author
  } do
    {post, full} = see_only_post(author)
    gated = preview_assigns(full, post) |> Map.new() |> check_boundaries(author)

    refute is_nil(gated[:object])
  end

  # The actual `:read` re-check happens in `ActivityLive`'s `update_many` →
  # `maybe_check_boundaries`, which only runs inside a real mounted LiveView (not under
  # `render_stateful`). So we verify (a) the preview is configured to trigger it, and
  # (b) an actual feed page doesn't leak the body to a see-only viewer (below).
  test "the top-of-thread preview is configured to re-check :read (stateful + boundary check)",
       %{author: author} do
    {post, full} = see_only_post(author)
    assigns = preview_assigns(full, post)

    assert Keyword.get(assigns, :modal_component_stateful?) == true
    assert Keyword.get(assigns, :check_object_boundary) == true
  end

  test "the feed shows the see-only article's excerpt but NOT its full body", %{
    author: author,
    viewer: viewer,
    viewer_account: viewer_account
  } do
    {:ok, _article} =
      Posts.publish(
        current_user: author,
        # render as an Article → feed shows the preview card (truncated, no full body)
        schema: Bonfire.Articles.Article,
        post_attrs: %{
          post_content: %{
            name: "Paywalled Headline",
            html_body: long_body()
          }
        },
        boundary: "local:preview"
      )

    conn(user: viewer, account: viewer_account)
    |> visit("/feed/local")
    # the card renders (headline + truncated intro) …
    |> assert_has("article", text: "Paywalled Headline")
    # … but the deep body past the truncation is never sent to the client
    |> refute_has("article", text: @secret)
  end

  test "the feed shows the see-only article's primary image", %{
    author: author,
    viewer: viewer,
    viewer_account: viewer_account
  } do
    {:ok, _article} =
      Posts.publish(
        current_user: author,
        schema: Bonfire.Articles.Article,
        post_attrs: %{
          post_content: %{
            name: "Paywalled Image Headline",
            html_body: long_body()
          },
          uploaded_media: [
            %{
              "href" => "https://example.com/paid-cover.jpg",
              "alt" => "Paid article cover",
              "primary_image" => true
            }
          ]
        },
        boundary: "local:preview"
      )

    conn(user: viewer, account: viewer_account)
    |> visit("/feed/local")
    |> assert_has("article", text: "Paywalled Image Headline")
    |> assert_has("[data-id=article_cover]")
    |> refute_has("article", text: @secret)
  end
end
