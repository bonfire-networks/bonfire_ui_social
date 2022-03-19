defmodule Bonfire.UI.Social.CreateActivityLive do
  use Bonfire.Web, :stateful_component
  use Bonfire.Common.Utils
  alias Surface.Components.Form.TextArea
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Inputs

  # prop target_component, :string
  prop reply_to_id, :string
  prop thread_id, :string
  prop create_activity_type, :any
  prop to_circles, :list
  prop smart_input_prompt, :string, default: ""
  prop smart_input_text, :string, default: "", required: false
  prop showing_within, :any
  prop with_editor, :boolean, required: false
  prop textarea_class, :string, default: "textarea prose prose-sm"
  prop activity, :list
  prop object, :list

  def update(%{activity: activity, object: object} = assigns, socket) do
    socket = assign(socket, activity: activity)
    {:ok, socket
    |> assign(assigns)
    }
    # {:ok, assign(socket, activity_id: activity_id)}
  end

  def update(%{activity: activity, object: object} = assigns, socket) do
    socket = assign(socket, activity: activity)
    {:ok, socket
    |> assign(assigns)
    }
    # {:ok, assign(socket, activity_id: activity_id)}
  end
    
  def update(assigns, socket) do
   {:ok, socket |> assign(assigns)}
  end

  def with_editor?(assigns) do
    case e(assigns, :with_editor, nil) do
      nil -> e(assigns, :showing_within, nil) != :thread && module_enabled?(Bonfire.Editor.Ck.Bubble)
      overide -> overide
    end
  end

  def activity_type_or_reply(assigns, create_activity_type) do
    debug(e(assigns, :reply_to_id, ""), "reply to id")
    debug(e(assigns, :thread_id, ""), "thread_id")
    if e(assigns, :reply_to_id, "") !="" or e(assigns, :thread_id, "") !="",
    do: "reply",
    else: "#{create_activity_type}"
  end
end
