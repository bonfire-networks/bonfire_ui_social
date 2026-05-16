defmodule Bonfire.UI.Social.PostContentSEO do
  @moduledoc """
  Builds meaningful page metadata (title, description, image) for post/discussion
  pages, so sharing a post to X, Mastodon, Slack, etc. shows the actual content
  rather than the generic instance defaults.

  Most Bonfire posts have neither a `title` nor a `summary` (the latter is only
  the content-warning field) — only an `html_body` — so without these fallbacks
  the OpenGraph/Twitter tags would always degrade to the instance name.

  Used by the `SEO.*.Build` protocol implementations in `post_content_seo.ex`.
  """
  use Bonfire.UI.Common

  @description_length 200

  @doc "The post's creator (subject) from whichever association is loaded."
  def creator(post_content) do
    e(post_content, :pointer, :created, :creator, nil) ||
      e(post_content, :activity, :subject, nil) ||
      e(post_content, :pointer, :created, :creator_id, nil) ||
      e(post_content, :activity, :subject_id, nil)
  end

  @doc "Display name of the post's author."
  def author(post_content), do: author(post_content, creator(post_content))

  def author(post_content, creator) do
    Bonfire.Me.Characters.display_username(creator, true) ||
      e(creator, :profile, :name, nil) ||
      e(post_content, :activity, :subject, :profile, :name, nil)
  end

  @doc "Post title, falling back to the thread name, then to `Post by {author}`."
  def title(post_content), do: title(post_content, author(post_content))

  def title(post_content, author) do
    e(post_content, :title, nil) ||
      e(post_content, :activity, :replied, :thread, :named, :name, nil) ||
      if(author, do: l("Post by %{author}", author: author))
  end

  @doc "Post summary, or a plain-text truncated excerpt of the body as fallback."
  def description(post_content) do
    case e(post_content, :summary, nil) do
      summary when is_binary(summary) and summary != "" ->
        summary

      _ ->
        case e(post_content, :html_body, nil) do
          body when is_binary(body) and body != "" ->
            body
            |> Text.text_only()
            |> Text.sentence_truncate(@description_length)

          _ ->
            nil
        end
    end
  end
end
