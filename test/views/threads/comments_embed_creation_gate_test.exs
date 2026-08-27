defmodule Bonfire.UI.Social.CommentsEmbedCreationGateTest do
  @moduledoc """
  The generic `media_uri` branch creates a thread anchor on demand, unauthenticated, attributed to the instance's configured import author — which previously let anyone (a crawler, a curl, a forged iframe URL) mint public posts under that identity for arbitrary URIs.

  Creation (unlike reading) is therefore gated (see `EmbedCommentsLive.maybe_create_anchor/3`): an anchor is created only for a URI whose host is allowlisted in `IFRAME_ALLOWED_ORIGINS` (host match, any scheme/port/path) AND when there is a creator (the configured import author, else the
  signed-in viewer). The allowlist applies to everyone, with no signed-in bypass. Reading an existing thread needs neither the allowlist nor a creator.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Files.Media
  alias Bonfire.Me.Accounts

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  setup do
    # the media branch fetches the page at `media_uri` to build the anchor
    Tesla.Mock.mock_global(fn _env ->
      {:ok, %Tesla.Env{status: 200, body: "<html><head><title>Article</title></head></html>"}}
    end)

    bot = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], bot.id)
    {:ok, bot: bot}
  end

  defp allowlist!(origin) do
    System.put_env("IFRAME_ALLOWED_ORIGINS", origin)
    on_exit(fn -> System.delete_env("IFRAME_ALLOWED_ORIGINS") end)
  end

  defp visit_embed(conn, uri),
    do: live(conn, "/comments/embed?media_uri=#{URI.encode_www_form(uri)}")

  test "a guest-loaded embed does NOT create an anchor for a non-allowlisted origin" do
    uri = "https://attacker.example/arbitrary-path/"

    {:ok, _view, html} = visit_embed(conn(), uri)

    assert html =~ "Be the first to comment"
    assert {:error, :not_found} = Media.get_by_path(uri)
  end

  test "a guest-loaded embed creates the anchor when the URI's origin is allowlisted",
       %{bot: bot} do
    allowlist!("https://blog.example.com")
    uri = "https://blog.example.com/allowlisted-article/"

    {:ok, _view, _html} = visit_embed(conn(), uri)

    assert {:ok, media} = Media.get_by_path(uri)
    assert media.creator_id == bot.id
  end

  test "an allowlisted host authorises the same host on other schemes and ports (host-level match)" do
    allowlist!("https://blog.example.com")
    uri = "http://blog.example.com:8080/plaintext-origin/"

    {:ok, _view, _html} = visit_embed(conn(), uri)

    assert {:ok, _media} = Media.get_by_path(uri)
  end

  test "no bypass: a signed-in viewer on a non-allowlisted origin does not create either" do
    account = fake_account!()
    user = fake_user!(account)
    {:ok, account} = Accounts.confirm_email(account)

    # the allowlist applies to everyone; being signed in does not bypass it
    uri = "https://anywhere.example/user-anchored/"

    {:ok, _view, _html} = visit_embed(conn(user: user, account: account), uri)

    assert {:error, :not_found} = Media.get_by_path(uri)
  end

  test "reading an existing thread needs neither the allowlist nor a configured creator" do
    allowlist!("https://blog.example.com")
    uri = "https://blog.example.com/pre-existing/"
    {:ok, _view, _html} = visit_embed(conn(), uri)
    assert {:ok, media} = Media.get_by_path(uri)

    # a later guest visit with no allowlist and no import author still displays the thread
    System.delete_env("IFRAME_ALLOWED_ORIGINS")
    Process.delete([:bonfire_ghost, :auto_import_as])

    {:ok, view, _html} = visit_embed(conn(), uri)
    assert assigns(view).object_id == media.id
  end
end
