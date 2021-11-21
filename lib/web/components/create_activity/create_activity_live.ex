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
  prop create_activity_type, :string, default: nil
  prop reply_to_id, :string
  prop reply_to_thread_id, :string
  prop smart_input_placeholder, :string, required: false
  prop smart_input_text, :string, default: "", required: false

  def update(assigns, socket) do

    create_activity_type = e(assigns, :create_activity_type, "post")

    {:ok,  assign(socket, assigns
    |> assigns_merge(
        changeset: Bonfire.Social.Posts.LiveHandler.post_changeset(%{}),
        smart_input_placeholder: e(assigns, :smart_input_placeholder, "Write something..."),
        smart_input_text: e(assigns, :smart_input_text, ""),
        textarea_class: "block w-full h-full h-40 text-sm transition-all duration-300 ease-in-out rounded-none rounded-t resize-none textarea textarea-bordered bg-base-100"
    ))
    |> assign_global(
          create_activity_type: create_activity_type,
          activity_type_or_reply: activity_type_or_reply(assigns, create_activity_type)
      )
  }
  end

  def activity_type_or_reply(assigns, create_activity_type) do
    IO.inspect(e(assigns, :reply_to_id, ""), label: "reply to id")
    IO.inspect(e(assigns, :reply_to_thread_id, ""), label: "reply_to_thread_id")
    if e(assigns, :reply_to_id, "") !="" or e(assigns, :reply_to_thread_id, "") !="",
    do: "reply",
    else: create_activity_type
  end
end
