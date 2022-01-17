defmodule Bonfire.UI.Social.ProfileHeroFullLive do
  use Bonfire.Web, :stateless_component

  prop user, :map

  def display_url("https://"<>url), do: url
  def display_url("http://"<>url), do: url
  def display_url(url), do: url

end
