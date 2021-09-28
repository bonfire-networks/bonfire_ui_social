defmodule Bonfire.UI.Social.CreateActivityLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.Common.Utils
  alias Surface.Components.Form.TextArea
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Inputs

  # prop target_component, :string
  prop smart_input_private, :boolean, default: nil
  prop create_activity_type, :string, default: "post"
  prop reply_to_id, :string, default: ""
  prop reply_to_thread_id, :string, default: ""
  prop smart_input_placeholder, :string, required: false
  prop smart_input_text, :string, default: "", required: false

  def update(assigns, socket) do

    create_activity_type = if e(assigns, :smart_input_private, nil), do: "message",
    else: e(assigns, :create_activity_type, "post")

    {:ok, socket
    |> assigns_merge(
      assigns,
      changeset: Bonfire.Social.Posts.LiveHandler.post_changeset(%{}),
      smart_input_placeholder: e(assigns, :smart_input_placeholder, "Write something..."),
      smart_input_text: e(assigns, :smart_input_text, ""),
      create_activity_type: create_activity_type,
      activity_type_or_reply: activity_type_or_reply(assigns, create_activity_type)
    )}
  end

  def activity_type_or_reply(assigns, create_activity_type) do
    if e(assigns, :reply_to_id, "") !="" or e(assigns, :reply_to_thread_id, "") !="", do: "reply", else: create_activity_type
  end
end
