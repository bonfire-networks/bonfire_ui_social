defmodule Bonfire.UI.Social.MessageThreadsLive do
  use Bonfire.Web, :stateless_component

  prop feed, :list
  prop tab_id, :string
  prop to_circles, :list

  def permalink(thread, object) do
    thread_url = if thread do
      "/messages/#{ulid(thread)}"
    end

    if thread_url && ulid(thread) != ulid(object) do
      "#{thread_url}##{ulid(object)}"
    else
      "/messages/#{ulid(object)}"
    end
  end
end
