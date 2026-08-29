defmodule Bonfire.UI.Social.Activity.MediaLinkLiveTest do
  use ExUnit.Case, async: true

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Social.Activity.MediaLinkLive
  alias Bonfire.UI.Social.Activity.MediaLive

  test "an Open Graph image duplicated as the favicon is not treated as a cover" do
    site_icon = "https://example.com/site-icon.svg"

    media =
      media(%{
        "favicon" => site_icon,
        "other" => %{"og:image" => site_icon}
      })

    assert MediaLive.preview_img(media) == nil
  end

  test "an Open Graph image different from the favicon remains a cover" do
    cover = "https://example.com/article-cover.jpg"

    media =
      media(%{
        "favicon" => "https://example.com/favicon.svg",
        "other" => %{"og:image" => cover}
      })

    assert MediaLive.preview_img(media) == cover
  end

  test "an SVG remains a cover when it is not the favicon" do
    cover = "https://example.com/article-illustration.svg"

    media =
      media(%{
        "favicon" => "https://example.com/favicon.svg",
        "other" => %{"og:image" => cover}
      })

    assert MediaLive.preview_img(media) == cover
  end

  test "favicon fallback stays compact and preserves the whole icon" do
    favicon = "https://example.com/favicon.png"

    media =
      media(%{
        "favicon" => favicon,
        "facebook" => %{"site_name" => "EXAMPLE.COM"},
        "other" => %{
          "title" => "Example article",
          "description" => "A useful description",
          "og:image" => favicon
        }
      })

    preview_img = MediaLive.preview_img(media)

    html =
      render_component(&MediaLinkLive.render/1, %{
        media: media,
        media_url: media.path,
        preview_img: preview_img,
        parent_id: "favicon-preview-test",
        __context__: %{}
      })

    assert preview_img == nil
    assert html =~ ~s(data-id="media_favicon")
    assert html =~ "w-10 h-10 shrink-0"
    assert html =~ "w-full h-full rounded-md object-contain"
    assert html =~ "text-pretty max-w-prose"
    refute html =~ "max-w-[120px] w-full h-full"
    refute html =~ "object-cover rounded-l-lg"

    {:ok, document} = Floki.parse_fragment(html)
    [identity] = Floki.find(document, ~s([data-id="media_identity"]))

    assert Floki.find(identity, ~s([data-id="media_favicon"])) != []
    assert Floki.find(identity, ~s([data-id="media_author"])) != []
  end

  # The homepage link card for the instance's own site. Every field here is copied from the media that crashed the feed in production: `json_ld` is an ARRAY rather than an object, `path` has noscheme, and there is no cover image anywhere in the metadata, so every candidate in the preview chain has to fall through to the last one.
  describe "a website link preview whose json_ld is an array" do
    defp array_json_ld_media do
      %Bonfire.Files.Media{
        id: "01GSFXHPVXPG359CYYT7F68HPC",
        path: "campground.bonfire.cafe",
        file: nil,
        size: 0,
        media_type: "website",
        metadata: %{
          "canonical_url" => nil,
          "facebook" => %{
            "og:description" =>
              "This is a demo instance of the Bonfire Classic flavour for testing purposes",
            "og:locale" => "en",
            "og:site_name" => "Bonfire Campground",
            "og:type" => "website"
          },
          "favicon" => nil,
          "json_ld" => [
            %{
              "@context" => "https://schema.org",
              "@type" => "BreadcrumbList",
              "itemListElement" => []
            }
          ],
          "oembed" => nil,
          "other" => %{
            "description" =>
              "This is a demo instance of the Bonfire Classic flavour for testing purposes",
            "title" => "Bonfire Campground · Bonfire Campground",
            "viewport" => "width=device-width, initial-scale=1.0, viewport-fit=cover"
          },
          "status_code" => 200,
          "twitter" => %{"twitter:site" => "@SwitchToBonfire"}
        }
      }
    end

    test "the media classifies without raising" do
      media = array_json_ld_media()

      assert MediaLive.the_medias([media]) == [media]
      assert MediaLive.has_video_page_metadata?(media) == false
      assert MediaLive.peertube_embed_url(media) == nil
    end

    test "it has no cover image, so the card falls back to the compact layout" do
      assert MediaLive.preview_img(array_json_ld_media()) == nil
    end

    test "it renders in a feed" do
      html =
        render_component(&MediaLive.render/1, %{
          media: [array_json_ld_media()],
          showing_within: :feed,
          parent_id: "array-json-ld-test",
          __context__: %{}
        })

      assert html =~ "campground.bonfire.cafe"
    end
  end

  defp media(metadata) do
    %Bonfire.Files.Media{
      id: "01K36J7G8R4PN6X4F9WQ2ZTCE",
      path: "https://example.com/article",
      media_type: "link",
      metadata: metadata
    }
  end
end
