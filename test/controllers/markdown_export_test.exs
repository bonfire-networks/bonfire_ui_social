defmodule Bonfire.UI.Social.MarkdownExportTest do
  @moduledoc """
  Markdown export of objects (`/post/markdown/:id` and `/discussion/markdown/:id`).

  Pins the behaviour of the download endpoint: response headers, the optional YAML frontmatter, the optional quoted reply tree, and that boundaries are enforced.
  Covers both `Bonfire.Data.Social.Post` and `Bonfire.Articles.Article`, both reuse the same `PostContent` mixin, so both must serialize identically.
  """
  use Bonfire.UI.Social.ConnCase, async: false

  import Bonfire.Posts.Fake, only: [fake_post!: 3, fake_comment!: 4]
  import Bonfire.Articles.Fake, only: [fake_article!: 3]

  @moduletag :ui

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account), account: account, me: me}
  end

  # `fake_comment!/4` only defaults in the `reply_to_id` when no attrs are given, so pass it
  defp reply!(me, reply_to, body) do
    fake_comment!(me, reply_to, "public", %{
      reply_to_id: uid(reply_to),
      post_content: %{html_body: body}
    })
  end

  # `canonical_url/1` refuses to lazy-load `:peered` (it must be preloaded at the source), so preload it here rather than in the assertion
  defp canonical_url!(object) do
    object
    |> Bonfire.Common.Repo.Preload.maybe_preload(:peered)
    |> URIs.canonical_url()
  end

  # the line the given text ends up on, so we can assert on its quote prefix
  defp line_containing(markdown, text) do
    markdown
    |> String.split("\n")
    |> Enum.find(&String.contains?(&1, text))
  end

  describe "downloading a post as markdown" do
    test "serves the body as an attachment", %{conn: conn, me: me} do
      post = fake_post!(me, "public", %{post_content: %{html_body: "Body of the exported post"}})

      conn = get(conn, "/post/markdown/#{id(post)}")

      assert markdown = response(conn, 200)
      assert markdown =~ "Body of the exported post"

      assert "text/markdown" <> _ = List.first(get_resp_header(conn, "content-type"))

      assert [~s[attachment; filename="#{id(post)}.md"]] ==
               get_resp_header(conn, "content-disposition")
    end

    test "includes the title and summary", %{conn: conn, me: me} do
      post =
        fake_post!(me, "public", %{
          post_content: %{
            name: "The exported title",
            summary: "The exported summary",
            html_body: "Body with a heading"
          }
        })

      markdown = conn |> get("/post/markdown/#{id(post)}") |> response(200)

      assert markdown =~ "## The exported title"
      assert markdown =~ "### The exported summary"
      assert markdown =~ "Body with a heading"
    end

    test "omits frontmatter unless asked for", %{conn: conn, me: me} do
      post =
        fake_post!(me, "public", %{
          post_content: %{name: "No frontmatter please", html_body: "Body without frontmatter"}
        })

      markdown = conn |> get("/post/markdown/#{id(post)}") |> response(200)

      refute String.starts_with?(markdown, "---")
      refute markdown =~ "uri:"
    end

    test "includes frontmatter when asked for", %{conn: conn, me: me} do
      post =
        fake_post!(me, "public", %{
          post_content: %{name: "Frontmatter title", html_body: "Body under the frontmatter"}
        })

      markdown =
        conn |> get("/post/markdown/#{id(post)}?frontmatter=true") |> response(200)

      assert String.starts_with?(markdown, "---")
      assert markdown =~ ~s[title: "Frontmatter title"]
      assert markdown =~ "uri: #{canonical_url!(post)}"
      assert markdown =~ ~s[author: "#{e(me, :profile, :name, nil)}"]
      assert markdown =~ "Body under the frontmatter"
    end

    test "omits replies unless asked for", %{conn: conn, me: me} do
      post = fake_post!(me, "public", %{post_content: %{html_body: "Body of the parent post"}})
      reply!(me, post, "Body of the reply")

      markdown = conn |> get("/post/markdown/#{id(post)}") |> response(200)

      assert markdown =~ "Body of the parent post"
      refute markdown =~ "Body of the reply"
    end

    test "includes replies as quotes when asked for", %{conn: conn, me: me} do
      post = fake_post!(me, "public", %{post_content: %{html_body: "Body of the parent post"}})
      reply!(me, post, "Body of the reply")

      markdown = conn |> get("/post/markdown/#{id(post)}?replies=true") |> response(200)

      assert markdown =~ "Body of the parent post"
      assert markdown =~ "Body of the reply"

      # the reply is quoted one level deeper than the root
      assert markdown |> line_containing("Body of the reply") |> String.starts_with?(">")
      refute markdown |> line_containing("Body of the parent post") |> String.starts_with?(">")
    end

    test "404s for an unknown id", %{conn: conn} do
      conn = get(conn, "/post/markdown/#{Needle.ULID.generate()}")

      assert response(conn, 404)
    end

    test "404s for a post we are not permitted to read", %{conn: conn} do
      someone_else = fake_user!()

      private_post =
        fake_post!(someone_else, "mentions", %{
          post_content: %{html_body: "Body nobody else may read"}
        })

      conn = get(conn, "/post/markdown/#{id(private_post)}")

      assert response(conn, 404)
    end
  end

  describe "downloading an article as markdown" do
    test "serves the body as an attachment", %{conn: conn, me: me} do
      article =
        fake_article!(me, "public", %{
          post_content: %{
            name: "The exported article",
            html_body: "Body of the exported article"
          }
        })

      conn = get(conn, "/post/markdown/#{id(article)}")

      assert markdown = response(conn, 200)
      assert markdown =~ "## The exported article"
      assert markdown =~ "Body of the exported article"

      assert "text/markdown" <> _ = List.first(get_resp_header(conn, "content-type"))
    end

    test "is also served from the discussion path", %{conn: conn, me: me} do
      article =
        fake_article!(me, "public", %{
          post_content: %{
            name: "Article at both paths",
            html_body: "Body reachable at both paths"
          }
        })

      from_post_path = conn |> get("/post/markdown/#{id(article)}") |> response(200)
      from_discussion_path = conn |> get("/discussion/markdown/#{id(article)}") |> response(200)

      assert from_discussion_path == from_post_path
      assert from_discussion_path =~ "Body reachable at both paths"
    end

    test "is reachable by adding .md to the article's own URL", %{conn: conn, me: me} do
      article =
        fake_article!(me, "public", %{
          post_content: %{name: "Article at a .md URL", html_body: "Body at a .md URL"}
        })

      conn = get(conn, "/discussion/#{id(article)}.md")

      assert redirected_to(conn) == "/discussion/markdown/#{id(article)}"
    end

    test "includes frontmatter when asked for", %{conn: conn, me: me} do
      article =
        fake_article!(me, "public", %{
          post_content: %{name: "Article frontmatter title", html_body: "Body of the article"}
        })

      markdown =
        conn |> get("/post/markdown/#{id(article)}?frontmatter=true") |> response(200)

      assert String.starts_with?(markdown, "---")
      assert markdown =~ ~s[title: "Article frontmatter title"]
      assert markdown =~ "uri: #{canonical_url!(article)}"
      assert markdown =~ "Body of the article"
    end
  end
end
