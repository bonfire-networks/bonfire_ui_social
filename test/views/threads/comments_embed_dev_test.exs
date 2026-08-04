defmodule Bonfire.UI.Social.CommentsEmbedDevTest do
  @moduledoc """
  Dev/preview safety for the public comments embed (ghost-and-publishing plan, embed follow-up ii):
  an embed loaded from a localhost/loopback page must not create PUBLIC content — the created
  thread anchor is forced to a local-only boundary.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Files.Media

  setup do
    # the media branch fetches the page at `media_uri` to build the anchor
    Tesla.Mock.mock_global(fn _env ->
      {:ok, %Tesla.Env{status: 200, body: "<html><head><title>Dev preview</title></head></html>"}}
    end)

    bot = fake_user!()
    # configured embed import author, so the anchor can be created without a signed-in viewer
    # (`embed_anchor_creator/1` falls back to `Bonfire.Ghost.auto_import_as/0`)
    Process.put([:bonfire_ghost, :auto_import_as], bot.id)

    {:ok, bot: bot}
  end

  test "an embed loaded from a localhost page creates the anchor with a local-only boundary" do
    uri = "https://blog.example.com/dev-local-boundary/"
    parent = "http://localhost:4000/blog/dev-local-boundary/"

    {:ok, _view, _html} =
      live(
        conn(),
        "/comments/embed/interactive?media_uri=#{URI.encode_www_form(uri)}&embed_parent=#{URI.encode_www_form(parent)}"
      )

    assert {:ok, media} = Media.get_by_path(uri)
    object = Bonfire.Common.Needles.get!(media.id, skip_boundary_check: true)

    # a guest/remote must NOT be able to read a dev-preview-created anchor
    refute Bonfire.Boundaries.can?(nil, :read, object)
  end

  test "a localhost origin overrides an attacker-supplied boundary=public param" do
    uri = "https://blog.example.com/dev-local-wins/"
    parent = "http://127.0.0.1:4000/blog/dev-local-wins/"

    {:ok, _view, _html} =
      live(
        conn(),
        "/comments/embed/interactive?media_uri=#{URI.encode_www_form(uri)}&embed_parent=#{URI.encode_www_form(parent)}&boundary=public"
      )

    assert {:ok, media} = Media.get_by_path(uri)
    object = Bonfire.Common.Needles.get!(media.id, skip_boundary_check: true)
    refute Bonfire.Boundaries.can?(nil, :read, object)
  end

  test "a production-origin embed still creates a publicly-readable anchor (control)" do
    # guest-loaded creation requires the URI's origin to be allowlisted (loopback previews are
    # exempt, which is what the tests above exercise)
    System.put_env("IFRAME_ALLOWED_ORIGINS", "https://blog.example.com")
    on_exit(fn -> System.delete_env("IFRAME_ALLOWED_ORIGINS") end)

    uri = "https://blog.example.com/prod-public/"
    parent = "https://blog.example.com/prod-public/"

    {:ok, _view, _html} =
      live(
        conn(),
        "/comments/embed/interactive?media_uri=#{URI.encode_www_form(uri)}&embed_parent=#{URI.encode_www_form(parent)}"
      )

    assert {:ok, media} = Media.get_by_path(uri)
    object = Bonfire.Common.Needles.get!(media.id, skip_boundary_check: true)
    assert Bonfire.Boundaries.can?(nil, :read, object)
  end
end
