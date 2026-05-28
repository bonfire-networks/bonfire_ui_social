defmodule Bonfire.UI.Social.CommentsEmbedGuestReplyTest do
  @moduledoc """
  Regression coverage for the logged-out comments-embed remote-interaction
  flow:

    * the guest fallback composer honours the `reply_to_id` assign, so its
      remote-interaction link follows the active reply (template);
    * the `:thread_embed` guest branch of
      `Bonfire.UI.Social.Threads.LiveHandler.reply/4` assigns `reply_to_id`
      to the clicked reply instead of collapsing to the thread root (handler);
    * a media-only embed never emits a remote-interaction link with an empty
      `uri` (the guard falls back to local Login/Register instead);
    * the `reply_to_activity` event resolves the object from the pushed id
      (not nil LiveView assigns), so guests reach remote interaction rather
      than being bounced to `/login`.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Common.URIs

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  setup do
    user = fake_user!()

    {:ok, root} =
      Bonfire.Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: "embed root post"}},
        boundary: "public"
      )

    {:ok, reply} =
      Bonfire.Posts.publish(
        current_user: user,
        post_attrs: %{
          post_content: %{html_body: "a specific reply"},
          reply_to_id: root.id
        },
        boundary: "public"
      )

    {:ok, user: user, root: root, reply: reply}
  end

  describe "guest composer follows the reply_to_id assign" do
    test "remote-interaction link targets the active reply once reply_to_id is set",
         %{root: root, reply: reply} do
      {:ok, view, _html} =
        live(conn(), "/comments/embed/#{root.id}?auth_mode=remote")

      # Initially the guest composer falls back to the thread root.
      assert assigns(view).reply_to_id == nil

      root_url = URIs.canonical_url(root)
      reply_url = URIs.canonical_url(reply)
      refute root_url == reply_url

      html = render(view)
      assert html =~ "inline_composer_remote_interaction_"
      assert html =~ URI.encode_www_form(root_url) or html =~ root_url

      # `send_self(reply_to_id: ...)` (what the guest reply handler does) is
      # delivered as `{:assign, ...}` to the LiveView process.
      send(view.pid, {:assign, [reply_to_id: reply.id]})

      html = render(view)
      assert assigns(view).reply_to_id == reply.id
      assert html =~ URI.encode_www_form(reply_url) or html =~ reply_url
    end
  end

  describe "guest :thread_embed reply handler targets the clicked reply" do
    test "clicking Reply on a reply assigns reply_to_id to that reply (not the root)",
         %{root: root, reply: reply} do
      {:ok, view, _html} =
        live(conn(), "/comments/embed/#{root.id}?auth_mode=remote")

      assert assigns(view).reply_to_id == nil

      # The per-reply Reply button (embed_actions) pushes the
      # "Bonfire.Social.Feeds:reply_to_activity" event from the reply's
      # activity component, whose `object` is the reply.
      view
      |> element("[data-id=action_reply]")
      |> render_click()

      assert assigns(view).reply_to_id == reply.id
    end
  end

  describe "a media-only embed never emits an empty remote-interaction uri" do
    test "guest media-only embed remote CTA either carries a non-empty url or is absent",
         %{user: user} do
      url = "https://example.com/some/article-#{System.unique_integer([:positive])}"

      # Insert the Media directly (mirrors comments_embed once Unfurl has run)
      # to keep the test network-free — no AP fetch.
      {:ok, media} =
        Bonfire.Files.Media.insert(
          user,
          url,
          %{media_type: "link", size: 0},
          %{url: url, media_type: "link", metadata: %{"label" => "Some Article"}}
        )

      {:ok, view, _html} =
        live(conn(), "/comments/embed/#{media.id}?auth_mode=remote")

      # the embed resolved to the media-only thread
      assert assigns(view).thread_id == media.id

      html = render(view)

      # the opening <a> tag (attribute order is not guaranteed)
      remote_tag =
        Regex.run(
          ~r/<a [^>]*id="inline_composer_remote_interaction_[^"]*"[^>]*>/s,
          html
        ) ||
          Regex.run(~r/<a [^>]*href="[^"]*remote_interaction[^"]*"[^>]*>/s, html)

      case remote_tag && Regex.run(~r/href="([^"]+)"/, hd(remote_tag)) do
        [_, href] ->
          # Regression: the carried url/uri param must never be empty
          # (an empty `?uri=` dead-ends on the remote server).
          query =
            href
            |> String.replace("&amp;", "&")
            |> URI.decode()
            |> URI.parse()
            |> Map.get(:query)
            |> Kernel.||("")

          params = URI.decode_query(query)

          assert is_binary(params["url"]) and params["url"] != "",
                 "remote-interaction url param must not be empty, got: #{inspect(params)} from #{href}"

        nil ->
          # Acceptable: when no resolvable URL exists the guard suppresses the
          # remote CTA and falls back to local Login/Register.
          assert html =~ "inline_composer_login_" or html =~ "inline_composer_signup_"
      end
    end
  end

  describe "reply_to_activity uses the pushed id, not nil LiveView assigns" do
    test "guest Reply in the embed resolves the object → remote interaction, not /login",
         %{root: root, reply: reply} do
      {:ok, view, _html} =
        live(conn(), "/comments/embed/#{root.id}?auth_mode=remote")

      assert assigns(view).reply_to_id == nil

      # This is the event the embed Reply button pushes when
      # `@activity_component_id` is set (the real-app path). The LiveView
      # (EmbedCommentsLive) has no `object`/`activity` assigns, so the handler
      # must use the pushed `id` — otherwise reply_to is nil → no canonical
      # URL → the remote-interaction guard sends the guest to /login.
      render_hook(view, "Bonfire.Social.Feeds:reply_to_activity", %{"id" => reply.id})

      # not bounced to local login (no pending redirect on the socket)
      assert :sys.get_state(view.pid).socket.redirected == nil
      # the clicked object was resolved from the id param
      assert assigns(view).reply_to_id == reply.id
    end
  end
end
