defmodule Bonfire.UI.Social.Activity.AcademicPaperLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil
end
