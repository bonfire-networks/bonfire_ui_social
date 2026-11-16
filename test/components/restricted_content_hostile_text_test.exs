defmodule Bonfire.UI.Social.RestrictedContentHostileTextTest do
  @moduledoc """
  What the closed card shows of an object (its name and summary) may come from fields kept as received (when the object is not a post), so it must never come out as raw HTML.
  """
  use ExUnit.Case, async: true
  use Surface.LiveViewTest

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  alias Bonfire.UI.Social.RestrictedContentLive

  @payload "<img src=x onerror=alert(1)>"

  defp live_onerror?(html), do: html =~ ~r/<img[^>]*onerror/i

  defp render_card(object) do
    assigns = %{object: object}

    render_surface do
      ~F"""
      <RestrictedContentLive object={@object} viewing_main_object={false} />
      """
    end
  end

  test "a hostile name and summary render without a live onerror" do
    refute live_onerror?(render_card(%{name: @payload, summary: "plain"}))
    refute live_onerror?(render_card(%{name: "plain", summary: @payload}))
  end

  test "a plain name and summary are shown (control)" do
    html = render_card(%{name: "A tidy name", summary: "A tidy summary"})
    assert html =~ "A tidy name"
    assert html =~ "A tidy summary"
  end
end
