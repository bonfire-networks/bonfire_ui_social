defmodule Bonfire.UI.Social.CommentsEmbedResilienceTest do
  @moduledoc """
  Regression tests for the two latent `CommentsLive.handle_params/3` crashes:

    * the fallback clause used to return the raw `error/2` term instead of
      `{:noreply, socket}`, crashing the LiveView on any unrecognized params;
    * the `media_uri` clause's `with` had no `else`, so a failed resolution
      returned a non-tuple and crashed the visitor's iframe.

  Both must now degrade to the empty state instead of a 500.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  describe "handle_params/3 resilience" do
    test "unrecognized params → empty state via the fallback clause, no crash" do
      # A query string bypasses the static-page cache (which would otherwise
      # rewrite the bare path to `/comments/embed/index.html` and match the
      # :id route). With only unrecognized params we hit the fallback
      # handle_params clause — the one that used to return the raw error/2
      # term and crash instead of {:noreply, socket}.
      {:ok, view, _html} = live(conn(), "/comments/embed?unrelated=1")

      assert render(view) =~ "No comments possible here."
    end

    test "unresolvable media_uri → renders the empty state, does not crash" do
      {:ok, _view, html} =
        live(conn(), "/comments/embed?media_uri=not-a-valid-url")

      assert html =~ "No comments"
    end
  end
end
