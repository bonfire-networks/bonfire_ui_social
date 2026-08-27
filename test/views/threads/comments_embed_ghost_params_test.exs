defmodule Bonfire.UI.Social.CommentsEmbedGhostParamsTest do
  @moduledoc """
  Covers the Ghost/CMS canonical-* param routing in `EmbedCommentsLive`:

    * `?canonical_slug=` and `?canonical_id=` reach `handle_ghost_params/4`;
    * navigation only looks up articles imported by webhooks/backfill;
    * when Ghost isn't configured (the default in test), the view degrades to the empty state
      without creating a generic media anchor or returning a 500.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Files.Media

  describe "canonical_* (Ghost) params" do
    test "canonical_slug with no resolvable article → empty state, no crash" do
      {:ok, view, _html} =
        live(conn(), "/comments/embed?canonical_slug=some-ghost-post")

      assert render(view) =~ "Be the first to comment"
    end

    test "canonical_id with no resolvable article → empty state, no crash" do
      {:ok, view, _html} =
        live(conn(), "/comments/embed?canonical_id=01ABCDEF")

      assert render(view) =~ "Be the first to comment"
    end

    test "canonical_slug with media_uri does not create a generic anchor" do
      bot = fake_user!()
      Process.put([:bonfire_ghost, :auto_import_as], bot.id)
      uri = "https://blog.example.com/not-imported/"

      {:ok, view, _html} =
        live(
          conn(),
          "/comments/embed?canonical_slug=some-ghost-post&media_uri=#{URI.encode_www_form(uri)}"
        )

      assert render(view) =~ "Be the first to comment"
      assert {:error, :not_found} = Media.get_by_path(uri)
    end
  end
end
