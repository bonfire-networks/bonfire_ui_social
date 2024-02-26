defmodule Bonfire.UI.Social.Activity.ActionsLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.Social.Feeds.LiveHandler

  prop activity, :any, default: nil
  prop object, :any, required: true
  # prop profile, :any, default: nil
  prop thread_id, :string, required: true
  prop object_type, :any, required: true
  prop object_type_readable, :any, required: true
  prop verb, :string, required: true
  prop reply_count, :any, default: nil
  prop permalink, :string, required: true
  prop activity_component_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop showing_within, :atom, default: nil
  prop feed_name, :any, default: nil
  prop hide_reply, :boolean, default: false
  prop viewing_main_object, :boolean, default: false
  prop flagged, :any, default: nil
  prop thread_mode, :any, default: nil
  prop object_boundary, :any, default: nil
  prop is_remote, :boolean, default: false
  prop hide_more_actions, :boolean, default: false
  prop parent_id, :any, default: nil
  prop published_in, :any, default: nil
  prop labelled, :any, default: nil
  prop hide_actions, :any, default: false

  prop my_boost, :any, default: nil
  prop my_like, :any, default: nil
  prop my_bookmark, :any, default: nil

  def update_many(assigns_sockets) do
    assigns_sockets
    |> LiveHandler.actions_update_many(caller_module: __MODULE__)
    |> debug("lllll")
    |> Enum.map(fn
      {assigns, socket} ->
        assign(socket, assigns)

      socket ->
        socket
    end)

    # |> debug("kkkk")
  end

  def count(replied) do
    # debug(replied)
    e(replied, :nested_replies_count, 0) + e(replied, :direct_replies_count, 0)
  end

  def the_activity(activity, object) do
    activity || e(object, :activity, nil) || object
  end
end
