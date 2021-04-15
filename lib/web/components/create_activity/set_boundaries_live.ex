defmodule Bonfire.UI.Social.SetBoundariesLive do
  use Bonfire.Web, :live_component

  def mount(socket) do
    {:ok, assign(socket,
      to_circles: [
        Bonfire.Boundaries.Circles.get_tuple(:guest),
        Bonfire.Boundaries.Circles.get_tuple(:local),
        Bonfire.Boundaries.Circles.get_tuple(:admin),
        Bonfire.Boundaries.Circles.get_tuple(:activity_pub)
      ]
    )}
  end


end
