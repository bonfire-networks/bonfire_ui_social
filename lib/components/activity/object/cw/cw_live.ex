defmodule Bonfire.UI.Social.Activity.CWLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop summary, :string, default: nil
  prop cw, :boolean, default: nil
  prop activity_component_id, :string, default: nil

  prop class, :css_class,
    default:
      "flex w-full flex-1 items-start mb-2 gap-2 p-1 pl-3 border-hair border-secondary rounded-full"
end
