defmodule Bonfire.UI.Social.LinkPreviewLabelXSSTest do
  @moduledoc """
  A media label (a link's unfurled title, or the `name` of a remote attachment) is text kept as received, so it must be shown escaped, never as HTML.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  use Surface.LiveViewTest
  @moduletag :ui

  alias Bonfire.UI.Social.Activity.MediaLive
  alias Bonfire.UI.Social.Activity.MediaCarouselModalLive

  @payload "<img src=x onerror=alert(1)>"

  defp media(metadata) do
    struct(
      Bonfire.Files.Media,
      id: "01HZZ0LabelXSSMediaTEST",
      path: "https://remote.local/pic.png",
      media_type: "image/png",
      metadata: metadata
    )
  end

  # the media's own image has a legitimate onerror fallback, so look for the payload's tag
  defp live_onerror?(html), do: html =~ ~r/<img src=x onerror=alert/i

  defp label_variants(label) do
    [
      {"unfurled title", %{"title" => label}},
      {"remote attachment name", %{"json_ld" => %{"attachment" => %{"name" => label}}}}
    ]
  end

  # the label shown up-front, when the media is the object itself
  defp render_media_live(media) do
    assigns = %{media: media}

    render_surface do
      ~F"""
      <MediaLive media={@media} media_text_up_font? />
      """
    end
  end

  # the caption of the full-screen viewer
  defp render_carousel_modal(media) do
    assigns = %{media_list: [media]}

    render_surface do
      ~F"""
      <MediaCarouselModalLive media_list={@media_list} parent_id="label-xss-parent" />
      """
    end
  end

  defp render_view(:media_live, media), do: render_media_live(media)
  defp render_view(:carousel_modal, media), do: render_carousel_modal(media)

  for view <- [:media_live, :carousel_modal] do
    describe "#{view}" do
      test "a hostile label renders without a live onerror" do
        for {source, metadata} <- label_variants(@payload) do
          html = render_view(unquote(view), media(metadata))
          refute live_onerror?(html), "#{source} was rendered as HTML"
        end
      end

      test "a plain label is shown (control)" do
        for {source, metadata} <- label_variants("A plain label") do
          html = render_view(unquote(view), media(metadata))
          assert html =~ "A plain label", "#{source} not shown"
        end
      end
    end
  end
end
