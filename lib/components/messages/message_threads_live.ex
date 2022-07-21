defmodule Bonfire.UI.Social.MessageThreadsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop threads, :any
  prop thread_id, :string
  prop tab_id, :string
  prop context, :any, default: nil
  prop showing_within, string, default, nil
  # prop to_boundaries, :list
  # prop to_circles, :list
  prop users, :list

  def permalink(thread, object) do
    thread_url = if thread do
      "/messages/#{ulid(thread)}"
    end

    if thread_url && ulid(thread) != ulid(object) do
      "#{thread_url}#comment-#{ulid(object)}"
    else
      "/messages/#{ulid(object)}"
    end
  end
end
