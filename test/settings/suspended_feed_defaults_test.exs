defmodule Bonfire.UI.Social.SuspendedFeedDefaultsTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Social.FeedLoader

  test "suspended controls are absent while other feed settings remain" do
    account = fake_account!()
    user = fake_user!(account)

    conn(user: user, account: account)
    |> visit("/settings/user/feeds")
    |> refute_has("#default-sort-form")
    |> refute_has("#feed-pagination-form")
    |> assert_has("#default-feed-form")
    |> assert_has("#feed-infinite-scroll-form")
  end

  test "saved defaults are ignored while explicit sorting and pagination remain available" do
    user = fake_user!()

    user = %{
      user
      | settings: %Bonfire.Data.Identity.Settings{
          json: %{
            bonfire: %{default_pagination_limit: 3},
            bonfire_ui_social: %{Bonfire.UI.Social.FeedLive => %{sort_by: :like_count}}
          }
        }
    }

    assert Bonfire.Common.Settings.__get__([:default_pagination_limit], nil, current_user: user) ==
             3

    assert Bonfire.Common.Settings.__get__([Bonfire.UI.Social.FeedLive, :sort_by], nil,
             current_user: user
           ) == :like_count

    assert {:ok, filters} =
             FeedLoader.prepare_feed_filters(nil, %{feed_name: nil}, current_user: user)

    refute filters.sort_by == :like_count

    assert {:ok, filters} =
             FeedLoader.prepare_feed_filters(nil, %{feed_name: nil, sort_by: :boost_count},
               current_user: user
             )

    assert filters.sort_by == :boost_count

    assert Bonfire.Common.Repo.pagination_opts(current_user: user)[:limit] ==
             Bonfire.Common.Repo.pagination_opts([])[:limit]

    assert Bonfire.Common.Repo.pagination_opts(current_user: user, limit: 4)[:limit] == 4
  end
end
