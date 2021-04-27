defmodule Bonfire.UI.Social.CreateActivityLive do
  use Surface.Component
  import Bonfire.Common.Utils
  alias Surface.Components.Form.TextArea
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Inputs

  prop target_component, :string
  prop smart_input_private, :boolean, default: nil
  prop create_activity_type, :string, default: nil
  prop reply_to_id, :string, default: ""
  prop reply_to_thread_id, :string
  prop smart_input_placeholder, :string
  prop smart_input_text, :string

  def update(assigns, socket) do
    {:ok, socket
    |> assigns_merge(
      assigns,
      changeset: Bonfire.Social.Web.LiveHandlers.Posts.post_changeset(%{})
    )}
  end
end
