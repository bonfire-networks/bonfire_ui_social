defmodule Bonfire.UI.Social.ForgotPasswordViewLive do
  use Bonfire.Web, :stateless_component

  prop form, :any
  prop error, :any
  prop requested, :any
end
