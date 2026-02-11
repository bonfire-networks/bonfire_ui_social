defmodule Bonfire.UI.Social.Activity.QuoteRequestFooterLive do
  @doc "Renders Accept/Decline action buttons for a quote request notification."
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :any, default: nil
end
