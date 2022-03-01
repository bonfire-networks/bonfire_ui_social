defmodule Bonfire.UI.Social.Activity.DateAgoLive do
  use Bonfire.Web, :stateless_component

  alias Bonfire.UI.Social.BoundaryIconLive

  prop object, :any
  prop verb_display, :string
  prop date_ago, :any
  prop viewing_main_object, :boolean
  prop permalink, :string
  prop showing_within, :string, default: :feed
  
  def permalink(%{object: %{peered: %{canonical_uri: permalink}}} = _assigns) when is_binary(permalink) do
    permalink
  end

  def permalink(%{permalink: permalink} = _assigns) do
    permalink
  end

end
