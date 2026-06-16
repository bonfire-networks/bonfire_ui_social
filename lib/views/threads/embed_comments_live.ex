defmodule Bonfire.UI.Social.EmbedCommentsLive do
  @moduledoc """
  Embeddable comments thread, rendered inside an iframe on third-party sites.

  This view is driven by the embed loader script
  (`bonfire_ui_common/assets/static/js/comments_embed.js`), which reads
  `data-*` attributes off its own `<script>` tag and forwards them to this
  LiveView as query params.

  ## Embed `data-*` attributes

  All attributes are optional. Put them on the embed `<script>` tag:

      <script
        src="https://your-instance.example/js/comments_embed.js"
        data-media-uri="https://example.com/my-article"
        data-boundary="public"
        data-sort-by="latest_reply"
        data-theme="dark"
        async
      ></script>

  | Attribute | Default | Purpose |
  |---|---|---|
  | `data-post-id` | — | Explicit Bonfire post/thread ID. When set, skips the `media-uri` lookup and renders this thread directly. |
  | `data-media-uri` | current page URL | URL to find or create the thread for. The canonical URI is used as the dedup key. |
  | `data-canonical-slug` | — | Ghost post slug to find/create a thread for. |
  | `data-canonical-id` | — | Ghost post ID (alternative to slug; prefixed `id:` server-side). |
  | `data-boundary` | `"public"` | Visibility of the created thread (e.g. `public`, `local`, `nonfederated`, `discoverable`, `nonfederated:preview`). |
  | `data-group-id` | — | Bonfire group/topic the thread should be posted under. |
  | `data-require-topic` | — | When `"true"`, only create the thread if the canonical category or primary tag matches a Bonfire topic. |
  | `data-creator` | script default | User ID to attribute thread creation to. |
  | `data-auth-mode` | `local` | How logged-out visitors authenticate: `local` shows Login/Register for this instance; `remote` shows a single button to the remote-interaction page so they can reply from any fediverse server (that page also offers local log in / sign up). |
  | `data-sort-by` | thread default | Initial comment sort: `latest_reply`, `reply_count`, `boost_count`, `like_count`, `popularity_score`, `newest`. |
  | `data-sort-order` | per sort type | Sort direction for `data-sort-by`: `asc` or `desc`. |
  | `data-mode` | instance/user setting | Initial thread display mode: `flat` or `nested`. |
  | `data-theme` | — | DaisyUI theme to apply inside the iframe (e.g. `dark`, `light`). |
  | `data-token-max-age` | `720` (hours ≈ 30 days) | JS-only: hours before the stored auth token is treated as stale and re-auth is prompted. The server still enforces a hard cap of 1 year. |

  Ghost-specific usage (`data-canonical-slug`, `data-canonical-id`,
  `data-group-id`, `data-require-topic`) is also documented in
  `bonfire_ghost/README.md`.
  """

  use Bonfire.UI.Common.Web,
      {:surface_live_view_child, layout: {Bonfire.UI.Common.LayoutView, :iframe}}

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.LoadCurrentUser,
              Bonfire.UI.Me.LivePlugs.LoadCurrentUserFromEmbedToken
            ]}

  def mount(raw_params, _session, socket) do
    socket = Phoenix.Component.assign_new(socket, :current_params, fn -> nil end)
    params = socket.assigns[:current_params] || (is_map(raw_params) && raw_params) || %{}
    embed_theme = e(params, "theme", nil)

    {:ok,
     socket
     |> Bonfire.UI.Common.ThemeHelper.push_theme(embed_theme)
     |> assign_new(:no_header, fn -> true end)
     |> assign_new(:without_sidebar, fn -> true end)
     |> assign_new(:without_secondary_widgets, fn -> true end)
     |> assign_new(:sidebar_widgets, fn -> [] end)
     |> assign_new(:force_static, fn -> false end)
     |> assign(
       page_title: l("Comments"),
       page: "comments",
       showing_within: :thread_embed,
       reply_to_id: nil,
       inline_action_kind: nil,
       inline_action_target_slot_id: nil,
       inline_action_object_id: nil,
       inline_action_object_type: nil,
       inline_action_object_label: nil,
       inline_action_is_remote: false,
       inline_action_permalink: nil,
       no_mobile_header: true,
       hide_thread_stats: true,
       embed_theme: embed_theme,
       # "local" (default: Login/Register for this instance) or "remote"
       # (a single button to the remote-interaction page, so guests can reply
       # from any fediverse server). Set via the `data-auth-mode` embed attr.
       auth_mode: e(params, "auth_mode", nil),
       participants: nil,
       sort_by: maybe_to_atom(e(params, "sort_by", nil)),
       sort_order: maybe_to_atom(e(params, "sort_order", nil)),
       activity: nil,
       object: nil,
       object_id: nil,
       reply_id: nil,
       thread_id: nil,
       page_info: nil,
       replies: nil,
       threaded_replies: nil,
       include_path_ids: nil,
       thread_mode:
         maybe_to_atom(e(params, "mode", nil)) ||
           Settings.get(
             [Bonfire.UI.Social.ThreadLive, :thread_mode],
             nil,
             assigns(socket)[:__context__]
           ),
       loading: false
     )
     |> assign_global(:go, e(params, "embed_parent", nil))
     |> then(fn socket ->
       with {:noreply, socket} <- load_params(params, nil, socket) do
         socket
       else
         e ->
           error(e, "Error loading comments embed params")
           socket
       end
     end)}
  end

  # def handle_params(params, url, socket), do: load_params(params, url, socket)

  # reply_to_id is set via the generic `{:assign, ...}` handler (send_self), not a dedicated message.

  def handle_event("reset_reply_to", _params, socket) do
    {:noreply, assign(socket, reply_to_id: nil)}
  end

  def load_params(%{"id" => "comment_" <> comment_id} = _params, _url, socket)
      when is_binary(comment_id) do
    debug(comment_id, "comment_id that needs redirection")

    with thread_id when is_binary(thread_id) <-
           Bonfire.Social.Threads.fetch_thread_id(comment_id,
             current_user: current_user(socket)
           ) do
      {:noreply, redirect_to(socket, "/comments/#{thread_id}/reply/#{comment_id}")}
    else
      error ->
        debug(error, "Could not find thread for comment")

        {:noreply,
         assign_error(socket, l("Comment not found or you don't have permission to view it"))}
    end
  end

  def load_params(%{"id" => id} = params, _url, socket) when is_binary(id) do
    debug(id, "object_id")

    reply_id = e(params, "reply_id", nil)

    {:noreply,
     socket
     |> assign(
       object_id: id,
       thread_id: id,
       reply_id: reply_id
       #  include_path_ids:
       #    Bonfire.Social.Threads.LiveHandler.maybe_include_path_ids(
       #      reply_id,
       #      e(params, "level", nil),
       #      e(assigns(socket), :__context__, nil) || assigns(socket)
       #    )
     )
     |> assign_new(:main_object_component_id, fn ->
       Bonfire.UI.Social.ActivityLive.component_id(id, "main_object", nil)
     end)}
  end

  def load_params(%{"canonical_slug" => slug} = params, url, socket) when is_binary(slug) do
    handle_ghost_params(slug, params, url, socket)
  end

  def load_params(%{"canonical_id" => id} = params, url, socket) when is_binary(id) do
    handle_ghost_params("id:#{id}", params, url, socket)
  end

  def load_params(%{"media_uri" => uri} = params, _url, socket) when is_binary(uri) do
    socket = assign_global(socket, :go, e(params, "embed_parent", nil) || uri)

    # TODO: cache result
    with {:ok, %{id: id} = _media} <-
           Bonfire.Files.Media.get_or_add_media_by_uri(
             params["creator"] || current_user_or_id(socket),
             uri,
             params["boundary"] || "public",
             params["to_circles"],
             update_existing: false
           ) do
      load_params(%{"id" => id}, nil, socket)
    else
      other ->
        error(other, "Could not resolve media_uri to a thread")
        {:noreply, assign_error(socket, l("No comments available here."))}
    end
  end

  def load_params(params, _url, socket) do
    error(params, "Need an ID or media URI")
    {:noreply, assign_error(socket, l("No comments available here."))}
  end

  defp handle_ghost_params(slug_or_id, params, _url, socket) do
    socket = assign_global(socket, :go, e(params, "embed_parent", nil))
    url = e(params, "media_uri", nil) || e(params, "embed_parent", nil)

    with {:ok, %{id: id}} <-
           maybe_apply(Bonfire.Ghost.EmbedHelper, :get_or_create_post_for_article, [
             slug_or_id,
             url,
             [
               current_user: params["creator"] || current_user(socket),
               boundary: params["boundary"],
               group_id: params["group_id"],
               require_topic: params["require_topic"] == "true"
             ]
           ]) do
      load_params(%{"id" => id}, nil, socket)
    else
      {:error, :ghost_not_configured} ->
        uri = e(params, "media_uri", nil) || e(params, "embed_parent", nil)

        if uri,
          do:
            load_params(
              params
              |> Map.delete("canonical_slug")
              |> Map.delete("canonical_id")
              |> Map.put("media_uri", uri),
              nil,
              socket
            ),
          else: {:noreply, assign_error(socket, l("Could not find article"))}

      {:error, :topic_required} ->
        {:noreply,
         assign_error(
           socket,
           l("This article is not associated with a topic on this Bonfire instance")
         )}

      error ->
        debug(error, "Ghost article lookup failed")
        {:noreply, assign_error(socket, l("Could not find article"))}
    end
  end
end
