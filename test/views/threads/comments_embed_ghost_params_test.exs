defmodule Bonfire.UI.Social.CommentsEmbedGhostParamsTest do
  @moduledoc """
  Covers the Ghost/CMS canonical-* param routing in `EmbedCommentsLive`:

    * `?canonical_slug=` and `?canonical_id=` reach `handle_ghost_params/4`;
    * when Ghost isn't configured (the default in test), the lookup returns
      `{:error, :ghost_not_configured}` and the view must degrade gracefully —
      falling back to `media_uri` when present, or the empty state otherwise —
      never a 500.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  describe "canonical_* (Ghost) params" do
    test "canonical_slug with no resolvable article → empty state, no crash" do
      {:ok, view, _html} =
        live(conn(), "/comments/embed?canonical_slug=some-ghost-post")

      assert render(view) =~ "No comments"
    end

    test "canonical_id with no resolvable article → empty state, no crash" do
      {:ok, view, _html} =
        live(conn(), "/comments/embed?canonical_id=01ABCDEF")

      assert render(view) =~ "No comments"
    end

    test "canonical_slug falls back to media_uri when Ghost is unconfigured" do
      # ghost_not_configured → retries with the media_uri clause; an invalid
      # URI then degrades to the empty state rather than crashing.
      {:ok, view, _html} =
        live(
          conn(),
          "/comments/embed?canonical_slug=some-ghost-post&media_uri=not-a-valid-url"
        )

      assert render(view) =~ "No comments"
    end
  end
end
