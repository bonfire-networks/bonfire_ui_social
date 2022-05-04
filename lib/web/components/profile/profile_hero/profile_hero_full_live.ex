defmodule Bonfire.UI.Social.ProfileHeroFullLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.UI.Social.Integration

  prop user, :map

  def display_url("https://"<>url), do: url
  def display_url("http://"<>url), do: url
  def display_url(url), do: url

end
