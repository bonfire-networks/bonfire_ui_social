# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Social.FeedController do
  use Bonfire.UI.Common.Web, :controller

  alias Bonfire.Social.Feeds
  alias Bonfire.Social.FeedLoader
  alias Bonfire.Social.Objects
  alias Bonfire.Me.Users
  alias Bonfire.UI.Social.FeedView
  alias Bonfire.Common.Config

  @doc "Feed redirect for other views who may want to redirect to the right feed format"
  def feed_redirect(conn_or_socket, format, %{"feed_name" => feed_name} = params) do
    if format in ["atom", "rss"] do
      redirect_to(conn_or_socket, build_feed_path(feed_name, params, format))
    else
      redirect_to(conn_or_socket, build_feed_path(feed_name, params, "atom"))
    end
  end

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
    opts = build_feed_opts(params)

    # Get feed preset configuration
    with {:ok, %{assigns: preset_assigns, filters: preset_filters}} <-
           Feeds.feed_preset_if_permitted(feed_name, opts),
         merged_filters = Map.merge(preset_filters, extract_param_filters(params)),
         %{edges: activities, page_info: page_info} <-
           FeedLoader.feed(String.to_atom(feed_name), merged_filters, opts) do
      feed_data =
        %{
          activities: activities,
          feed_name: feed_name,
          page_info: page_info,
          subject_user: opts[:subject_user]
        }
        |> maybe_add_tag_context(params)
        |> Enum.into(preset_assigns)

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
  end

  defp extract_param_filters(params) do
    params
    # TODO: support more types
    |> Map.put(:object_type, Bonfire.Data.Social.Post)
    |> maybe_add_tag_filter(params)
    |> maybe_add_by_filter(params)
  end

  defp maybe_add_tag_filter(filters, %{"tag" => tag}) when is_binary(tag) do
    Map.put(filters, :tags, tag)
  end

  defp maybe_add_tag_filter(filters, _), do: filters

  defp maybe_add_by_filter(filters, %{"by" => by}) when is_binary(by) do
    Map.put(filters, :by, by)
  end

  defp maybe_add_by_filter(filters, _), do: filters

  defp maybe_add_user_context(feed_data, %{"username" => username}) do
    case Users.by_username(username) do
      {:ok, user} -> Map.put(feed_data, :subject_user, user)
      _ -> feed_data
    end
  end

  defp maybe_add_user_context(feed_data, _), do: feed_data

  defp maybe_add_tag_context(feed_data, %{"tag" => tag}) do
    # TODO
    feed_data
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

  defp build_feed_path(feed_name, params, format) do
    param =
      params["param"] ||
        params["username"] ||
        params["tag"]

    path =
      if param do
        "/feeds/#{feed_name}/#{param}.#{format}"
      else
        "/feeds/#{feed_name}.#{format}"
      end

    # Optionally add query string for extra params
    query =
      params
      |> Map.drop(["feed_name", "param", "username", "tag"])
      |> URI.encode_query()

    if query == "" do
      path
    else
      path <> "?" <> query
    end
  end
end
