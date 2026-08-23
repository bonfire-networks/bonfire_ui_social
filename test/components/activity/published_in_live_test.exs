defmodule Bonfire.UI.Social.Activity.PublishedInLiveTest do
  use ExUnit.Case, async: true

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Social.Activity.PublishedInLive

  @context %{
    id: "01K36J7G8R4PN6X4FJ9WQ2ZTCE",
    profile: %{name: "fermo! mutual aid and neighbourhood organising"},
    character: %{username: "fermo"}
  }

  # passes `to` as production does, so the component never resolves a path and needs no DB sandbox
  defp render_published_in(assigns),
    do:
      render_component(
        &PublishedInLive.render/1,
        Map.merge(%{context: @context, to: "/+fermo", __context__: %{}}, Map.new(assigns))
      )

  test "compact provenance labels the context after a separator it owns itself" do
    # the separator has to sit inside the chip, so presets hiding the whole chip don't strand it
    assert [_, after_separator] = String.split(render_published_in(compact: true), "·", parts: 2)
    assert after_separator =~ "Posted in"
    assert after_separator =~ "fermo! mutual aid and neighbourhood organising"
  end

  test "standalone provenance renders its default top-line row" do
    html = render_published_in([])

    assert html =~ "Posted in"
    assert html =~ "border-b-hair"
    assert html =~ ~s(href="/+fermo")
  end

  test "a caller's class replaces the standalone default" do
    html = render_published_in(class: "custom-provenance")

    assert html =~ "custom-provenance"
    refute html =~ "border-b-hair"
  end
end
