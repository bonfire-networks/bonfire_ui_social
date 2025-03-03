defmodule Bonfire.UI.Social.Routes do
  @behaviour Bonfire.UI.Common.RoutesModule

  defmacro __using__(_) do
    quote do
      # pages anyone can view
      scope "/", Bonfire.UI.Social do
        pipe_through(:browser)

        live("/feed", FeedsLive, as: :feed)
        live("/feed/local", FeedsLive, :local, as: :feed)

        live("/bookmarks", FeedsLive, :bookmarks, as: :bookmarks)

        live("/discussion/:id", DiscussionLive, as: Needle.Pointer)
        live("/discussion/as/:id", DiscussionLive, as: Bonfire.Data.Social.APActivity)
        live("/discussion/:type/:id", DiscussionLive, as: Needle.Pointer)
        live("/discussion/:id/reply/:reply_to_id", DiscussionLive, as: Needle.Pointer)

        live("/post/:id/history", PostHistoryLive)

        live("/discuss/:id", DiscussionLive, as: Bonfire.Data.Social.PostContent)
      end

      # pages you need to view as a user
      scope "/", Bonfire.UI.Social do
        pipe_through(:browser)
        pipe_through(:user_required)
        live("/feed/:tab", FeedsLive, as: :feed)

        # TODO:
        live("/feed/:tab/:object_types", FeedsLive, as: :feed)
        live("/write", WriteLive, as: :write)
      end

      # pages you need an account to view
      scope "/", Bonfire.UI.Social do
        pipe_through(:browser)
        pipe_through(:account_required)

        live("/notifications", NotificationsFeedLive, as: :notifications)
      end
    end
  end
end
