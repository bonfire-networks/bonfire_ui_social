defmodule Bonfire.UI.Social.Activity.MediaCarouselModalLive do
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "List of media items to display in the carousel"
  prop media_list, :list, required: true

  @doc "Parent ID for deterministic DOM IDs"
  prop parent_id, :string, required: true
  prop modal_id, :string, default: nil
  @doc "Whether showing within flags context"
  prop showing_within, :atom, default: nil

  @doc "Content warning flag"
  prop cw, :boolean, default: false

  @doc "The __context__ from parent"
  prop __context__, :map, default: %{}
end
