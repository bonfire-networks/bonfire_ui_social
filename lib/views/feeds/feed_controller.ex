# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Social.FeedController do
  use Bonfire.UI.Common.Web, :controller

  alias Bonfire.Social.Feeds
  alias Bonfire.Social.FeedLoader
  alias Bonfire.Social.Objects
  alias Bonfire.Me.Users
  alias Bonfire.UI.Social.FeedView
  alias Bonfire.Common.Config

  # Generic feed handler
  def feed(conn, %{"feed_name" => feed_name} = params) do
    format = params["format"] || get_format(conn)

    with {:ok, feed_data} <- fetch_feed_data(feed_name, params) do
      render_feed(conn, format, feed_data)
    else
      _ ->
        throw(:not_found)
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

    # Get feed preset configuration
    with {:ok, %{filters: preset_filters} = preset} <-
           Feeds.feed_preset_if_permitted(feed_name, opts),
         merged_filters =
           Map.merge(preset_filters, extract_param_filters(params, opts)),
         %{edges: activities, page_info: page_info} <-
           FeedLoader.feed(feed_name, merged_filters, opts) do
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

  defp extract_param_filters(params, opts) do
    params
    # TODO: support more types
    |> Map.put(:object_type, Bonfire.Data.Social.Post)
    |> maybe_add_by_filter(opts)
  end

  defp maybe_add_user_context(opts, %{"param" => username}) do
    case Users.by_username(username) do
      {:ok, user} -> Keyword.put(opts, :subject_user, user)
      _ -> opts
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
