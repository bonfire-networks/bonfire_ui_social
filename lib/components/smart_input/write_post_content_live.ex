defmodule Bonfire.UI.Social.WritePostContentLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils
  alias Bonfire.UI.Common.WriteEditorLive

  @behaviour Bonfire.UI.Common.SmartInputModule
  def smart_input_module,
    do: [
      :post,
      Bonfire.Data.Social.Post,
      Bonfire.Data.Social.PostContent,
      Bonfire.Data.Social.Message
    ]

  def smart_input_icon(:message), do: "ph:chat-circle-text-duotone"
  def smart_input_icon(:broadcast), do: "ph:megaphone-duotone"
  def smart_input_icon(_), do: "ph:note-pencil-duotone"

  def smart_input_label(:message), do: l("Message")
  def smart_input_label(:broadcast), do: l("Broadcast")
  def smart_input_label(_), do: l("Note")

  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil
  # prop create_object_type, :any, default: nil
  prop to_boundaries, :any, default: nil
  prop boundary_preset, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop verb_permissions, :map, default: %{}
  prop mentions, :list, default: []
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: nil
  prop insert_text, :string, default: nil
  prop preloaded_recipients, :any, default: nil
  prop uploads, :any, default: nil
  prop uploaded_files, :list, default: nil
  prop title_prompt, :string, default: nil
  prop selected_cover, :any, default: nil

  prop open_boundaries, :boolean, default: false
  prop boundaries_modal_id, :string, default: :sidebar_composer
  prop reset_smart_input, :boolean, default: false

  prop preview_boundary_for_id, :any, default: nil
  prop preview_boundary_for_username, :any, default: nil
  prop preview_boundary_verbs, :list, default: []

  prop custom_emojis, :any, default: []
  prop quoted_url, :string, default: nil
  # Classes to customize the smart input appearance
  prop textarea_container_class, :css_class
  prop textarea_container_class_alpine, :string
  prop textarea_class, :css_class
  prop replied_activity_class, :css_class
  prop event_target, :any, default: nil

  def handler(create_object_type) do
    cond do
      # TODO: config or behavior driven mapping
      create_object_type in ["message", :message] -> "Bonfire.Messages:send"
      create_object_type in ["broadcast", :broadcast] -> "Bonfire.Notify:broadcast"
      true -> "Bonfire.Posts:post"
    end
  end
end
