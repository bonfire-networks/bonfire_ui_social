defmodule Bonfire.UI.Social.CommentsEmbedApRedirectTest do
  @moduledoc """
  Site owners can put `<link rel="alternate" type="application/activity+json" href="https://<bonfire>/comments/embed?media_uri=<page url>">` in their page template. A fediverse server that is handed the page URL then follows that link, and the embed route must answer an ActivityPub request with a redirect to the page's Media post, never with the embed HTML. A missing post follows the same rules as an embed load: it is created only when an import author is configured and the host is allowlisted.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Files.Media

  setup do
    Tesla.Mock.mock_global(fn _env ->
      {:ok, %Tesla.Env{status: 200, body: "<html><head><title>A page</title></head></html>"}}
    end)

    System.put_env("IFRAME_ALLOWED_ORIGINS", "https://blog.example.com")
    on_exit(fn -> System.delete_env("IFRAME_ALLOWED_ORIGINS") end)

    :ok
  end

  defp ap_get(page) do
    conn()
    |> put_req_header("accept", "application/activity+json")
    |> get("/comments/embed?media_uri=#{URI.encode_www_form(page)}")
  end

  defp browser_get(page),
    do: get(conn(), "/comments/embed?media_uri=#{URI.encode_www_form(page)}")

  defp ap_id!(media) do
    assert {:ok, %{data: %{"id" => ap_id}}} = ActivityPub.Object.get_cached(pointer: media)
    ap_id
  end

  test "an existing post: redirects to its ActivityPub id, and browsers still get the embed" do
    author = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], author.id)
    page = "https://blog.example.com/existing/"

    browser_get(page) |> html_response(200)
    assert {:ok, media} = Media.get_by_path(page)

    conn = ap_get(page)
    assert redirected_to(conn, 302) == ap_id!(media)

    assert "accept" in (conn
                        |> get_resp_header("vary")
                        |> Enum.flat_map(&String.split(&1, ~r/,\s*/))
                        |> Enum.map(&String.downcase/1))

    # the redirect must not be served to a browser from a cache, nor the HTML to a fetcher
    assert browser_get(page) |> html_response(200) =~ media.id
  end

  test "a missing post with an import author: created, then redirected to" do
    author = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], author.id)
    page = "https://blog.example.com/first-fetch/"

    conn = ap_get(page)

    assert {:ok, media} = Media.get_by_path(page)
    assert redirected_to(conn, 302) == ap_id!(media)
  end

  test "a missing post without an import author: 404, nothing created" do
    page = "https://blog.example.com/no-author/"

    assert ap_get(page).status == 404
    assert {:error, :not_found} = Media.get_by_path(page)
  end

  test "a host that is not allowlisted: 404, nothing created" do
    author = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], author.id)
    page = "https://elsewhere.example.org/article/"

    assert ap_get(page).status == 404
    assert {:error, :not_found} = Media.get_by_path(page)
  end
end
