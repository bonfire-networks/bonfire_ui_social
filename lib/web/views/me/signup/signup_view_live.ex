defmodule Bonfire.UI.Social.SignupViewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any
  prop error, :any
  prop registered, :boolean

end
