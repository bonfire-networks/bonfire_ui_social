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
  | `data-media-uri` | current page URL | URL to find (or, when creation is allowed — see below — create) the thread for. The canonical URI is used as the dedup key. |
  | `data-canonical-slug` | — | Ghost post slug used to find its already-imported thread. Page navigation never imports the article. |
  | `data-canonical-id` | — | Ghost post ID used to find its already-imported thread (alternative to slug; prefixed `id:` server-side). |
  | `data-auth-mode` | `local` | How logged-out visitors authenticate: `local` shows Login/Register for this instance; `remote` shows a single button to the remote-interaction page so they can reply from any fediverse server (that page also offers local log in / sign up). |
  | `data-sort-by` | thread default | Initial comment sort: `latest_reply`, `reply_count`, `boost_count`, `like_count`, `popularity_score`, `newest`. |
  | `data-sort-order` | per sort type | Sort direction for `data-sort-by`: `asc` or `desc`. |
  | `data-mode` | instance/user setting | Initial thread display mode: `flat` or `nested`. |
  | `data-published-at` | — | Article publication date (ISO 8601 or `YYYY-MM-DD`). Backdates a newly-created thread so importing an old article doesn't jump to the top of feeds. Ignored if in the future; a Ghost article is already backdated from its own published date. |
  | `data-theme` | — | DaisyUI theme to apply inside the iframe (e.g. `dark`, `light`). |
  | `data-token-max-age` | `720` (hours ≈ 30 days) | JS-only: hours before the stored auth token is treated as stale and re-auth is prompted. The server still enforces a hard cap of 1 year. |

  Ghost-specific usage (`data-canonical-slug`, `data-canonical-id`) is also
  documented in `bonfire_ghost/README.md`.

  ## Who a created thread belongs to (and why you can't set it here)

  This LiveView is unauthenticated and its params come from a third-party page, so it accepts nothing that chooses a created post's author, audience or destination: `data-creator`, `data-boundary`, `data-group-id`, `data-to-circles` and `data-require-topic` are parsed-and-ignored (old snippets keep working; a warning is logged). They previously let any visitor forge a post's author, place it in an arbitrary group, or publish a paid Ghost article publicly via `data-boundary=public`.

  A generic media thread is attributed to the instance's configured import author: the `auto_import_as` instance setting (`[:bonfire_ghost, :auto_import_as]`, set in the Ghost settings; read via `Bonfire.Ghost.auto_import_as/0`), else the signed-in viewer. The import author wins so an anchor isn't attributed to an incidental reader who merely opened the page; the viewer is the fallback so a blogger on an instance without a configured author can still start a thread by signing in. Either way the operator chooses the author in settings, not per-embed. Ghost articles are never created by this view: webhooks and the explicit historical backfill own imports, including their author, destination and audience.

  Reading an existing thread is always allowed. A missing one is *created* (see `maybe_create_anchor/3`) only when there is a real account to attribute it to: the configured import author (`auto_import_as`), else the signed-in viewer. That import author is a genuine user the operator designates to stand in for imports (effectively a bot account, but a real one with its own boundaries and feeds), NOT a synthetic placeholder. What we never fall back to is an anonymous/placeholder subject, e.g. `Media.insert`'s `0AND0MSTRANGERS0FF1NTERNET` guests-circle sentinel: if no real account resolves, nothing is created and the empty state offers local sign-in so the blogger can sign in and start the discussion.

  Creation also requires the URI's HOST to be one the operator allowlisted in `IFRAME_ALLOWED_ORIGINS` (host match via `Bonfire.UI.Common.EmbedOrigins.host_allowed?/1`; CSP-only values like `*` or `'self'` never qualify), or the embed to be a loopback dev preview (whose anchor is local-only anyway). This domain allowlist applies to everyone, with no bypass for signed-in viewers, so a blogger initializes a thread by signing in on their own (allowlisted) site.

  Creation runs on the static render too, since guests never get a connected socket on this instance. The two rules above, not "is the socket connected", are what bound creation.

  ## Dev/preview safety

  When the embedding page is served from a loopback host (`localhost`, `127.0.0.0/8`, `[::1]`), i.e. a local dev/preview of a site, any thread this embed CREATES is forced to a local-only boundary, so testing the widget can't accidentally publish public/federated content. Detected from the `embed_parent` (the page URL, always sent by the loader) or the `media_uri`. A localhost page carries a localhost URL, which is its own dedup key, so a preview never touches the production thread.
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
     |> assign_global(:link_target, "_blank")
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

    # read first (same lookup `get_or_add_media_by_uri` dedups with), so displaying an existing
    # thread needs no creator and no creation privileges. TODO: cache result
    case Bonfire.Files.Media.get_by_path(uri) do
      {:ok, %{id: id}} ->
        load_params(%{"id" => id}, nil, socket)

      _ ->
        maybe_create_anchor(uri, params, socket)
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

  # Create an anchor only when both hold, as described in the moduledoc: a real account to attribute
  # it to, and an operator-approved domain.
  defp maybe_create_anchor(uri, params, socket) do
    # the import author wins over the incidental signed-in viewer (the anchor stands in for the page)
    creator = embed_anchor_creator(socket)

    cond do
      # no account to attribute to (no configured import author and no signed-in viewer): don't create; the empty state offers local sign-in to init
      is_nil(creator) ->
        {:noreply, socket}

      # the domain must be operator-allowlisted (for everyone, no bypass), unless a loopback preview
      not (loopback_origin?(params) or Bonfire.UI.Common.EmbedOrigins.host_allowed?(uri)) ->
        warn(
          uri,
          "Not creating a thread anchor: the URI's host is not allowlisted in IFRAME_ALLOWED_ORIGINS"
        )

        {:noreply, socket}

      true ->
        case Bonfire.Files.Media.get_or_add_media_by_uri(
               creator,
               uri,
               # a preview loaded from a localhost/loopback page is kept local-only so dev
               # testing can't publish public/federated content
               embed_boundary(params),
               nil,
               # backdate the anchor to the article's publication date (if given & in the past), so
               # importing an old article doesn't jump to the top of feeds
               update_existing: false,
               id: embed_published_id(params)
             ) do
          {:ok, %{id: id}} ->
            load_params(%{"id" => id}, nil, socket)

          other ->
            error(other, "Could not resolve media_uri to a thread")

            {:noreply,
             assign_error(socket, l("Could not make the discussion ready for commenting."))}
        end
    end
  end

  # server-decided: the configured import author wins, else the signed-in viewer
  def embed_anchor_creator(socket) do
    configured_import_author() || current_user(socket)
  end

  defp configured_import_author do
    maybe_apply(Bonfire.Ghost, :auto_import_as, [], fallback_return: nil) ||
      Config.get([:bonfire_ghost, :auto_import_as], nil)
  end

  # the boundary to give an anchor CREATED by this embed: local-only when the embedding page is a
  # localhost/loopback origin (dev preview), so testing can't publish public/federated content
  defp embed_boundary(params), do: if(loopback_origin?(params), do: "local", else: "public")

  # a backdated id from the `published_at` param (nil when absent, unparseable, or in the future —
  # `generate_ulid_if_past/1` only ever moves a post EARLIER), so importing an old article doesn't
  # surface as freshly posted
  defp embed_published_id(params) do
    case e(params, "published_at", nil) do
      date when is_binary(date) and date != "" ->
        Bonfire.Common.DatesTimes.generate_ulid_if_past(date)

      _ ->
        nil
    end
  end

  # is the embedding page (or the media URI it points at) served from a loopback host?
  defp loopback_origin?(params) do
    loopback_host?(e(params, "embed_parent", nil) || e(params, "media_uri", nil))
  end

  defp loopback_host?(url) when is_binary(url) do
    case URI.parse(url).host do
      nil -> false
      host -> host in ~w(localhost 0.0.0.0 ::1 [::1]) or String.starts_with?(host, "127.")
    end
  end

  defp loopback_host?(_), do: false

  defp handle_ghost_params(slug_or_id, params, _url, socket) do
    socket = assign_global(socket, :go, e(params, "embed_parent", nil))
    url = e(params, "media_uri", nil) || e(params, "embed_parent", nil)
    warn_ignored_params(params)

    with {:ok, %{id: id}} <-
           maybe_apply(Bonfire.Ghost.EmbedHelper, :get_post_for_article, [
             slug_or_id,
             url
           ]) do
      load_params(%{"id" => id}, nil, socket)
    else
      error ->
        debug(error, "Ghost article lookup failed")
        {:noreply, assign_error(socket, l("Could not find article"))}
    end
  end
end
