defmodule Bonfire.UI.Social.Activity.NoteLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop activity, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop showing_within, :atom, default: nil
  prop cw, :boolean, default: nil
  prop is_remote, :boolean, default: false
  prop thread_title, :any, default: nil
  prop hide_actions, :boolean, default: false
  prop activity_inception, :boolean, default: false
  prop activity_component_id, :string, default: nil
  prop parent_id, :any, default: nil

  def preloads(),
    do: [
      :post_content,
      :language
    ]

  def post_content(object) do
    e(object, :post_content, nil) || object
  end

  @doc """
  The post's text as an email shows it: plain, and cut at a word before 250 characters, so one long post cannot fill a digest (or at 250 characters, in a language written without spaces). From the summary when there is one, as the feed shows it.

  Behind a content warning (`cw`), only the warning: an email has no button to reveal the rest, so the reader follows the row's link to read it. A post marked sensitive with no warning of its own gets a generic one.

      iex> email_excerpt(%{post_content: %{html_body: "<p>Q&amp;A tonight.</p>"}}, false)
      "Q&A tonight."
  """
  def email_excerpt(object, true = _cw) do
    case plain(e(post_content(object), :summary, nil)) do
      nil -> l("Content warning")
      warning -> l("Content warning: %{warning}", warning: warning)
    end
  end

  def email_excerpt(object, _cw) do
    content = post_content(object)

    (plain(e(content, :summary, nil)) || plain(e(content, :html_body, nil)))
    |> excerpt()
  end

  @doc "The post's title as an email shows it, or nothing behind a content warning, since a title can say what the warning hides."
  def email_title(_object, true), do: nil
  def email_title(object, _cw), do: plain(e(post_content(object), :name, nil))

  # text as written, the way `Bonfire.Social.Activities.describe_parts/1` words a push: `Text.text_only/1` strips the tags but leaves the text HTML-escaped, which a template would escape again
  defp plain(html) do
    case html |> Text.maybe_markdown_to_html() |> Text.text_only() do
      text when is_binary(text) and text != "" -> HtmlEntities.decode(text)
      _ -> nil
    end
  end

  # `sentence_truncate/2` cuts at a space, and gives nothing back when there is none
  defp excerpt(text) do
    case Text.sentence_truncate(text, 250) do
      "" -> Text.truncate(text, 250, "…")
      ^text -> text
      cut -> cut <> " …"
    end
  end
end
