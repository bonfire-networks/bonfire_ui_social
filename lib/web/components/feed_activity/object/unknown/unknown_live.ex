defmodule Bonfire.UI.Social.Activity.UnknownLive do
  use Bonfire.Web, :live_component
  import Bonfire.UI.Social.Integration

  def update(%{object: nil} = assigns, socket) do
    {:ok, socket |>
      assigns_merge(assigns,
        object: %{name: l "[Deleted]"}
      )}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

end
