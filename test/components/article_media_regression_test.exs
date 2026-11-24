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
      |> click_button(
        "[phx-click='Bonfire.UI.Common.SmartInput:toggle-cover-image']",
        "Set as cover"
      )
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

    test "each upload preview has an Insert in text button placing it in the editor", %{
      conn: conn
    } do
      file = Path.expand("../fixtures/icon.png", __DIR__)

      conn
      |> visit("/write")
      |> upload("Upload an attachment", file)
      |> PhoenixTest.unwrap(fn view ->
        html = Phoenix.LiveViewTest.render(view)
        [_, ref] = Regex.run(~r/upload_metadata\[([^\]]+)\]/, html)

        # the button dispatches `bonfire:insert_at_cursor` on itself with the upload's placeholder, as markdown: `milkdown.hooks.js` sends it to the plain field last written in, else to the editor
        [button] =
          html
          |> LazyHTML.from_document()
          |> LazyHTML.query("[data-role=insert_in_text]")
          |> LazyHTML.attribute("phx-click")

        assert button =~ "bonfire:insert_at_cursor"
        refute button =~ ~s("to":)
        assert button =~ "upload:#{ref}"
        assert button =~ ~s("markdown":true)

        # the newest upload shows its alt text without Edit; Done, in the Edit button's place meanwhile, puts it back in the strip of thumbnails
        doc = LazyHTML.from_document(html)
        [done] = doc |> LazyHTML.query("[data-role=alt_done]") |> LazyHTML.attribute("phx-click")
        assert done =~ "alt_done"
        refute done =~ "expanded"

        # Edit and Collapse also close it, so it doesn't reopen on its own row after a collapse
        [toggle] =
          doc |> LazyHTML.query("[data-role=upload_toggle]") |> LazyHTML.attribute("phx-click")

        assert toggle =~ "expanded"
        assert toggle =~ "alt_done"

        # one Done for the list, not one per upload
        assert doc
               |> LazyHTML.query("[data-role=upload_entry] [data-role=alt_done]")
               |> Enum.count() == 0

        html
      end)
    end

    # the composer writes `upload:<ref>` for a file it hasn't uploaded yet: publishing stores the file and puts its URL there
    test "an upload placed in the text gets its stored URL in the published body", %{
      conn: conn,
      me: me
    } do
      file = Path.expand("../fixtures/icon.png", __DIR__)

      conn
      |> visit("/write")
      |> upload("Upload an attachment", file)
      |> PhoenixTest.unwrap(fn view ->
        # the upload entry's ref, as the composer's metadata inputs name it
        [_, ref] = Regex.run(~r/upload_metadata\[([^\]]+)\]/, Phoenix.LiveViewTest.render(view))

        view
        |> Phoenix.LiveViewTest.element("#smart_input_form")
        |> Phoenix.LiveViewTest.render_submit(%{
          "post" => %{
            "post_content" => %{"html_body" => "Intro\n\n![](upload:#{ref})\n\nmore"}
          }
        })
      end)
      |> wait_async()

      [media] = repo().all(from(m in Bonfire.Files.Media, where: m.creator_id == ^id(me)))
      [%{id: post_id}] = repo().all(from(f in Bonfire.Files, where: f.media_id == ^id(media)))

      body =
        Bonfire.Common.Needles.get!(post_id, skip_boundary_check: true)
        |> repo().maybe_preload(:post_content)
        |> e(:post_content, :html_body, nil)

      refute body =~ "upload:"
      assert Bonfire.Files.InlineMedia.inline_ids(body, [media]) == [id(media)]
    end
  end

  # media placed in the body (see `Bonfire.Files.InlineMedia`) renders there, where it sits, and not again in the attachment list
  describe "inline media in the body" do
    defp publish_article_with_body!(me, body, media_list) do
      Bonfire.Articles.Fake.fake_article!(me, "public", %{
        post_content: %{name: "Article #{System.unique_integer()}", html_body: body},
        uploaded_media: media_list
      })
    end

    defp loaded_files(object) do
      object |> repo().maybe_preload([files: [:media]], force: true) |> e(:files, [])
    end

    # the inner HTML of the rendered body, and the whole page
    defp body_and_page(conn, path) do
      conn
      |> visit(path)
      |> PhoenixTest.unwrap(fn view ->
        html = Phoenix.LiveViewTest.render(view)

        body =
          html
          |> LazyHTML.from_document()
          |> LazyHTML.query("[data-id=object_body]")
          |> LazyHTML.to_html()

        send(self(), {:rendered, body, html})
        html
      end)

      assert_received {:rendered, body, html}
      {body, html}
    end

    defp count(html, text), do: length(String.split(html, text)) - 1

    test "the attachment list leaves out inline media (unit)", %{me: me} do
      inline = upload_image!(me)
      other = upload_image!(me)
      body = "Intro\n\n![](#{Bonfire.Files.inline_url(inline)})\n\nmore"
      article = publish_article_with_body!(me, body, [inline, other])

      assert {nil, [{Bonfire.UI.Social.Activity.MediaLive, %{media: listed}}]} =
               ActivityLive.do_primary_image_and_component_maybe_attachments(
                 id(article),
                 loaded_files(article),
                 :article,
                 body
               )

      assert Enum.map(listed, &e(&1, :media_id, nil)) == [id(other)]
    end

    test "with all its media inline, there's no attachment list (unit)", %{me: me} do
      inline = upload_image!(me)
      body = "![](#{Bonfire.Files.inline_url(inline)})"
      article = publish_article_with_body!(me, body, [inline])

      assert {nil, []} =
               ActivityLive.do_primary_image_and_component_maybe_attachments(
                 id(article),
                 loaded_files(article),
                 :article,
                 body
               )
    end

    test "an inline image flagged as the cover stays the cover (unit)", %{me: me} do
      cover = upload_image!(me, %{metadata: %{"primary_image" => "true"}})
      body = "![](#{Bonfire.Files.inline_url(cover)})"
      article = publish_article_with_body!(me, body, [cover])

      assert {primary_image, _} =
               ActivityLive.do_primary_image_and_component_maybe_attachments(
                 id(article),
                 loaded_files(article),
                 :article,
                 body
               )

      assert e(primary_image, :media_id, nil) == id(cover)
    end

    test "the article page shows inline media in the body, once, and the rest in the list", %{
      conn: conn,
      me: me
    } do
      inline = upload_image!(me)
      other = upload_image!(me)
      body = "Intro\n\n![](#{Bonfire.Files.inline_url(inline)})\n\nmore"
      article = publish_article_with_body!(me, body, [inline, other])

      {body_html, page} = body_and_page(conn, "/post/#{id(article)}")

      inline_file = Path.basename(inline.path)
      other_file = Path.basename(other.path)

      assert body_html =~ ~r/Intro.*data-id="article_media".*#{inline_file}.*more/s
      assert count(page, inline_file) == count(body_html, inline_file)
      refute body_html =~ other_file
      assert page =~ other_file

      # in the body, an image shows at its own size at most (Q7): its wrapper keeps it from being stretched to the column, which the attachment list does
      assert body_html =~ ~r/data-role="inline_media"[^>]*>.*data-id="article_media"/s
    end

    test "control: without inline media, the article page lists its media as before", %{
      conn: conn,
      me: me
    } do
      other = upload_image!(me)
      article = publish_article_with_body!(me, "no media in the text", [other])

      {body_html, page} = body_and_page(conn, "/post/#{id(article)}")

      refute body_html =~ Path.basename(other.path)
      assert page =~ Path.basename(other.path)
    end

    # as an author does it: only the player's URL, alone on its line; the link preview (`URLPreviews`) finds its oEmbed and attaches it, and the body shows the player there
    test "a player's URL alone on its line shows as its player, in place, once", %{
      conn: conn,
      me: me
    } do
      youtube = "https://www.youtube.com/watch?v=inlinePlay1"
      Process.put(:req_adapter, fn request -> {request, Req.Response.new(status: 404)} end)

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://www.youtube.com/oembed" <> _} ->
          %Tesla.Env{
            status: 200,
            headers: [{"content-type", "application/json"}],
            body:
              Jason.encode!(%{
                "type" => "video",
                "title" => "An inline player",
                "provider_name" => "YouTube",
                "html" => ~s(<iframe src="https://www.youtube.com/embed/inlinePlay1"></iframe>)
              })
          }

        %{method: :get, url: "https://www.youtube.com/watch" <> _} = env ->
          %Tesla.Env{
            env
            | status: 200,
              headers: [{"content-type", "text/html"}],
              body:
                ~s(<html><head><title>An inline player</title><meta property="og:title" content="An inline player"><link rel="alternate" type="application/json+oembed" href="https://www.youtube.com/oembed?url=#{URI.encode_www_form(youtube)}&format=json"></head><body></body></html>)
          }

        _ ->
          %Tesla.Env{status: 404, body: ""}
      end)

      {:ok, post} =
        Bonfire.Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "Watch this:\n\n#{youtube}\n\nafter"}},
          boundary: "public"
        )

      assert [_ | _] = loaded_files(post), "control: the link preview attached the player's link"

      {body_html, page} = body_and_page(conn, "/post/#{id(post)}")

      # its iframe (YouTube's, as its privacy-enhanced `youtube-nocookie.com`) between the text before and after it
      assert body_html =~ ~r/Watch this:.*<iframe[^>]*\/embed\/inlinePlay1.*after/s
      assert count(page, "/embed/inlinePlay1") == count(body_html, "/embed/inlinePlay1")
    end

    # a remote post's body is HTML: a link alone in its paragraph places its player there, as a URL alone on its line does in a local post. Received as from Mastodon, whose link text is split in spans, with the link preview (`URLPreviews`) finding the player's oEmbed
    for {name, link} <- [
          {"a link",
           ~s(<a href="https://www.youtube.com/watch?v=remotePlay1">https://www.youtube.com/watch?v=remotePlay1</a>)},
          {"a Mastodon link",
           ~s(<a href="https://www.youtube.com/watch?v=remotePlay1" target="_blank" rel="nofollow noopener" translate="no"><span class="invisible">https://www.</span><span class="ellipsis">youtube.com/watch?v=remotePl</span><span class="invisible">ay1</span></a>)}
        ] do
      test "in a remote post, #{name} alone in its paragraph shows as its player, in place, once",
           %{conn: conn} do
        username = "inline_player_#{System.unique_integer([:positive])}"
        remote_actor = "https://mocked.local/users/#{username}"
        youtube = "https://www.youtube.com/watch?v=remotePlay1"
        Process.put(:req_adapter, fn request -> {request, Req.Response.new(status: 404)} end)
        Process.put(:federating, true)

        Tesla.Mock.mock_global(fn
          %{method: :get, url: ^remote_actor} ->
            Tesla.Mock.json(
              Bonfire.Federate.ActivityPub.Simulate.actor_json(remote_actor, username)
            )

          %{method: :get, url: "https://www.youtube.com/oembed" <> _} ->
            %Tesla.Env{
              status: 200,
              headers: [{"content-type", "application/json"}],
              body:
                Jason.encode!(%{
                  "type" => "video",
                  "title" => "A remote player",
                  "provider_name" => "YouTube",
                  "html" => ~s(<iframe src="https://www.youtube.com/embed/remotePlay1"></iframe>)
                })
            }

          %{method: :get, url: "https://www.youtube.com/watch" <> _} = env ->
            %Tesla.Env{
              env
              | status: 200,
                headers: [{"content-type", "text/html"}],
                body:
                  ~s(<html><head><title>A remote player</title><link rel="alternate" type="application/json+oembed" href="https://www.youtube.com/oembed?url=#{URI.encode_www_form(youtube)}&format=json"></head><body></body></html>)
            }

          _ ->
            %Tesla.Env{status: 404, body: ""}
        end)

        object_id =
          "https://mocked.local/objects/inline-player-#{System.unique_integer([:positive])}"

        public = "https://www.w3.org/ns/activitystreams#Public"

        {:ok, data} =
          ActivityPub.Federator.Transformer.handle_incoming(%{
            "@context" => "https://www.w3.org/ns/activitystreams",
            "type" => "Create",
            "id" => object_id <> "/activity",
            "actor" => remote_actor,
            "to" => [public],
            "object" => %{
              "id" => object_id,
              "type" => "Note",
              "attributedTo" => remote_actor,
              "to" => [public],
              "cc" => [],
              "content" => "<p>Intro</p><p>#{unquote(link)}</p><p>after</p>"
            }
          })

        assert {:ok, post} = Bonfire.Federate.ActivityPub.Incoming.receive_activity(data)

        assert [_ | _] = loaded_files(post),
               "control: the link preview attached the player's link"

        {body_html, page} = body_and_page(conn, "/post/#{id(post)}")

        assert body_html =~ ~r/Intro.*<iframe[^>]*\/embed\/remotePlay1.*after/s
        assert count(page, "/embed/remotePlay1") == count(body_html, "/embed/remotePlay1")
      end
    end

    # an uploaded video or audio placed in the text (`![](URL)`, as the composer places any file) shows as its player there, not as a broken image
    test "an uploaded video placed in the text shows as its player, in place, once", %{
      conn: conn,
      me: me
    } do
      {:ok, video} = Files.upload(Bonfire.Files.VideoUploader, me, video_file())
      body = "Intro\n\n![](#{Bonfire.Files.inline_url(video)})\n\nmore"
      article = publish_article_with_body!(me, body, [video])

      {body_html, page} = body_and_page(conn, "/post/#{id(article)}")

      video_file = Path.basename(video.path)
      assert body_html =~ ~r/Intro.*<video.*#{video_file}.*more/s
      refute body_html =~ ~r/<img[^>]*#{video_file}/
      assert count(page, video_file) == count(body_html, video_file)
    end

    test "an uploaded audio file placed in the text shows as its player, in place, once", %{
      conn: conn,
      me: me
    } do
      {:ok, audio} = Files.upload(Bonfire.Files.DocumentUploader, me, audio_file())
      body = "Intro\n\n![](#{Bonfire.Files.inline_url(audio)})\n\nmore"
      article = publish_article_with_body!(me, body, [audio])

      {body_html, page} = body_and_page(conn, "/post/#{id(article)}")

      audio_file = Path.basename(audio.path)
      assert body_html =~ ~r/Intro.*<audio.*#{audio_file}.*more/s
      refute body_html =~ ~r/<img[^>]*#{audio_file}/
      assert count(page, audio_file) == count(body_html, audio_file)
    end

    # a real announcement post: a player alone in its paragraph, and a link on the line after itslabel
    test "the announcement fixture shows its player and its blog link in place, once each", %{
      conn: conn,
      me: me
    } do
      # link previews find nothing: the links are attached as given
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 404, body: ""} end)

      youtube = "https://www.youtube.com/watch?v=q0BvUFpVJMs"
      blog = "https://bonfirenetworks.org/posts/for-the-things-we-can-only-do-together/"
      image = upload_image!(me)

      body =
        "Bonfire for Communities 1.1 is out today: For the things we can only do together.\n\n#{youtube}\n\nGroups now federate, so you can find, follow and join one from a different Bonfire instance, from the threadiverse, and even from Mastodon, with the account you already have. Take your community back!\n\n![](#{Bonfire.Files.inline_url(image)})\n\nBlog post: \n#{blog}\n\n#bonfire #fediverse\n"

      {:ok, _post} =
        Bonfire.Posts.publish(
          current_user: me,
          post_attrs: %{
            post_content: %{html_body: body},
            uploaded_media: [%{"href" => youtube}, %{"href" => blog}, image]
          },
          boundary: "public"
        )

      conn
      |> visit("/feed/local")
      |> wait_async()
      |> open_browser()
      |> assert_has("[data-id=object_body] [data-id=media_link][href='#{blog}']")

      {body_html, page} = body_and_page(conn, "/feed/local")

      image_file = Path.basename(image.path)

      assert body_html =~
               ~r/Bonfire for Communities.*q0BvUFpVJMs.*Take your community back!.*#{image_file}.*Blog post:.*for-the-things-we-can-only-do-together/s

      # each media once on the page: in the body, where it sits, not again in the list below
      assert count(page, "href=\"#{blog}\"") == count(body_html, "href=\"#{blog}\"")
      assert count(page, "q0BvUFpVJMs") == count(body_html, "q0BvUFpVJMs")
      assert count(page, image_file) == count(body_html, image_file)
    end

    test "a sensitive post shows its inline media in its body, blurred, once", %{
      conn: conn,
      me: me
    } do
      inline = upload_image!(me)

      {:ok, _post} =
        Bonfire.Posts.publish(
          current_user: me,
          post_attrs: %{
            sensitive: true,
            post_content: %{
              html_body: "Intro\n\n![](#{Bonfire.Files.inline_url(inline)})\n\nmore"
            },
            uploaded_media: [inline]
          },
          boundary: "public"
        )

      {body_html, page} = body_and_page(conn, "/feed/local")

      assert body_html =~ ~s(data-id="article_media")
      # the blur `MediaLive` puts over a sensitive image
      assert body_html =~ "backdrop-blur-sm"

      assert count(page, Path.basename(inline.path)) ==
               count(body_html, Path.basename(inline.path))
    end

    test "a post in the feed shows inline media in its body, and the rest in the list", %{
      conn: conn,
      me: me
    } do
      inline = upload_image!(me)
      other = upload_image!(me)

      {:ok, _post} =
        Bonfire.Posts.publish(
          current_user: me,
          post_attrs: %{
            post_content: %{
              html_body: "Intro\n\n![](#{Bonfire.Files.inline_url(inline)})\n\nmore"
            },
            uploaded_media: [inline, other]
          },
          boundary: "public"
        )

      {body_html, _page} = body_and_page(conn, "/feed/local")

      assert body_html =~ ~r/Intro.*data-id="article_media".*#{Path.basename(inline.path)}.*more/s
      refute body_html =~ Path.basename(other.path)
    end
  end
end
