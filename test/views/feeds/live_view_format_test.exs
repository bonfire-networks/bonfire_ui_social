defmodule Bonfire.UI.Social.LiveViewFormatTest do
  @moduledoc """
  A LiveView page renders as HTML whatever format the `Accept` header negotiates. When a client asks for plain text, the page renders the way `?_email_format=text` shows it: each component with a text template renders that inside the HTML page.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  # what a crawler sent in prod
  @text_accept "text/plain,text/html,application/xhtml+xml,application/xml"

  setup do
    {:ok, _post} =
      Bonfire.Posts.publish(
        current_user: fake_user!(),
        post_attrs: %{post_content: %{html_body: "a public post for guests"}},
        boundary: "public"
      )

    :ok
  end

  defp get_with_accept(path, accept) do
    conn()
    |> put_req_header("accept", accept)
    |> get(path)
  end

  test "a guest asking for plain text gets the feed as HTML, with its activities as text" do
    # the positive first: the post is in the HTML feed, not as text
    html = get_with_accept("/feed/local", "text/html") |> html_response(200)
    assert html =~ "a public post for guests"
    refute html =~ "<pre>"

    conn = get_with_accept("/feed/local", @text_accept)
    assert ["text/html" <> _] = get_resp_header(conn, "content-type")
    assert html_response(conn, 200) =~ ~r/<pre>[^<]*a public post for guests/
  end

  test "a guest asking for XML gets the feed as HTML" do
    conn = get_with_accept("/feed/local", "application/xml")
    assert ["text/html" <> _] = get_resp_header(conn, "content-type")
    html = html_response(conn, 200)
    assert html =~ "a public post for guests"
    refute html =~ "<pre>"
  end

  test "a guest asking for plain text gets the login page as HTML" do
    conn = get_with_accept("/login", @text_accept)
    assert ["text/html" <> _] = get_resp_header(conn, "content-type")
    assert html_response(conn, 200) =~ "<form"
  end
end
