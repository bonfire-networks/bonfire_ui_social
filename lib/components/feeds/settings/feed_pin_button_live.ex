defmodule Bonfire.UI.Social.FeedPinButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, required: true
  prop feed_name, :any, required: true
  prop pinned, :boolean, required: true
  prop class, :css_class, default: "btn-sm"
  prop icon_class, :css_class, default: "size-4"

  @doc "Renders the shared feed-tab pin action and its accessible state."
  def render(assigns) do
    assigns
    |> assign(label: if(assigns.pinned, do: l("Unpin from feed tabs"), else: l("Pin to feed tabs")))
    |> render_sface()
  end
end
