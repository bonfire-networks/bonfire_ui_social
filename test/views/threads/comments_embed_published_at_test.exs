defmodule Bonfire.UI.Social.CommentsEmbedPublishedAtTest do
  @moduledoc """
  Backdating embed imports to the article's publication date (ghost-and-publishing plan, embed
  follow-up i), so importing an old/backfilled article doesn't shoot it to the top of feeds as if
  freshly posted. Covers the `data-published-at` → `published_at` param on the generic (non-Ghost)
  `media_uri` branch; the Ghost branch already backdates from the article payload's own
  `published_at`. Backdating only ever moves a post earlier — a future date is ignored (guard in
  `DatesTimes.generate_ulid_if_past/1`).
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Files.Media
  alias Bonfire.Common.DatesTimes

  setup do
    Tesla.Mock.mock_global(fn _env ->
      {:ok, %Tesla.Env{status: 200, body: "<html><head><title>Old article</title></head></html>"}}
    end)

    bot = fake_user!()
    Process.put([:bonfire_ghost, :auto_import_as], bot.id)

    # guest-loaded creation requires the URI's origin to be allowlisted
    System.put_env("IFRAME_ALLOWED_ORIGINS", "https://blog.example.com")
    on_exit(fn -> System.delete_env("IFRAME_ALLOWED_ORIGINS") end)

    {:ok, bot: bot}
  end

  defp visit_embed(uri, extra) do
    {:ok, _view, _html} =
      live(conn(), "/comments/embed/interactive?media_uri=#{URI.encode_www_form(uri)}#{extra}")
  end

  test "published_at backdates the created anchor to the given date" do
    uri = "https://blog.example.com/an-old-article/"
    visit_embed(uri, "&published_at=2020-01-01T00:00:00.000Z")

    assert {:ok, media} = Media.get_by_path(uri)
    assert %DateTime{year: 2020, month: 1} = DatesTimes.date_from_pointer(media.id)
  end

  test "a date-only published_at is accepted" do
    uri = "https://blog.example.com/date-only/"
    visit_embed(uri, "&published_at=2019-07-25")

    assert {:ok, media} = Media.get_by_path(uri)
    assert %DateTime{year: 2019, month: 7, day: 25} = DatesTimes.date_from_pointer(media.id)
  end

  test "no published_at → the anchor is created at ~now (not backdated)" do
    uri = "https://blog.example.com/fresh/"
    visit_embed(uri, "")

    assert {:ok, media} = Media.get_by_path(uri)
    assert DatesTimes.date_from_pointer(media.id).year == DateTime.utc_now().year
  end

  test "a future published_at is ignored (anchor stays at ~now)" do
    uri = "https://blog.example.com/future/"
    visit_embed(uri, "&published_at=2999-01-01T00:00:00.000Z")

    assert {:ok, media} = Media.get_by_path(uri)
    assert DatesTimes.date_from_pointer(media.id).year == DateTime.utc_now().year
  end
end
