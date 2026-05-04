defmodule Bonfire.UI.Social.LoadObjectTest do
  @moduledoc """
  Covers `Bonfire.Social.Objects.LiveHandler.load_object_assigns/1` end-to-end,
  through the routes that exercise heads 3 (`post_id`) and 4 (`object_id`).

  The key scenarios:
    * regular `Bonfire.Data.Social.Post` thread root (the common case)
    * `Bonfire.Files.Media` thread root with media_type "article" (the
      comments_embed flow). For this case, `Bonfire.Posts.read/2` returns
      `{:error, :not_found}` and the loader must fall through to
      `Bonfire.Social.Objects.read/2` — historically broken because the
      original `maybe_apply(..., fallback_fun: ...)` only fired on missing
      module, not on `{:error, _}`.
  """

  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Files.Media
  alias Bonfire.Social.Objects

  @media_uri "https://blog.example.com/test-article/"

  setup do
    account = fake_account!()
    user = fake_user!(account)
    {:ok, conn: conn(user: user, account: account), user: user}
  end

  describe "Post-rooted thread" do
    test "/discussion/<post_id> renders the main object and replies", %{
      conn: conn,
      user: user
    } do
      {:ok, post} =
        Posts.publish(
          current_user: user,
          post_attrs: %{post_content: %{html_body: "Original post"}},
          boundary: "public"
        )

      {:ok, _reply} =
        Posts.publish(
          current_user: user,
          post_attrs: %{
            post_content: %{html_body: "First reply"},
            reply_to_id: post.id
          },
          boundary: "public"
        )

      conn
      |> visit("/discussion/#{post.id}")
      |> assert_has("article", text: "Original post")
      |> assert_has("article", text: "First reply")
    end

    test "/post/<post_id> renders the main object", %{conn: conn, user: user} do
      {:ok, post} =
        Posts.publish(
          current_user: user,
          post_attrs: %{post_content: %{html_body: "Hello world"}},
          boundary: "public"
        )

      conn
      |> visit("/post/#{post.id}")
      |> assert_has("article", text: "Hello world")
    end
  end

  describe "Media-rooted thread (comments_embed flow)" do
    setup do
      Tesla.Mock.mock_global(fn _env ->
        {:ok,
         %Tesla.Env{
           status: 200,
           body: """
           <html>
             <head>
               <title>Test Article Title</title>
               <meta property="og:type" content="article" />
               <meta property="og:title" content="Test Article Title" />
             </head>
             <body><p>Article body</p></body>
           </html>
           """
         }}
      end)

      :ok
    end

    test "/discussion/<media_id> renders for a Media thread root with replies", %{
      conn: conn,
      user: user
    } do
      {:ok, media} =
        Media.get_or_add_media_by_uri(user, @media_uri, "public", [], update_existing: false)

      assert media.__struct__ == Bonfire.Files.Media,
             "expected get_or_add_media_by_uri to return a Media struct"

      {:ok, _reply} =
        Posts.publish(
          current_user: user,
          post_attrs: %{
            post_content: %{html_body: "Comment on the article"},
            reply_to_id: media.id
          },
          boundary: "public"
        )

      conn
      |> visit("/discussion/#{media.id}")
      |> assert_has("article", text: "Comment on the article")
    end

    test "/post/<media_id> falls through from Posts.read to Objects.read", %{
      conn: conn,
      user: user
    } do
      # This is the regression case for the `maybe_apply(..., fallback_fun: ...)`
      # bug: head 3 (post_id) was attempting Posts.read, which returns
      # {:error, :not_found} for a Media id. The original code's fallback never
      # fired on {:error, _}, so we ended up in not_found_fallback. After the
      # fix, head 3 now falls through to Objects.read and the page loads.
      {:ok, media} =
        Media.get_or_add_media_by_uri(user, @media_uri, "public", [], update_existing: false)

      {:ok, _reply} =
        Posts.publish(
          current_user: user,
          post_attrs: %{
            post_content: %{html_body: "Reply to media"},
            reply_to_id: media.id
          },
          boundary: "public"
        )

      conn
      |> visit("/post/#{media.id}")
      |> assert_has("article", text: "Reply to media")
    end
  end

  describe "load_object_assigns behavior (unit-ish)" do
    test "head 4 (object_id) loads a Post via Objects.read", %{user: user} do
      {:ok, post} =
        Posts.publish(
          current_user: user,
          post_attrs: %{post_content: %{html_body: "Direct read"}},
          boundary: "public"
        )

      assert {:ok, loaded} =
               Objects.read(post.id, current_user: user)

      assert loaded.id == post.id
    end

    test "head 4 (object_id) loads a Media via Objects.read", %{user: user} do
      Tesla.Mock.mock_global(fn _env ->
        {:ok,
         %Tesla.Env{
           status: 200,
           body: "<html><head><title>Direct</title></head></html>"
         }}
      end)

      {:ok, media} =
        Media.get_or_add_media_by_uri(user, @media_uri, "public", [], update_existing: false)

      assert {:ok, loaded} =
               Objects.read(media.id, current_user: user)

      assert loaded.id == media.id

      # The whole point: Objects.read can produce a usable result for a Media,
      # so head 4 (and head 3 via the read_post_or_object fallback) succeeds.
    end
  end

  describe "OpenPreview modal — ObjectThreadLive stateful render" do
    # PhoenixTest can't fire the JS hook that opens the modal. To exercise the
    # modal's actual render path (its `update/2` callback, which is where we
    # were crashing before the load fix), we render `ObjectThreadLive` directly
    # with the same shape of `modal_assigns` that `Bonfire.UI.Common.OpenPreviewLive`
    # passes through `PreviewContentLive`.

    test "renders a deep-reply preview for a Post-rooted thread", %{user: user} do
      {:ok, post} =
        Posts.publish(
          current_user: user,
          post_attrs: %{post_content: %{html_body: "Root post"}},
          boundary: "public"
        )

      {:ok, reply} =
        Posts.publish(
          current_user: user,
          post_attrs: %{
            post_content: %{html_body: "A deep reply"},
            reply_to_id: post.id
          },
          boundary: "public"
        )

      doc = render_modal(post.id, reply, user, post_id: post.id)

      assert doc =~ "Root post" or doc =~ "A deep reply",
             "expected the modal render to include the main object and/or the preloaded reply"
    end

    test "renders a deep-reply preview for a Media-rooted thread (the bug fix)", %{user: user} do
      Tesla.Mock.mock_global(fn _env ->
        {:ok,
         %Tesla.Env{status: 200, body: "<html><head><title>Article</title></head></html>"}}
      end)

      {:ok, media} =
        Media.get_or_add_media_by_uri(user, @media_uri, "public", [], update_existing: false)

      {:ok, reply} =
        Posts.publish(
          current_user: user,
          post_attrs: %{
            post_content: %{html_body: "Comment on the article"},
            reply_to_id: media.id
          },
          boundary: "public"
        )

      # In the real call site (activity_live.ex), `post_id` is set to the
      # thread root's id when @object_type is :article — even when the
      # underlying schema is `Bonfire.Files.Media`. This is what triggered
      # head 3 (`post_id`) to fire and `Posts.read` to fail before the
      # `read_post_or_object` fix.
      doc = render_modal(media.id, reply, user, post_id: media.id)

      assert doc =~ "Comment on the article",
             "expected the modal to render the preloaded reply even though Posts.read failed for the Media"
    end
  end

  # Mirrors the `modal_assigns` shape that `OpenPreviewLive` passes for the
  # deep-reply case (`!top_of_thread? and !reply_to_top_of_thread?`):
  # `object`/`activity` are nil, `replies` carries the preloaded comment tree,
  # `modal_component_stateful?` is true.
  defp render_modal(thread_id, reply, user, opts) do
    base = [
      thread_id: thread_id,
      object_id: thread_id,
      reply_id: reply.id,
      include_path_ids: [reply.id],
      current_url: "/discussion/#{thread_id}/reply/#{reply.id}",
      activity: nil,
      object: nil,
      replies: [
        %{
          id: "preview-comment-reply",
          activity: Map.put(reply.activity, :object, reply)
        }
      ],
      activity_inception: "preview",
      showing_within: :thread,
      loaded: true
    ]

    assigns = if opts[:post_id], do: Keyword.put(base, :post_id, opts[:post_id]), else: base

    render_stateful(
      Bonfire.UI.Social.ObjectThreadLive,
      Map.new(assigns),
      current_user: user
    )
  end
end
