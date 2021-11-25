defmodule Bonfire.UI.Social.NavLive do
  use Bonfire.Web, :stateless_component
  alias Bonfire.Me.Fake

  prop page, :any
  prop inner_content, :any
end
