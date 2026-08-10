defmodule Bonfire.UI.Social.FeedControllerTest do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  alias Bonfire.Posts

  test "serves the local feed as atom" do
    user = fake_user!()

    {:ok, post} =
      Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: "an atom feed entry"}},
        boundary: "public"
      )

    # assert the precondition separately: if the activity never reached the :local feed, fail here (naming the cause) rather than further down on an empty XML document, which can't tell a publishing/boundary problem apart from a rendering one
    assert Bonfire.Social.FeedLoader.feed_contains?(:local, post),
           "the published post is missing from the :local feed, so the feed data is at fault rather than the atom rendering"

    conn = get(conn(), "/feed/local/feed.atom")

    assert conn.status == 200
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "application/atom+xml"
    assert response(conn, 200) =~ "an atom feed entry"
  end

  test "an unknown feed name renders a 404 instead of crashing (was: uncaught throw :not_found)" do
    # Bonfire.Fail implements Plug.Exception, so in prod it renders a 404 page;
    # in tests the raise surfaces wrapped with the 404 plug_status
    assert error =
             assert_raise(Bonfire.Fail, fn ->
               get(conn(), "/feed/no_such_feed_preset/feed.atom")
             end)

    assert Plug.Exception.status(error) == 404
  end
end
