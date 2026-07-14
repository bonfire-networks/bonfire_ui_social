defmodule Bonfire.UI.Social.ArticleMediaRegressionTest do
  @moduledoc """
  Regression tests for media attached to Articles not being displayed.

  Reported behaviour (2026-07-14):

    1. Media uploaded on an article is not shown at all: for `object_type == :article`,
       `ActivityLive.do_primary_image_and_component_maybe_attachments/3` splits out the
       cover (`primary_image` flagged media) and then drops ALL remaining attachments
       (returns `[]` instead of a MediaLive component).

    2. Clicking "Set as cover" in the composer and publishing as an Article should
       result in an `Bonfire.Articles.Article` whose media has
       `metadata["primary_image"] == "true"`, and the article page should render the
       cover figure (`[data-id=article_cover]`). In the reported case the created
       object ended up as a plain Post with no `primary_image` flag saved.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  use Bonfire.Common.Utils
  import Bonfire.Files.Simulation
  import Ecto.Query

  alias Bonfire.Files
  alias Bonfire.Files.ImageUploader
  alias Bonfire.Common.Types
  alias Bonfire.Articles.Article
  alias Bonfire.UI.Social.ActivityLive

  @moduletag :ui

  setup do
    account = fake_account!()
    me = fake_user!(account)
    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me}
  end

  defp upload_image!(me, attrs \\ %{}) do
    {:ok, media} = Files.upload(ImageUploader, me, image_file(), attrs)
    media
  end

  defp publish_article!(me, media_list) do
    Bonfire.Articles.Fake.fake_article!(me, "public", %{
      post_content: %{
        name: "Article with media #{System.unique_integer()}",
        html_body: "Some long-form body. #{System.unique_integer()}"
      },
      uploaded_media: media_list
    })
  end

  describe "attachments on articles (unit)" do
    test "an article's non-cover media is not silently dropped", %{me: me} do
      media = upload_image!(me)

      # the media has no primary_image flag (user uploaded it without clicking Set as cover)
      refute e(media, :metadata, "primary_image", nil)

      {primary_image, components} =
        ActivityLive.do_primary_image_and_component_maybe_attachments(
          id(media),
          [media],
          :article
        )

      # REGRESSION: currently returns {nil, []} — the uploaded media vanishes entirely.
      # Either it should be promoted to the cover, or rendered as an attachment.
      assert primary_image != nil or components != [],
             "uploaded media was dropped from the article: no cover and no attachments component"
    end

    test "an article's cover-flagged media is used as primary image (control)", %{me: me} do
      media = upload_image!(me, %{metadata: %{"primary_image" => "true"}})

      {primary_image, _components} =
        ActivityLive.do_primary_image_and_component_maybe_attachments(
          id(media),
          [media],
          :article
        )

      assert id(primary_image) == id(media)
    end
  end

  describe "article page rendering" do
    test "cover-flagged media renders as the article cover (control)", %{conn: conn, me: me} do
      media = upload_image!(me, %{metadata: %{"primary_image" => "true"}})
      article = publish_article!(me, [media])

      conn
      |> visit("/post/#{id(article)}")
      |> assert_has_or_open_browser("[data-id=article_cover]")
    end

    test "media uploaded without the cover flag is still shown on the article page", %{
      conn: conn,
      me: me
    } do
      media = upload_image!(me)
      article = publish_article!(me, [media])

      conn
      |> visit("/post/#{id(article)}")
      |> PhoenixTest.unwrap(fn view ->
        html = Phoenix.LiveViewTest.render(view)

        # REGRESSION: the image is attached to the article in the DB but rendered
        # nowhere on the page — neither as cover nor as an attachment.
        assert html =~ Path.basename(media.path),
               "uploaded media is attached to the article but not rendered anywhere on its page"

        html
      end)
    end
  end

  describe "cover toggle state propagation" do
    # Pinpoints WHERE the 'Set as cover' click gets lost: after clicking, the hidden
    # upload_metadata[<ref>][primary_image] input rendered by UploadPreviewsLive must
    # have value="true", otherwise submitting the form can never persist the flag.
    test "on /write (inline composer) the hidden primary_image input flips to true", %{
      conn: conn
    } do
      file = Path.expand("../fixtures/icon.png", __DIR__)

      conn
      |> visit("/write")
      |> upload("Upload an attachment", file)
      |> click_button(
        "[phx-click='Bonfire.UI.Common.SmartInput:toggle-cover-image']",
        "Set as cover"
      )
      |> assert_has_or_open_browser("input[name*='[primary_image]'][value='true']")
    end
  end

  describe "composer flow: upload → Set as cover → publish as article" do
    test "creates an Article whose media is flagged as primary image", %{conn: conn, me: me} do
      file = Path.expand("../fixtures/icon.png", __DIR__)
      content = "article body #{System.unique_integer()}"
      title = "article title #{System.unique_integer()}"

      conn
      |> visit("/write")
      |> upload("Upload an attachment", file)
      # the "Set as cover" toggle rendered by UploadPreviewsLive for image uploads
      |> click_button("[phx-click='Bonfire.UI.Common.SmartInput:toggle-cover-image']", "Set as cover")
      # submit the composer form as an article, letting the rendered hidden inputs
      # (upload_metadata[...][primary_image], etc) flow through like a real submit
      |> PhoenixTest.unwrap(fn view ->
        view
        |> Phoenix.LiveViewTest.element("#smart_input_form")
        |> Phoenix.LiveViewTest.render_submit(%{
          "create_object_type" => "article",
          "post" => %{
            "create_object_type" => "article",
            "post_content" => %{"name" => title, "html_body" => content}
          }
        })
      end)
      |> wait_async()

      # the uploaded media must have been saved with the cover flag
      [media] =
        repo().all(from(m in Bonfire.Files.Media, where: m.creator_id == ^id(me)))

      assert e(media, :metadata, "primary_image", nil) in [true, "true"],
             "'Set as cover' was clicked but primary_image flag was not saved in media metadata: #{inspect(media.metadata)}"

      # and the created object must be an Article, not a plain Post
      [%{id: object_id}] =
        repo().all(from(f in Bonfire.Files, where: f.media_id == ^id(media)))

      object = Bonfire.Common.Needles.get!(object_id, skip_boundary_check: true)

      assert Types.object_type(object) == Article,
             "expected the published object to be an Article, got: #{inspect(Types.object_type(object))}"
    end
  end
end
