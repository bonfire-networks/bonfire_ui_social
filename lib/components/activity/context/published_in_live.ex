defmodule Bonfire.UI.Social.Activity.PublishedInLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop context, :any, default: nil
  prop showing_within, :atom, default: nil
  prop class, :css_class, default: ["flex items-center -ml-8 justify-start -ml-[30px]"]
end
