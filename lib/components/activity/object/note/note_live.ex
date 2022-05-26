defmodule Bonfire.UI.Social.Activity.NoteLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.Text
  
  prop object, :any
  prop activity, :any
  prop viewing_main_object, :boolean
  prop permalink, :string
  prop date_ago, :string
  prop showing_within, :any
  prop activity_inception, :any

  def post_content(object) do
    e(object, :post_content, object)
    # |> debug("activity_note_object")
  end
end
