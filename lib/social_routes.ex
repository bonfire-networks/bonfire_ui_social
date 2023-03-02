defmodule Bonfire.UI.Social.Routes do
  def declare_routes, do: nil

  defmacro __using__(_) do
    quote do
      # pages anyone can view
      scope "/", Bonfire.UI.Social do
        pipe_through(:browser)

        # live("/local", Feeds.LocalLive, as: :local)
        # live("/federation", Feeds.FederationLive, as: :federation)
        # live("/federation/:type", Feeds.FederationLive, as: :federation)

        # WIP: TEMP ROUTES to be moved to Bonfire.UI.Topics and Bonfire.UI.Groups
        live("/topic", TopicLive)
        live("/group", GroupLive)
        live("/group/:tab", GroupLive)
        live("/group/:tab/:tab_id", GroupLive)


        live("/feed", FeedsLive, as: :feed)
        live("/feed/:tab", FeedsLive, as: :feed)
        # TODO:
        live("/feed/:tab/:object_type", FeedsLive, as: :feed)

        live("/write", WriteLive, as: :write)

        # live "/post", PostLive, as: Bonfire.Data.Social.Post
        live("/post/:id", PostLive, as: Bonfire.Data.Social.Post)
        live("/discussion/:id", DiscussionLive, as: Pointers.Pointer)
        live("/discussion/:type/:id", DiscussionLive, as: Pointers.Pointer)
        live("/discussion/:id/reply/:reply_to_id", DiscussionLive, as: Pointers.Pointer)
      end

      # pages you need to view as a user
      scope "/", Bonfire.UI.Social do
        pipe_through(:browser)
        pipe_through(:user_required)

        # live("/feed/likes/", Feeds.LikesLive, as: Bonfire.Data.Social.Like)
        live("/messages/:id", MessagesLive, as: Bonfire.Data.Social.Message)
        live("/messages/:id/reply/:reply_to_id", MessagesLive, as: Bonfire.Data.Social.Message)
        live("/messages/@:username", MessagesLive, as: Bonfire.Data.Social.Message)
        live("/messages", MessagesLive, as: Bonfire.Data.Social.Message)
      end

      # pages you need an account to view
      scope "/", Bonfire.UI.Social do
        pipe_through(:browser)
        pipe_through(:account_required)

        live("/notifications", Feeds.NotificationsLive, as: :notifications)
        # live "/flags", FlagsLive, as: :flags
      end
    end
  end
end
