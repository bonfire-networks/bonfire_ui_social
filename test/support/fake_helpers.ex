defmodule Bonfire.UI.Social.Test.FakeHelpers do

  def post_attrs(n), do: %{post_content: %{summary: "summary", name: "post ##{n}", html_body: "<p>epic html message</p>"}}

  def post_attrs(n, attrs), do: Map.merge(attrs, %{post_content: %{name: "post ##{n}", html_body: "<p>epic html message</p>"}})


  def publish_multiple_times(msg, user, n, preset \\ "public")
  def publish_multiple_times(msg, user, n, preset) when n > 0 do
    {:ok, _post} = Bonfire.Social.Posts.publish(current_user: user, post_attrs: msg, boundary: preset)
    publish_multiple_times(msg, user, n-1)
  end

  def publish_multiple_times(_msg, _user, 0, _preset) do
    :ok
  end

end
