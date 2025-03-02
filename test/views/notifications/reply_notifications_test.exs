defmodule Bonfire.Social.Notifications.Threads.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows

 
  describe "show" do
    # FIXME: should this be expected behaviour? (without @ mention)
    @tag :skip_ci
    test "replies I'm allowed to see (even from people I'm not following) in my notifications", %{conn: conn} do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      attrs = %{post_content: %{html_body: "<p>here is an epic html post</p>"}}

      assert {:ok, post} =
               Posts.publish(current_user: someone, post_attrs: attrs, boundary: "public")

      responder = fake_user!()

      attrs_reply = %{
        post_content: %{summary: "summary", name: "name 2", html_body: "<p>epic html reply</p>"},
        reply_to_id: post.id
      }

      assert {:ok, _post_reply} =
               Posts.publish(current_user: responder, post_attrs: attrs_reply, boundary: "public")

      conn(user: someone, account: some_account)
      |> visit("/notifications")
      |> assert_has(".feed", text: "epic html reply")
    end
  end

  describe "DO NOT show" do
    test "replies I'm NOT allowed to see in my notifications" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      attrs = %{post_content: %{html_body: "<p>here is an epic html post</p>"}}
      assert {:ok, post} = Posts.publish(current_user: someone, post_attrs: attrs)

      responder = fake_user!()

      attrs_reply = %{
        post_content: %{summary: "summary", name: "name 2", html_body: "epic html reply"},
        reply_to_id: post.id
      }

      assert {:ok, _post_reply} = Posts.publish(current_user: responder, post_attrs: attrs_reply)

      conn(user: someone, account: some_account)
      |> visit("/notifications")
      |> refute_has(".feed", text: "epic html reply")
    end
  end
end