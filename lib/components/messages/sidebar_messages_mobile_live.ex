defmodule Bonfire.UI.Social.SidebarMessagesMobileLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop threads, :any
  prop context, :any, default: nil
  prop thread_id, :string

  def permalink(thread, object) do
    thread_url =
      if thread do
        "/messages/#{ulid(thread)}"
      end

    if thread_url && ulid(thread) != ulid(object) do
      "#{thread_url}##{ulid(object)}"
    else
      "/messages/#{ulid(object)}"
    end
  end
end
