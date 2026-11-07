defmodule Bonfire.UI.Social.Test.FakeHelpers do
  def post_attrs(n),
    do: %{
      post_content: %{
        summary: "summary",
        name: "post ##{n}",
        html_body: "<p>epic html message</p>"
      }
    }

  def post_attrs(n, attrs),
    do:
      Map.merge(attrs, %{
        post_content: %{name: "post ##{n}", html_body: "<p>epic html message</p>"}
      })

  def publish_multiple_times(msg, user, n, preset \\ "public")

  def publish_multiple_times(msg, user, n, preset) when n > 0 do
    {:ok, _post} = Bonfire.Posts.publish(current_user: user, post_attrs: msg, boundary: preset)

    publish_multiple_times(msg, user, n - 1, preset)
  end

  def publish_multiple_times(_msg, _user, 0, _preset) do
    :ok
  end

  @doc "Forgets the \"Top discussions\" widget's lists, now and when the test ends. They're cached once for everyone signed in and once for guests, not per user, so one test's list would otherwise be read by the next. `user` is any signed-in user, which picks the signed-in list."
  def reset_trending_discussions_cache(user, limit \\ 5) do
    reset = fn ->
      for viewer <- [user, nil],
          do: Bonfire.Social.Threads.list_trending(viewer, limit, cache: :reset)
    end

    reset.()
    ExUnit.Callbacks.on_exit(reset)
  end
end
