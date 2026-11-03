defmodule Bonfire.UI.Social.CommentsEmbedInviteOnlyTest do
  @moduledoc """
  The logged-out prompt under the comments embed must not push visitors toward a signup they cannot complete: on an invite-only instance that federates, replying with an existing fediverse account comes first, and "Sign in" stays for existing members.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  setup do
    user = fake_user!()

    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: "an embedded article"}},
        boundary: "public"
      )

    {:ok, post: post}
  end

  # an allowed email domain closes open signup, which is what makes an instance invite-only in :test
  defp invite_only! do
    Process.put([:bonfire_me, Bonfire.Me.Accounts, :allowed_email_domains], ["example.com"])
    assert Bonfire.Me.Accounts.instance_is_invite_only?()
  end

  defp guest_embed(post), do: conn() |> get("/comments/embed/#{post.id}") |> html_response(200)

  test "invite-only and federating: the prompt is remote-first and keeps Sign in", %{post: post} do
    invite_only!()
    assert Bonfire.Federate.ActivityPub.federating?()

    html = guest_embed(post)

    assert html =~ "inline_composer_remote_interaction_"
    assert html =~ "Reply with your existing account from any fediverse server"
    refute html =~ "to leave comments"
    assert html =~ "Sign in"
  end

  test "an open instance still invites people to join", %{post: post} do
    refute Bonfire.Me.Accounts.instance_is_invite_only?()

    html = guest_embed(post)

    assert html =~ "to leave comments"
  end

  test "invite-only with federation off offers no remote interaction", %{post: post} do
    invite_only!()
    # the test-safe override read by `federating_default?/1` through ProcessTree
    Process.put(:federating, false)
    refute Bonfire.Federate.ActivityPub.federating?()

    html = guest_embed(post)

    refute html =~ "inline_composer_remote_interaction_"
    assert html =~ "Sign in"
  end
end
