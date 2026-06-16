defmodule Bonfire.UI.Social.CommentsEmbedTeleportTest do

  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  setup do
    account = fake_account!()
    user = fake_user!(account)

    {:ok, root} =
      Bonfire.Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: "root post"}},
        boundary: "public"
      )

    {:ok, reply} =
      Bonfire.Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: "a reply"}, reply_to_id: root.id},
        boundary: "public"
      )

    {:ok, user: user, root: root, reply: reply}
  end

  describe "per-comment teleport slots exist in both thread modes" do
    test "FLAT mode embed renders a reply-slot + action-slot for each comment",
         %{root: root, reply: reply} do
      {:ok, view, _html} = live(conn(), "/comments/embed/#{root.id}?mode=flat")
      html = render(view)

      # Regression: before the fix, flat mode rendered no per-comment slots,
      # so the composer could not teleport next to the clicked comment.
      assert html =~ "reply-slot-#{reply.id}",
             "flat mode must render a per-comment reply-slot for the composer to teleport into"

      assert html =~ "action-slot-#{reply.id}",
             "flat mode must render a per-comment action-slot for inline report/block"
    end

    test "NESTED mode embed also renders a per-comment reply-slot (parity)",
         %{root: root, reply: reply} do
      {:ok, view, _html} = live(conn(), "/comments/embed/#{root.id}?mode=nested")
      html = render(view)

      assert html =~ "reply-slot-#{reply.id}"
    end

    test "embed renders a top-level action-slot for the root object",
         %{root: root} do
      {:ok, view, _html} = live(conn(), "/comments/embed/#{root.id}?mode=flat")
      html = render(view)

      assert html =~ "action-slot-#{root.id}",
             "the root object must have an action-slot so report/block on it has a portal target"
    end
  end
end
