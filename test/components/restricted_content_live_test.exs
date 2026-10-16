defmodule Bonfire.UI.Social.RestrictedContentLiveTest do
  @moduledoc """
  What someone who may find something but not read it is shown, in its two sizes: the card in a list (`viewing_main_object: false`), and the full screen when it is opened.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Common.Config
  alias Bonfire.UI.Social.RestrictedContentLive

  @object %{
    id: "01HB0ABCDEFGHJKMNPQRSTVWXY",
    post_content: %{
      name: "Our plans",
      summary: "What we decided",
      html_body: "<p>the part only members may read</p>"
    }
  }

  @group %{profile: %{name: "Knitters"}}

  defp render_restricted(assigns) do
    render_component(
      &RestrictedContentLive.render/1,
      Map.merge(%{__context__: %{}, object: @object}, Map.new(assigns))
    )
    |> Floki.parse_document!()
  end

  defp text(html, selector), do: html |> Floki.find(selector) |> Floki.text() |> String.trim()

  describe "the card" do
    test "shows its name and summary, and never its body" do
      html = render_restricted(viewing_main_object: false)

      assert text(html, ~s([data-role="name"])) == "Our plans"
      assert text(html, ~s([data-role="summary"])) == "What we decided"
      refute Floki.raw_html(html) =~ "the part only members may read"
    end

    test "says which group keeps it to its members" do
      html = render_restricted(viewing_main_object: false, published_in: @group)

      assert text(html, ~s([data-role="restricted_content_notice"])) ==
               "Only members of Knitters can read this"
    end

    test "says so plainly outside a group" do
      html = render_restricted(viewing_main_object: false)

      assert text(html, ~s([data-role="restricted_content_notice"])) == "You can't read this"
    end

    test "is compact: no message, buttons or sign-in" do
      html = render_restricted(viewing_main_object: false)

      assert Floki.find(html, ~s([data-role="restricted_object"])) != []
      assert Floki.find(html, ~s([data-role="restricted_login"])) == []
      refute Floki.raw_html(html) =~ "It was shared with a limited audience."
    end
  end

  describe "the full screen" do
    test "explains, with the same title, and offers a guest to sign in" do
      html = render_restricted(viewing_main_object: true, published_in: @group)

      assert Floki.find(html, ~s([data-role="restricted_content"])) != []

      assert text(html, ~s([data-role="restricted_content_notice"])) ==
               "Only members of Knitters can read this"

      assert Floki.raw_html(html) =~ "It was shared with a limited audience."
      assert Floki.find(html, ~s([data-role="restricted_login"])) != []
    end
  end

  # the instance's own words, set up in Settings > Instance > Restricted content screen, for both sizes alike, and only once it has enabled the screen
  describe "the instance's title" do
    setup do
      previous = Config.get([RestrictedContentLive], nil, :bonfire_ui_social)

      on_exit(fn ->
        Config.put([RestrictedContentLive], previous, :bonfire_ui_social)
      end)

      Config.put([RestrictedContentLive, :title], "Upgrade to read this", :bonfire_ui_social)
      :ok
    end

    test "is not used while the screen is off" do
      html = render_restricted(viewing_main_object: false, published_in: @group)

      assert text(html, ~s([data-role="restricted_content_notice"])) ==
               "Only members of Knitters can read this"
    end

    test "is used by the card and the full screen once it is on" do
      Config.put([RestrictedContentLive, :modularity], true, :bonfire_ui_social)

      for viewing_main_object <- [false, true] do
        html = render_restricted(viewing_main_object: viewing_main_object, published_in: @group)

        assert text(html, ~s([data-role="restricted_content_notice"])) == "Upgrade to read this"
      end
    end
  end
end
