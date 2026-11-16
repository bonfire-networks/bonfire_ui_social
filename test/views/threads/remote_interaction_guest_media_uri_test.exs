defmodule Bonfire.UI.Social.RemoteInteractionGuestMediaUriTest do
  @moduledoc """
  `/remote_interaction?media_uri=...` is a GET that a guest, with no session, can request with any address on an allowlisted host (`IFRAME_ALLOWED_ORIGINS`) when an import author is configured (`:bonfire_ghost, :auto_import_as`). It starts the page's thread, but only for an address its origin actually serves (never for one that answers 404), and only a few times a minute from one IP, so a guest cannot fill the instance with posts by the import author.

  The control is the comments embed of the same allowlisted host, which starts a thread for the page, so the setup (import author, allowlist) is known to be working.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Files.Media

  @origin "https://blog.local"
  # the attempts one IP may make per minute through this page (the default of `EmbedThreads`)
  @max_per_minute 5

  setup do
    bot = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], bot.id)

    System.put_env("IFRAME_ALLOWED_ORIGINS", @origin)
    on_exit(fn -> System.delete_env("IFRAME_ALLOWED_ORIGINS") end)

    # the limiter may be switched off for the test run (ENABLE_RATE_LIMIT=no)
    Process.put([:bonfire, :rate_limit, :disabled], false)

    # each test starts with the limit unused (the counters outlive a test)
    for ip <- ["unknown", "127.0.0.1"],
        do: Bonfire.UI.Common.RateLimit.set("embed_threads:#{ip}", 60_000, 0)

    {:ok, bot: bot}
  end

  defp random_uri, do: "#{@origin}/#{Needle.UID.generate()}"

  defp page_exists!,
    do:
      Tesla.Mock.mock_global(fn _env ->
        {:ok, %Tesla.Env{status: 200, body: "<html><head><title>Article</title></head></html>"}}
      end)

  defp page_missing!,
    do: Tesla.Mock.mock_global(fn _env -> {:ok, %Tesla.Env{status: 404, body: "not found"}} end)

  defp visit_remote_interaction(conn, uri),
    do: live(conn, "/remote_interaction?type=reply&media_uri=#{URI.encode_www_form(uri)}")

  test "control: the comments embed of an allowlisted page creates its thread, as the import author",
       %{bot: bot} do
    page_exists!()
    uri = random_uri()

    {:ok, _view, _html} = live(conn(), "/comments/embed?media_uri=#{URI.encode_www_form(uri)}")

    assert {:ok, media} = Media.get_by_path(uri)
    assert media.creator_id == bot.id
  end

  test "a guest loading it for an address that does not exist at its origin creates no post" do
    page_missing!()
    uri = random_uri()

    {:ok, _view, _html} = visit_remote_interaction(conn(), uri)

    assert {:error, :not_found} = Media.get_by_path(uri),
           "a guest's GET made a post for #{uri}, which its origin does not serve"
  end

  test "control: a guest loading it for an address its origin serves starts the thread, as the import author",
       %{bot: bot} do
    page_exists!()
    uri = random_uri()

    {:ok, _view, _html} = visit_remote_interaction(conn(), uri)

    assert {:ok, media} = Media.get_by_path(uri)
    assert media.creator_id == bot.id
  end

  # the guest's own IP has used up its attempts, so the page (which keys the limit on the connection's address) starts no thread for a served address. Asserting the outcome rather than reading the counter back: a counter lives in a fixed time window, which can roll over between the page's hit and the read
  test "the page counts a guest's attempt against the guest's own IP" do
    page_exists!()
    Bonfire.UI.Common.RateLimit.set("embed_threads:127.0.0.1", 60_000, @max_per_minute)
    uri = random_uri()

    {:ok, _view, _html} = visit_remote_interaction(conn(), uri)

    assert {:error, :not_found} = Media.get_by_path(uri),
           "the attempt was not counted against the guest's IP"
  end

  # the limit is the default 5 attempts a minute per IP: this IP has used them all, so a served page starts no thread (a thread costs a full fetch and save, so the limit is used up rather than reached by creating five). Applied where the page applies it, in `EmbedThreads.get_or_create/4`
  test "a guest who used a minute's attempts starts no thread, even for a served address", %{
    bot: bot
  } do
    page_exists!()
    Bonfire.UI.Common.RateLimit.set("embed_threads:unknown", 60_000, @max_per_minute)
    uri = random_uri()

    assert {:error, :rate_limited} =
             Bonfire.UI.Social.EmbedThreads.get_or_create(uri, %{}, bot, rate_limit_ip: "unknown")

    assert {:error, :not_found} = Media.get_by_path(uri)
  end
end
