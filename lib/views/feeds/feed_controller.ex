# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Social.FeedController do
  use Bonfire.UI.Common.Web, :controller

  alias Bonfire.Social.Feeds
  alias Bonfire.Social.FeedLoader
  alias Bonfire.UI.Social.FeedView
  alias Bonfire.Common.Config

  # Generic feed handler
  def feed(conn, %{"feed_name" => feed_name} = params) do
    format = params["format"] || get_format(conn)

    with {:ok, feed_data} <- fetch_feed_data(feed_name, params) do
      render_feed(conn, format, feed_data)
    else
      e ->
        debug(e, "no such feed, or feed not permitted")
        # renders a 404 via Bonfire.Fail's Plug.Exception 
        raise Bonfire.Fail, :not_found
    end
  end

  def feed(conn, params) do
    feed(conn, params |> Map.put("feed_name", "local"))
  end

  # Private helper functions
  defp fetch_feed_data(feed_name, params) do
    # Build context based on available params
    opts =
      build_feed_opts(params)

    # |> debug("oopts")

    # the preset is looked up here only for the permission check and its `assigns`: `FeedLoader` looks it up again by name and merges its filters itself. Merging them in here handed it a `%FeedFilters{}`, which it takes as already prepared, so the URL's `by:` never became a subject filter and every feed showed everything
    with {:ok, preset} <- Feeds.feed_preset_if_permitted(feed_name, opts),
         %{edges: activities, page_info: page_info} <-
           FeedLoader.feed(feed_name, param_filters(opts), opts) do
      # the atom/rss views call `URIs.canonical_url/1` on the object and author, which needs
      # :peered (locality) and :shared_user (org vs person actor URL) — batch-preload here
      # (one query per assoc per page) rather than lazily per entry
      author_assocs = [:shared_user, character: [:peered]]

      # `prune: true` because a subject is not always a person: a group's feed carries the group's own boosts of what was posted in it, and a group has no `:shared_user`
      activities =
        repo().maybe_preload(
          activities,
          [
            activity: [
              subject: author_assocs,
              object: [:peered, created: [creator: author_assocs]]
            ]
          ],
          prune: true
        )

      feed_data =
        %{
          activities: activities,
          feed_name: feed_name,
          page_info: page_info,
          tag: opts[:tags],
          subject_user: opts[:subject_user]
        }
        |> Enum.into(preset[:assigns] || %{})

      {:ok, feed_data}
    end

    # |> debug("result")
  end

  defp build_feed_opts(params) do
    [
      limit: 20,
      preload_context: :all
    ]
    |> maybe_add_pagination(params)
    |> maybe_add_user_context(params)
    |> maybe_add_tag_context(params)
  end

  # only what a URL is meant to filter by, rather than every request param ("param", "format", "feed_name"...) passed through as a filter. The tag and cursor go in `opts` instead
  defp param_filters(opts) do
    %{}
    # never applied: `:object_type` is not a `FeedFilters` field (`:object_types` is), so it was dropped. Setting `object_types` instead would start limiting these feeds to posts, which is a change to decide on rather than a fix
    # |> Map.put(:object_type, Bonfire.Data.Social.Post)
    |> maybe_add_by_filter(opts)
  end

  # any character, not only users, since a group page offers this feed too, and a username that resolved to nothing left the feed unscoped. Not boundary-checked, matching the `Users.by_username/1` it replaces: the feed itself is served to anyone, and it is `FeedLoader` that keeps each post to those allowed to read it
  defp maybe_add_user_context(opts, %{"param" => username}) do
    case Bonfire.Common.Needles.get(username, skip_boundary_check: true) do
      {:ok, character} ->
        # what the feed's author header needs for its URL, the same as each entry's author below (`Users.by_username/1` used to load it). `prune: true` because a group has no `:shared_user`
        Keyword.put(
          opts,
          :subject_user,
          repo().maybe_preload(character, [:shared_user, character: [:peered]], prune: true)
        )

      _ ->
        opts
    end
  end

  defp maybe_add_user_context(feed_data, _), do: feed_data

  defp maybe_add_by_filter(filters, opts), do: Enums.maybe_put(filters, :by, opts[:subject_user])

  defp maybe_add_tag_context(opts, %{"tag" => tag}) do
    Keyword.put(opts, :tags, tag)
  end

  defp maybe_add_tag_context(feed_data, _), do: feed_data

  defp maybe_add_pagination(opts, %{"after" => cursor}) when is_binary(cursor) do
    Keyword.put(opts, :after, cursor)
  end

  defp maybe_add_pagination(opts, _), do: opts

  defp render_feed(conn, format, assigns) do
    format = normalize_format(format)
    # |> debug("fformat")
    template = "feed_view." <> format

    conn
    |> put_resp_content_type("application/#{format}+xml")
    |> put_view(FeedView)
    |> render(
      template,
      Enum.into(assigns, %{
        format: format,
        feed_config: Config.get([:feeds], %{}),
        view_module: FeedView
      })
    )
  end

  defp normalize_format(format) when format in ["atom", :atom], do: "atom"
  defp normalize_format(format) when format in ["rss", :rss], do: "rss"
  defp normalize_format(_), do: "atom"

  @doc "Feed redirect for other views who may want to redirect to the right feed format"
  def feed_redirect(conn_or_socket, format \\ "atom", feed_name \\ nil, params) do
    redirect_to(conn_or_socket, feed_path(format, feed_name, params))
  end

  def feed_path(format \\ "atom", feed_name \\ nil, params) do
    format = normalize_format(format)
    # || params["tag"]
    param =
      params["param"] ||
        params["username"]

    path =
      if param do
        "/feed/#{feed_name || "local"}/#{param}/feed.#{format}"
      else
        "/feed/#{feed_name || "local"}/feed.#{format}"
      end

    # Optionally add query string for extra params
    query =
      params
      # , "tag"
      |> Map.drop(["feed_name", "param", "username"])
      |> URI.encode_query()

    if query == "" do
      path
    else
      path <> "?" <> query
    end
  end
end
