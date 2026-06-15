defmodule Bonfire.UI.Social.EventCategoryIconLive do
  @moduledoc """
  Icon + accent hue per FEP-8a8e event category.

  Each branch must use a **literal** `<#Icon iconify="...">` and a literal
  `text-*` class: iconify_ex only generates icons it scans (a dynamic
  `iconify={name}` → blank square), and the colour classes are only kept by
  Tailwind because they appear here literally. `colored={false}` inherits the
  surrounding text colour (e.g. inside a coloured badge).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop category, :string, default: nil
  prop class, :css_class, default: "w-5 h-5"
  prop colored, :boolean, default: true
end
