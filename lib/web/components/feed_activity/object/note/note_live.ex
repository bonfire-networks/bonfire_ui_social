defmodule Bonfire.UI.Social.Activity.NoteLive do
  use Bonfire.Web, :stateless_component


  prop object, :any
  prop activity, :any
  prop viewing_main_object, :boolean
  prop permalink, :string
  prop date_ago, :string
  prop showing_within, :any


  def post_content(object) do
    # IO.inspect(object)
    # IO.inspect(e(object, :post_content, object))
    e(object, :post_content, object)
    #|> IO.inspect
  end
end
