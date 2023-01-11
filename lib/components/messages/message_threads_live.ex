defmodule Bonfire.UI.Social.MessageThreadsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop threads, :any, default: nil
  prop thread_id, :string, default: nil
  prop tab_id, :string, default: nil
  prop context, :any, default: nil
  prop showing_within, :string, default: nil

  def permalink(thread, object) do
    thread_url =
      if thread do
        "/messages/#{ulid(thread)}"
      end

    if thread_url && ulid(thread) != ulid(object) do
      "#{thread_url}#comment-#{ulid(object)}"
    else
      "/messages/#{ulid(object)}"
    end
  end
end
