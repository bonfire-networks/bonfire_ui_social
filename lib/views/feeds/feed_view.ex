# SPDX-License-Identifier: AGPL-3.0-only

defmodule Bonfire.UI.Social.FeedView do
  use Bonfire.UI.Common.Web, {:view, root: "lib/views/feeds"}

  alias Bonfire.Common.Config
  alias Bonfire.Common.Text
  alias Bonfire.Me.Users
  alias Bonfire.Files.IconUploader
  alias Bonfire.Social.Objects

  def pub_date(%DateTime{} = date) do
    DateTime.to_iso8601(date)
  end

  def pub_date(date) do
    # Try to extract date from ULID first
    case Bonfire.Common.DatesTimes.to_date_time(date) do
      nil -> nil
      dt -> DateTime.to_iso8601(dt)
    end
  end

  def prepare_activity(activity, opts \\ []) do
    object = e(activity, :object, %{})

    author =
      if opts[:author], do: e(activity, :subject, nil) || e(object, :created, :creator, nil)

    peered =
      e(object, :peered, nil) ||
        e(author, :character, :peered, nil) ||
        if id(object) == id(activity) do
          e(activity, :peered, nil)
        end

    %{
      activity: activity |> Map.drop([:object, :subject, :created]),
      object: object,
      author: author,
      is_remote:
        !Bonfire.Social.is_local?(
          peered ||
            e(activity, :subject, nil) ||
            e(opts, :subject_user, nil),
          false
        )
    }

    # |> debug("accctiv")
  end

  def most_recent_update(activities) do
    case List.first(activities) do
      %{updated_at: updated_at} when not is_nil(updated_at) ->
        DateTime.to_iso8601(updated_at)

      %{published_at: published_at} when not is_nil(published_at) ->
        DateTime.to_iso8601(published_at)

      _ ->
        DateTime.to_iso8601(DateTime.utc_now())
    end
  end

  def most_recent_update(activities, user) do
    case {List.first(activities), user} do
      {%{updated_at: updated_at}, _} when not is_nil(updated_at) ->
        DateTime.to_iso8601(updated_at)

      {_, user} when not is_nil(user) ->
        DateTime.to_iso8601(e(user, :updated_at, DateTime.utc_now()))

      _ ->
        DateTime.to_iso8601(DateTime.utc_now())
    end
  end

  # def feed_logo do
  #   Config.get([:feeds, :logo], "/images/bonfire-logo.png")
  # end

  # def logo(user) do
  #   Media.avatar_url(user) || "/images/avatar-placeholder.png"
  # end

  def activity_title(data, opts \\ %{}) do
    content =
      e(data, :post_content, :name, nil) || e(data, :post_content, :summary, nil) ||
        e(data, :post_content, :html_body, nil) || ""

    max_length = opts[:max_length] || 100

    content
    |> Text.maybe_markdown_to_html()
    |> Text.text_only()
    |> Text.truncate(max_length)
    |> escape()
  end

  def activity_content(data) do
    escape(e(data, :post_content, :html_body, nil))
  end

  def activity_context(activity) do
    context = e(activity, :replied, :thread_id, "public")
    escape(context)
  end

  def attachment_href(attachment) do
    attachment["url"] || ""
  end

  def attachment_type(attachment) do
    attachment["mediaType"] || "application/octet-stream"
  end

  def get_href(id) when is_binary(id), do: id
  def get_href(object), do: URIs.canonical_url(object)

  def hashtags(object) do
    e(object, :tags, [])
  end

  def as_public, do: "https://www.w3.org/ns/activitystreams#Public"

  def endpoint_url do
    Config.get(:endpoint_module).url()
  end

  def escape(html) when is_binary(html) do
    html
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  def escape(nil), do: ""
  def escape(other), do: to_string(other)
end
