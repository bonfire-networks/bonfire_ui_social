defmodule Bonfire.UI.Social.Activity.BoostedPostMetadataTest do
  @moduledoc """
  Regression tests: metadata of a boost/like activity must not leak into the original post's byline — the date (incl. `data-date`/`title`) must be the post's, and the remote-instance favicon must reflect the post's origin, not the booster's/liker's.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Posts
  alias Bonfire.Common.DatesTimes

  import Tesla.Mock

  setup do
    mock_global(fn env -> ActivityPub.Test.HttpRequestMock.request(env) end)
    :ok
  end

  defp subject_bylines(html) do
    # only the creator byline renders a username, excluding the minimal "X boosted" line
    Floki.parse_document!(html)
    |> Floki.find("[data-role=subject]")
    |> Enum.filter(&(Floki.find(&1, "[data-id=subject_username]") != []))
  end

  defp byline_dates(html) do
    subject_bylines(html)
    |> Floki.find("[data-date]")
    |> Floki.attribute("data-date")
    |> Enum.map(fn iso ->
      {:ok, date_time, _} = DateTime.from_iso8601(iso)
      date_time
    end)
  end

  describe "boosting a post" do
    test "the original post's byline shows the post's date, not the boost's" do
      me = fake_user!("mee")
      booster = fake_user!("boostee")

      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "the original post"}},
          boundary: "public"
        )

      {:ok, boost} = Boosts.boost(booster, post)

      post_date = DatesTimes.to_date_time(post.id)
      boost_date = DatesTimes.to_date_time(id(boost))

      assert DateTime.compare(post_date, boost_date) != :eq,
             "expected the post and the boost to have distinct timestamps, otherwise this test can't tell them apart"

      # the booster's profile feed contains just their boost of my post
      {:ok, _view, html} = live(conn(user: me), "/@boostee")

      assert [byline_date] = byline_dates(html)

      assert DateTime.compare(byline_date, post_date) == :eq,
             "expected the byline to show the post's date (#{post_date}), got #{byline_date}#{if DateTime.compare(byline_date, boost_date) == :eq, do: " (the boost's date)"}"
    end

    test "the original post's byline shows no remote instance icon when the post is local" do
      me = fake_user!("mee2")
      booster = Bonfire.Social.Fake.fake_remote_user!()

      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "my local post"}},
          boundary: "public"
        )

      {:ok, _boost} = Boosts.boost(booster, post)

      {:ok, _view, html} = live(conn(user: me), "/user/#{id(booster)}")

      bylines = subject_bylines(html)
      assert bylines != [], "expected the boosted post's byline to be rendered"

      assert Floki.find(bylines, "[data-id=peered]") == [],
             "expected no remote instance icon on the byline of a local post, the boost being remote is not the post's origin"
    end
  end

  describe "RSS/Atom FeedView locality" do
    defp peer, do: %Bonfire.Data.ActivityPub.Peered{id: "01ARZ3NDEKTSV4RRFFQ69G5FAV"}
    defp local_char(id), do: %{id: id, character: %{id: id, peered: nil}}
    defp remote_char(id), do: %{id: id, character: %{id: id, peered: peer()}}

    test "a remote actor's boost of a local post is not remote" do
      activity = %{
        id: "01BOOST0000000000000000000",
        subject: remote_char("01BOOSTER00000000000000000"),
        object: %{
          id: "01POST00000000000000000000",
          peered: nil,
          created: %{
            creator_id: "01CREATOR00000000000000000",
            creator: local_char("01CREATOR00000000000000000")
          }
        }
      }

      refute Bonfire.UI.Social.FeedView.prepare_activity(activity).is_remote
    end

    test "a local actor's boost of a remote post is remote" do
      activity = %{
        id: "01BOOST0000000000000000000",
        subject: local_char("01BOOSTER00000000000000000"),
        object: %{
          id: "01POST00000000000000000000",
          peered: nil,
          created: %{
            creator_id: "01CREATOR00000000000000000",
            creator: remote_char("01CREATOR00000000000000000")
          }
        }
      }

      assert Bonfire.UI.Social.FeedView.prepare_activity(activity).is_remote
    end

    test "an authored post still classifies by its subject" do
      activity = %{
        id: "01POST00000000000000000000",
        subject: remote_char("01CREATOR00000000000000000"),
        object: %{
          id: "01POST00000000000000000000",
          peered: nil,
          created: %{
            creator_id: "01CREATOR00000000000000000",
            creator: remote_char("01CREATOR00000000000000000")
          }
        }
      }

      assert Bonfire.UI.Social.FeedView.prepare_activity(activity).is_remote
    end
  end

  describe "liking a post" do
    test "the original post's byline shows the post's date, not the like's" do
      me = fake_user!("mee3")
      liker = fake_user!("likee")

      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "the original post"}},
          boundary: "public"
        )

      {:ok, like} = Likes.like(liker, post)

      post_date = DatesTimes.to_date_time(post.id)
      like_date = DatesTimes.to_date_time(id(like))

      assert DateTime.compare(post_date, like_date) != :eq

      # my notifications contain just the like of my post
      {:ok, _view, html} = live(conn(user: me), "/notifications")

      assert [byline_date] = byline_dates(html)

      assert DateTime.compare(byline_date, post_date) == :eq,
             "expected the byline to show the post's date (#{post_date}), got #{byline_date}#{if DateTime.compare(byline_date, like_date) == :eq, do: " (the like's date)"}"
    end
  end
end
