defmodule Bonfire.UI.Social.PageHeaderLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch

  # # prop current_user, :any, required: true # WIP Passing a boolean rather than the whole user object
  # prop name, :string, required: true
  # prop user_image, :string, required: true
  # prop username, :string, required: true
  prop page_title, :string, required: true
  prop page, :string, required: true
  prop smart_input, :boolean, required: true
  prop create_activity_type, :any, required: false


end
