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
  | `data-auth-mode` | `local` | How logged-out visitors authenticate: `local` shows Login/Register for this instance; `remote` shows a single button to the remote-interaction page so they can reply from any fediverse server (that page also offers local log in / sign up). |
  | `data-sort-by` | thread default | Initial comment sort: `latest_reply`, `reply_count`, `boost_count`, `like_count`, `popularity_score`, `newest`. |
  | `data-sort-order` | per sort type | Sort direction for `data-sort-by`: `asc` or `desc`. |
  | `data-mode` | instance/user setting | Initial thread display mode: `flat` or `nested`. |
  | `data-theme` | — | DaisyUI theme to apply inside the iframe (e.g. `dark`, `light`). |
  | `data-token-max-age` | `720` (hours ≈ 30 days) | JS-only: hours before the stored auth token is treated as stale and re-auth is prompted. The server still enforces a hard cap of 1 year. |

  Ghost-specific usage (`data-canonical-slug`, `data-canonical-id`) is also
  documented in `bonfire_ghost/README.md`.

  ## Who a created thread belongs to (and why you can't set it here)

  This LiveView is unauthenticated and its params come from a third-party page, so it accepts nothing that chooses a created post's author, audience or destination: `data-creator`, `data-boundary`, `data-group-id`, `data-to-circles` and `data-require-topic` are parsed-and-ignored (old snippets keep working; a warning is logged). They previously let any visitor forge a post's author, place it in an arbitrary group, or publish a paid Ghost article publicly via `data-boundary=public`.

  Instead a thread is attributed to the signed-in viewer, else to the instance's configured import author (`Bonfire.Ghost.auto_import_as/0`), and a Ghost article's audience is derived from its Ghost `visibility`/tiers. Set the author and destination group in the instance's Ghost settings.
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

    {:ok,
     socket
     |> Bonfire.UI.Common.ThemeHelper.setup_embed(e(params, "theme", nil))
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

    warn_ignored_params(params)

    # TODO: cache result
    with creator when not is_nil(creator) <- embed_anchor_creator(socket),
         {:ok, %{id: id} = _media} <-
           Bonfire.Files.Media.get_or_add_media_by_uri(
             creator,
             uri,
             "public",
             nil,
             update_existing: false
           ) do
      load_params(%{"id" => id}, nil, socket)
    else
      nil ->
        error(
          uri,
          "No embed creator configured — set an import author in the instance's Ghost settings (or sign in) to create thread anchors from embeds"
        )

        {:noreply, assign_error(socket, l("No comments available here."))}

      other ->
        error(other, "Could not resolve media_uri to a thread")
        {:noreply, assign_error(socket, l("No comments available here."))}
    end
  end

  def load_params(params, _url, socket) do
    error(params, "Need an ID or media URI")
    {:noreply, assign_error(socket, l("No comments available here."))}
  end

  # accepted-but-ignored, so old embed snippets keep working — see the moduledoc
  @ignored_params ~w(creator boundary group_id to_circles require_topic)

  defp warn_ignored_params(params) do
    case Enum.filter(@ignored_params, &(not is_nil(params[&1]))) do
      [] ->
        :ok

      ignored ->
        warn(
          ignored,
          "Ignoring embed-supplied params — a thread's author and audience are decided by instance settings, not by the embedding page"
        )
    end
  end

  # server-decided: the signed-in viewer, else the instance's configured import author
  defp embed_anchor_creator(socket) do
    current_user(socket) || maybe_apply(Bonfire.Ghost, :auto_import_as, [], fallback_return: nil)
  end

  defp handle_ghost_params(slug_or_id, params, _url, socket) do
    socket = assign_global(socket, :go, e(params, "embed_parent", nil))
    url = e(params, "media_uri", nil) || e(params, "embed_parent", nil)
    warn_ignored_params(params)

    # deliberately passes no opts from `params` — see the moduledoc (EmbedHelper also drops them)
    with {:ok, %{id: id}} <-
           maybe_apply(Bonfire.Ghost.EmbedHelper, :get_or_create_post_for_article, [
             slug_or_id,
             url,
             []
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
