defmodule Bonfire.UI.Social.Activity.DownloadMarkdownLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :string, required: true
  prop include_frontmatter, :boolean, default: false
  prop include_replies, :boolean, default: false
  prop as_icon, :boolean, default: false

  # prop download_url, :any, default: nil

  # @impl true
  # def handle_event("update_download_options", params, socket) do
  #   # Handles checked/unchecked checkboxes 
  #   include_frontmatter = Map.get(params, "frontmatter") == "true"
  #   include_replies = Map.get(params, "replies") == "true"
  #   object_id = socket.assigns.object_id

  #   {:noreply,
  #     socket
  #     |> assign(
  #       [include_frontmatter: include_frontmatter,
  #     include_replies: include_replies,
  #   download_url: download_url(object_id, include_frontmatter, include_replies)
  #   ] 
  #     |> debug("opts")
  #     )
  #   }
  # end

  # defp download_url(object_id, include_frontmatter, include_replies) do
  #   "/post/markdown/#{object_id}?frontmatter=#{to_string(include_frontmatter)}&replies=#{to_string(include_replies)}"
  # end
end
