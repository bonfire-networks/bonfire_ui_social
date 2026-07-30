defmodule Bonfire.UI.Social.MarkdownController do
  @moduledoc "Serves any readable object (`Post`, `Bonfire.Articles.Article`, …) as a downloadable markdown file. The serialisation itself lives in `Bonfire.Social.Objects.Render`."
  use Bonfire.UI.Common.Web, :controller

  alias Bonfire.Social.Objects

  def download_markdown(conn, %{"id" => id} = params) do
    with_frontmatter = params["frontmatter"] == "true"

    # NOTE: a type-agnostic read (rather than `Bonfire.Posts.read/2`, which only queries the `Post`
    # schema) so this works for any object with a post content, e.g. an Article
    case Objects.read(id,
           current_user: current_user(conn),
           preload: [:with_post_content, :with_media, :with_creator]
         ) do
      {:ok, object} ->
        markdown_content =
          object
          |> preload_for_render(with_frontmatter)
          |> Objects.Render.to_markdown(
            with_frontmatter: with_frontmatter,
            with_replies: params["replies"] == "true"
          )

        conn
        |> put_resp_content_type("text/markdown")
        |> put_resp_header("content-disposition", ~s[attachment; filename="#{id}.md"])
        |> send_resp(200, markdown_content)

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("text/markdown")
        |> send_resp(404, "Not found")

      error ->
        error(error, "Could not load the object to render as markdown")

        conn
        |> put_resp_content_type("text/markdown")
        |> send_resp(500, "Unable to generate markdown")
    end
  end

  # Load exactly what the serialiser reads, on the object itself: `Objects.read/2`'s activity
  # preloads don't survive onto the merged object (`maybe_preload_nested_pointers/3` re-follows
  # `activity.object` via `Needles.get/2`, dropping the query-side mixin preloads, before
  # `activity_under_object/1` merges it in), and the frontmatter's `URIs.canonical_url/1` refuses
  # to lazy-load `:peered` — it must be preloaded at the source.
  defp preload_for_render(object, with_frontmatter) do
    Bonfire.Common.Repo.Preload.maybe_preload(
      object,
      [:post_content] ++
        if(with_frontmatter,
          do: [:peered, created: [creator: [:character, :profile]]],
          else: []
        )
    )
  end
end
