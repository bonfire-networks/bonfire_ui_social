defmodule Bonfire.UI.Social.Activity.PublishedInLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop context, :any, default: nil
  prop showing_within, :atom, default: nil
  # compact = inline byline-end variant (in SubjectLive); default = standalone top-line
  prop compact, :boolean, default: false

  prop class, :css_class,
    default: [
      "flex items-center justify-start border-b-hair border-secondary pb-2 -mx-card px-card -mt-1.5"
    ]
end
