defmodule Bonfire.UI.Social.CommentsEmbedGuestUsabilityTest do
  @moduledoc """
  Step 1 of embed follow-up (iii): make the generic (non-Ghost) embed usable for guest audiences.

  An anchor is created only when there's a real creator (signed-in viewer, else the configured
  import author) — never an anonymous/sentinel author. Guests never get a connected socket, so
  creation runs on the STATIC render too; guest/empty-state cases are therefore driven through the
  static controller `get/2`, NOT connected `live/2` (which would auto-connect and mask the behavior).
  With no creator, nothing is created and the empty state offers LOCAL sign-in so the blogger can
  sign in and initialize the thread.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Files.Media

  @anon_sentinel "0AND0MSTRANGERS0FF1NTERNET"

  setup do
    Tesla.Mock.mock_global(fn _env ->
      {:ok, %Tesla.Env{status: 200, body: "<html><head><title>A page</title></head></html>"}}
    end)

    :ok
  end

  defp allowlist(origin) do
    System.put_env("IFRAME_ALLOWED_ORIGINS", origin)
    on_exit(fn -> System.delete_env("IFRAME_ALLOWED_ORIGINS") end)
  end

  defp static_get(conn, uri, extra \\ "") do
    get(conn, "/comments/embed?media_uri=#{URI.encode_www_form(uri)}#{extra}")
  end

  test "a guest sees an EXISTING thread (not the empty state) once the anchor exists" do
    author = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], author.id)
    allowlist("https://blog.example.com")
    uri = "https://blog.example.com/existing-thread/"

    # first request creates the anchor
    static_get(conn(), uri) |> html_response(200)
    assert {:ok, media} = Media.get_by_path(uri)

    # a subsequent guest request must render the thread, NOT the "be the first" empty state
    html = static_get(conn(), uri) |> html_response(200)
    refute html =~ "Be the first to comment"
    assert html =~ media.id
  end

  test "a guest sees an existing thread even when the page's canonical URL differs from the media_uri" do
    canonical = "https://blog.example.com/canonical-article/"

    Tesla.Mock.mock_global(fn _env ->
      {:ok,
       %Tesla.Env{
         status: 200,
         body:
           ~s(<html><head><link rel="canonical" href="#{canonical}"/><title>A</title></head></html>)
       }}
    end)

    allowlist("https://blog.example.com")
    account = fake_account!()
    blogger = fake_user!(account)
    # a page URL that differs from the canonical (e.g. tracking params) — the common real case
    page_uri = "https://blog.example.com/page/?utm=abc"

    # the blogger signs in and initializes the thread; the anchor is stored under the CANONICAL url
    {:ok, _v, _h} =
      live(
        conn(user: blogger, account: account),
        "/comments/embed/interactive?media_uri=#{URI.encode_www_form(page_uri)}"
      )

    # the canonical is the primary `path`; the (normalized) media_uri is recorded in metadata.urls and
    # found via the `get_by_url` fallback
    assert {:ok, media} = Media.get_by_path(canonical)
    assert {:ok, %{id: same}} = Media.get_by_url(page_uri)
    assert same == media.id

    # a GUEST (no import author configured) visiting the same page URL must still see the thread,
    # not the empty state — reading an existing thread must not depend on the media_uri matching
    # the stored canonical path
    html = static_get(conn(), page_uri) |> html_response(200)
    refute html =~ "Be the first to comment"
    assert html =~ media.id
  end

  test "a guest sees an existing thread when visiting the trailing-slash variant of the anchored URL" do
    author = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], author.id)
    allowlist("https://blog.example.com")

    # the anchor is created from the URL WITH a trailing slash
    stored = "https://blog.example.com/slash-thread/"
    static_get(conn(), stored) |> html_response(200)
    assert {:ok, media} = Media.get_by_path(stored)

    # now a PURE guest (import author removed, so nothing can be created) arrives at the same page
    # WITHOUT the trailing slash: seeing the thread proves the slash-normalized `urls` index resolved
    # it, and no duplicate anchor was minted under the slash-less path
    Process.delete([:bonfire_ghost, :auto_import_as])
    variant = "https://blog.example.com/slash-thread"
    html = static_get(conn(), variant) |> html_response(200)
    refute html =~ "Be the first to comment"
    assert html =~ media.id
    assert {:error, :not_found} = Media.get_by_path(variant)
  end

  test "a guest sees an existing thread when visiting a tracking-param variant of the anchored URL" do
    author = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], author.id)
    allowlist("https://blog.example.com")

    # the anchor is created from the clean URL (no tracking params)
    stored = "https://blog.example.com/track-thread/"
    static_get(conn(), stored) |> html_response(200)
    assert {:ok, media} = Media.get_by_path(stored)

    # a PURE guest (import author removed, so nothing can be created) arrives at the same page with
    # tracking params: seeing the thread proves the tracking-strip normalization resolved it, and no
    # duplicate anchor was minted under the tracking-carrying path
    Process.delete([:bonfire_ghost, :auto_import_as])
    variant = "https://blog.example.com/track-thread/?utm_source=news&fbclid=xyz"
    html = static_get(conn(), variant) |> html_response(200)
    refute html =~ "Be the first to comment"
    assert html =~ media.id
    assert {:error, :not_found} = Media.get_by_path(variant)
  end

  test "a guest sees an existing thread when visiting a combined slash + tracking variant" do
    author = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], author.id)
    allowlist("https://blog.example.com")

    # the anchor is created from the clean URL WITH a trailing slash and no tracking params
    stored = "https://blog.example.com/both-thread/"
    static_get(conn(), stored) |> html_response(200)
    assert {:ok, media} = Media.get_by_path(stored)

    # a PURE guest arrives WITHOUT the trailing slash AND with tracking params: both normalizations
    # (tracking-strip then slash-strip) must compose to resolve the one anchor, minting no duplicate
    Process.delete([:bonfire_ghost, :auto_import_as])
    variant = "https://blog.example.com/both-thread?utm_source=news&fbclid=xyz"
    html = static_get(conn(), variant) |> html_response(200)
    refute html =~ "Be the first to comment"
    assert html =~ media.id
    assert {:error, :not_found} = Media.get_by_path(variant)
    assert {:error, :not_found} = Media.get_by_path("https://blog.example.com/both-thread")
  end

  test "guest with no configured author: nothing created, empty state offers local sign-in" do
    uri = "https://blog.example.com/no-author/"

    conn = static_get(conn(), uri)
    html = html_response(conn, 200)

    assert {:error, :not_found} = Media.get_by_path(uri)
    assert html =~ "Be the first to comment"
    # a LOCAL sign-in link, not remote interaction (which can't init a non-existent object)
    assert html =~ "embed_empty_signin"
    assert html =~ "/login"
    refute html =~ "/remote_interaction"
  end

  test "empty state shows LOCAL sign-in even when auth_mode=remote (remote can't init a missing object)" do
    uri = "https://blog.example.com/remote-still-local/"

    html =
      conn()
      |> static_get(uri, "&auth_mode=remote")
      |> html_response(200)

    assert html =~ "Be the first to comment"
    assert html =~ "embed_empty_signin"
    assert html =~ "/login"
    refute html =~ "/remote_interaction"
  end

  test "guest + configured import author + allowlisted host: anchor created on the static render" do
    author = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], author.id)
    allowlist("https://blog.example.com")

    uri = "https://blog.example.com/authored/"
    static_get(conn(), uri) |> html_response(200)

    assert {:ok, media} = Media.get_by_path(uri)
    assert media.creator_id == author.id
    refute media.creator_id == @anon_sentinel
  end

  test "guest + configured author but NON-allowlisted host: not created, empty state shown" do
    author = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], author.id)
    allowlist("https://approved.example.com")

    uri = "https://not-approved.example.com/nope/"
    html = static_get(conn(), uri) |> html_response(200)

    assert {:error, :not_found} = Media.get_by_path(uri)
    assert html =~ "Be the first to comment"
  end

  test "host-level allowlist matches any scheme/port/path of an approved domain" do
    author = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], author.id)
    # listed as bare https host; the content URL is http with a port and a deep path
    allowlist("blog.example.com")

    uri = "http://blog.example.com:8080/deep/path/post/"
    static_get(conn(), uri) |> html_response(200)

    assert {:ok, _media} = Media.get_by_path(uri)
  end

  test "no import author configured: a signed-in viewer creates as themselves on an allowlisted domain" do
    account = fake_account!()
    me = fake_user!(account)
    allowlist("https://blog.example.com")
    uri = "https://blog.example.com/mine/"

    {:ok, _view, _html} =
      live(
        conn(user: me, account: account),
        "/comments/embed/interactive?media_uri=#{URI.encode_www_form(uri)}"
      )

    assert {:ok, media} = Media.get_by_path(uri)
    assert media.creator_id == id(me)
    refute media.creator_id == @anon_sentinel
  end

  test "no bypass: a signed-in viewer on a non-allowlisted domain does NOT create" do
    account = fake_account!()
    me = fake_user!(account)
    # domain not allowlisted: the operator hasn't approved it, so even a signed-in viewer can't
    # mint an anchor here (the allowlist applies to everyone)
    uri = "https://not-approved.example.com/x/"

    {:ok, _view, _html} =
      live(
        conn(user: me, account: account),
        "/comments/embed/interactive?media_uri=#{URI.encode_www_form(uri)}"
      )

    assert {:error, :not_found} = Media.get_by_path(uri)
  end

  test "import author configured wins over the signed-in viewer, and its anchor is allowlist-gated" do
    author = fake_user!()
    account = fake_account!()
    me = fake_user!(account)
    Process.put([:bonfire_ghost, :auto_import_as], author.id)

    # a non-allowlisted origin: even a signed-in viewer does not mint an import-author anchor here
    blocked = "https://not-listed.example.com/x/"

    live(
      conn(user: me, account: account),
      "/comments/embed/interactive?media_uri=#{URI.encode_www_form(blocked)}"
    )

    assert {:error, :not_found} = Media.get_by_path(blocked)

    # an allowlisted origin: created, attributed to the IMPORT AUTHOR (not the incidental viewer)
    allowlist("https://listed.example.com")
    ok = "https://listed.example.com/y/"

    live(
      conn(user: me, account: account),
      "/comments/embed/interactive?media_uri=#{URI.encode_www_form(ok)}"
    )

    assert {:ok, media} = Media.get_by_path(ok)
    assert media.creator_id == author.id
    refute media.creator_id == id(me)
  end

  test "end to end: guest sees the empty state + local sign-in, then a signed-in return creates the thread and enables commenting" do
    account = fake_account!()
    me = fake_user!(account)
    allowlist("https://blog.example.com")
    uri = "https://blog.example.com/e2e/"
    url = "/comments/embed/interactive?media_uri=#{URI.encode_www_form(uri)}"

    # BEFORE sign-in: guest, no import author → nothing created (allowlisted domain, but no creator),
    # empty state invites local sign-in
    {:ok, _guest_view, guest_html} = live(conn(), url)
    assert {:error, :not_found} = Media.get_by_path(uri)
    assert guest_html =~ "Be the first to comment"
    assert guest_html =~ "embed_empty_signin"
    refute guest_html =~ "/remote_interaction"

    # AFTER sign-in: the blogger returns signed in (the sign-in redirect lands back on the embed) →
    # the mount creates the anchor attributed to them, and the composer replaces the empty state
    {:ok, _signed_view, signed_html} = live(conn(user: me, account: account), url)
    assert {:ok, media} = Media.get_by_path(uri)
    assert media.creator_id == id(me)
    refute signed_html =~ "Be the first to comment"
    # the reply composer slot for the new thread is present (commenting enabled)
    assert signed_html =~ "reply-slot-#{media.id}"
  end
end
