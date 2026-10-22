defmodule Bonfire.UI.Social.WidgetTrendingDomIdsTest do
  @moduledoc "The dashboard shows a post in its \"Top discussions\" widget and in the feed beside it at once, so the two cards must not share DOM ids (the browser warns, and LiveView patches whichever it finds first)."
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  doctest Bonfire.UI.Social.WidgetTrendingDiscussionsLive, only: [card_id: 1]

  test "a trending post that is also in the dashboard feed doesn't repeat DOM ids" do
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)

    account = fake_account!()
    me = fake_user!(account)

    post =
      Bonfire.Posts.Fake.fake_post!(me, "public", %{
        post_content: %{html_body: "trending and in my feed"}
      })

    # the dashboard's feed is off unless the user turns it on
    Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :include, :feed], true,
      current_user: me
    )

    {:ok, view, _html} = live(conn(user: me, account: account), "/dashboard")
    html = render_async(view)

    doc = Floki.parse_document!(html)

    assert [_ | _] =
             Floki.find(doc, "[data-id=trending_discussions] [data-object_id='#{id(post)}']"),
           "control: in the widget"

    assert length(Floki.find(doc, "article[data-object_id='#{id(post)}']")) > 1,
           "control: in the feed as well"

    duplicates =
      doc
      |> Floki.attribute("[id]", "id")
      |> Enum.frequencies()
      |> Enum.filter(fn {_id, count} -> count > 1 end)

    assert duplicates == []
  end
end
