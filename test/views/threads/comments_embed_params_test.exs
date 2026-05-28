defmodule Bonfire.UI.Social.CommentsEmbedParamsTest do
  @moduledoc """
  Closes the documented-but-untested gap: the embed loader
  (`comments_embed.js`) maps `data-*` attributes onto query params, and
  `EmbedCommentsLive.mount/3` turns those into socket assigns. These tests assert
  that param → assign mapping for the deterministic, mount-level options.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Me.Accounts

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  setup do
    account = fake_account!()
    user = fake_user!(account)
    {:ok, account} = Accounts.confirm_email(account)

    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: "embed params post"}},
        boundary: "public"
      )

    {:ok, account: account, user: user, post: post}
  end

  describe "data-* → query param → assign mapping in mount/3" do
    test "data-sort-by maps to the :sort_by assign (as an atom); unrelated opts stay nil",
         %{post: post} do
      {:ok, view, _html} =
        live(conn(), "/comments/embed/#{post.id}?sort_by=latest_reply")

      a = assigns(view)
      assert a.sort_by == :latest_reply
      # opts not present in the query string default to nil
      assert a.sort_order == nil
      assert a.embed_theme == nil
    end

    test "data-sort-order maps to the :sort_order assign (as an atom)", %{post: post} do
      {:ok, view, _html} =
        live(conn(), "/comments/embed/#{post.id}?sort_by=like_count&sort_order=asc")

      assert assigns(view).sort_by == :like_count
      assert assigns(view).sort_order == :asc
    end

    test "data-theme maps to the :embed_theme assign", %{post: post} do
      {:ok, view, _html} =
        live(conn(), "/comments/embed/#{post.id}?theme=dark")

      assert assigns(view).embed_theme == "dark"
    end

    test "data-* (mode) maps to the :thread_mode assign", %{post: post} do
      {:ok, view, _html} =
        live(conn(), "/comments/embed/#{post.id}?mode=flat")

      assert assigns(view).thread_mode == :flat
    end

    test "data-auth-mode maps to the :auth_mode assign and renders the remote-interaction CTA for guests",
         %{post: post} do
      {:ok, view, html} =
        live(conn(), "/comments/embed/#{post.id}?auth_mode=remote")

      assert assigns(view).auth_mode == "remote"
      # guest sees the single remote-interaction button, not Login/Register
      assert html =~ "inline_composer_remote_interaction_"
      assert html =~ "/remote_interaction?type=reply"
      refute html =~ "inline_composer_login_"
    end

    test "without data-auth-mode, guests see the local Login/Register CTA", %{post: post} do
      {:ok, view, html} =
        live(conn(), "/comments/embed/#{post.id}?sort_by=newest")

      assert assigns(view).auth_mode == nil
      assert html =~ "inline_composer_login_"
      refute html =~ "inline_composer_remote_interaction_"
    end
  end
end
