defmodule Bonfire.UI.Social.ForgotPasswordViewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any
  prop error, :any
  prop requested, :any
end
