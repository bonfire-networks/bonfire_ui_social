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

  describe "opened, signed out" do
    setup do
      previous = Config.get([RestrictedContentLive], nil, :bonfire_ui_social)
      on_exit(fn -> Config.put([RestrictedContentLive], previous, :bonfire_ui_social) end)
      Config.put([RestrictedContentLive, :modularity], true, :bonfire_ui_social)

      # someone from another instance can only use their account there if this one federates
      Process.put(:federating, true)
      :ok
    end

    # what other servers may read and visitors here may not: the one case where an account elsewhere gets them in
    test "offers to use an account on another instance, which leads to the post" do
      post =
        Bonfire.Posts.Fake.fake_post!(
          fake_user!(),
          "mentions",
          %{
            post_content: %{html_body: "<p>for other servers to read</p>"}
          },
          to_circles: %{Bonfire.Boundaries.Circles.get_id!(:activity_pub) => "read"}
        )

      # the positive first: other servers may read it, visitors here may not
      assert Bonfire.Boundaries.can?(:activity_pub, :read, post)
      refute Bonfire.Boundaries.can?(:guest, :read, post)

      # a guest has no LiveView socket, so the page they get is the static render, which `visit` does not give (it connects a LiveView), and there is no async load to wait for
      # conn()
      # |> visit("/post/#{id(post)}")
      # |> wait_async()
      # |> assert_has("[data-role=restricted_content]")
      # |> unwrap(fn view ->
      #   html = Phoenix.LiveViewTest.render(view)
      #
      #   links =
      #     html
      #     |> Floki.parse_document!()
      #     |> Floki.attribute("[data-role=remote_interaction]", "href")
      #
      #   assert [link] = links, "no link to use an account on another instance: #{inspect(links)}"
      #
      #   # what the visitor's own instance is to fetch, so the address of the post itself
      #   assert URI.decode_www_form(link) =~
      #            Bonfire.Common.URIs.canonical_url(post, preload_if_needed: true)
      #
      #   html
      # end)

      link =
        conn()
        |> get_conn_render("/post/#{id(post)}")
        |> assert_has("[data-role=restricted_content]")
        |> static_href("[data-role=remote_interaction]")

      # what the visitor's own instance is to fetch, so the address of the post itself
      assert URI.decode_www_form(link) =~
               Bonfire.Common.URIs.canonical_url(post, preload_if_needed: true)
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
