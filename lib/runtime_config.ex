defmodule Bonfire.UI.Social.RuntimeConfig do
  use Bonfire.Common.Localise

  @behaviour Bonfire.Common.ConfigModule
  def config_module, do: true

  @doc """
  NOTE: you can override this default config in your app's `runtime.exs`, by placing similarly-named config keys below the `Bonfire.Common.Config.LoadExtensionsConfig.load_configs()` line
  """
  def config do
    import Config

    # config :bonfire_ui_social,
    #   modularity: :disabled

    config :bonfire, :ui,
      explore: [
        sections: [
          hashtags: Bonfire.UI.Social.FeedsLive,
          users: Bonfire.UI.Social.FeedsLive,
          posts: Bonfire.UI.Social.FeedsLive,
          groups: Bonfire.UI.Social.FeedsLive
        ],
        navigation: [
          hashtags: l("Hashtags"),
          users: l("Users"),
          posts: l("Posts"),
          groups: l("Groups")
        ]
      ],
      profile: [
        # TODO: make dynamic based on active extensions
        sections: [
          nil: Bonfire.UI.Social.ProfileTimelineLive,
          # private: Bonfire.UI.Social.MessageThreadsLive,
          posts: Bonfire.UI.Social.ProfilePostsLive,
          boosts: Bonfire.UI.Social.ProfileBoostsLive,
          highlights: Bonfire.UI.Social.ProfilePinsLive,
          followers: Bonfire.UI.Social.ProfileFollowsLive,
          followed: Bonfire.UI.Social.ProfileFollowsLive,
          requested: Bonfire.UI.Social.ProfileFollowsLive,
          requests: Bonfire.UI.Social.ProfileFollowsLive
        ],
        navigation: [
          # highlights: l("Highlights"),
          nil: l("Timeline"),
          posts: l("Posts"),
          boosts: l("Boosts")
        ],
        network: [
          followers: l("Followers"),
          followed: l("Followed")
        ],
        my_network: [
          followers: l("Followers"),
          # requests: "Follower requests",
          followed: l("Followed")
          # requested: "Pending"
        ],
        widgets: []
      ]
  end
end
