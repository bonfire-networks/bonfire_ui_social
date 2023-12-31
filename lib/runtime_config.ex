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
          groups: Bonfire.UI.Social.FeedsLive
        ],
        navigation: [
          hashtags: l("Hashtags"),
          users: l("Users"),
          groups: l("Groups")
        ]
      ],
      profile: [
        # TODO: make dynamic based on active extensions
        sections: [
          nil: Bonfire.UI.Social.ProfileTimelineLive
          # private: Bonfire.UI.Messages.MessageThreadsLive,
        ],
        navigation: [
          # highlights: l("Highlights"),
          nil: l("Timeline")
        ],
        widgets: []
      ]
  end
end
