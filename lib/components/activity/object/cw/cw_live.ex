defmodule Bonfire.UI.Social.Activity.CWLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop summary, :string, default: nil
  prop cw, :boolean, default: nil
  prop activity_component_id, :string, default: nil

  prop class, :css_class,
    default:
      "flex w-full flex-1 items-start my-2 gap-2 p-2 bg-base-content/5 border border-dashed border-base-content/20 rounded-box"
end
