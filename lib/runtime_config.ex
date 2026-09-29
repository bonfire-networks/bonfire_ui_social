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

    config :bonfire_ui_social, Bonfire.UI.Social.ThreadLive, thread_mode: :nested

    config :bonfire_ui_social, Bonfire.UI.Social.NotificationPreferencesLive,
      # Per-user display switches for the notifications feed, ordered. Each names what it controls: a `filter` key goes into the feed's filters, an `assign` key into the feed's assigns, and `:chips` is this UI's own chip bar. Defaults mirror the `:notifications` preset, so a user who changes nothing sees what the preset intends
      extra_toggles: [
        highlight: %{
          name: l("Highlight unread notifications"),
          assign: :enable_marker,
          default: false
        },
        chips: %{name: l("Show category filters"), controls: :chips, default: true},
        group: %{
          name: l("Group similar notifications"),
          filter: :show_objects_only_once,
          default: false
        },
        # not about the feed: whether what you write enables notifications of the replies below it, read when a post is written (`Bonfire.Notify.Bells.enable_thread_notifications_changeset/3`), so it controls nothing here and never asks to Apply
        notify_any_replies: %{
          name: l("Replies to my posts and comments"),
          description:
            l(
              "Including replies to those replies, even when you're not @mentioned. You can unsubscribe from any post or comment with its bell. Replies between people on other servers only arrive if they reach this one."
            ),
          keys: [:notifications, :notify_any_replies],
          default: true
        }
      ]

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
        sections: [
          timeline: Bonfire.UI.Social.ProfileTimelineLive
          # objects: Bonfire.UI.Social.ProfileTimelineLive
          # private: Bonfire.UI.Messages.MessageThreadsLive,
        ],
        navigation: [
          # highlights: l("Highlights"),
          timeline: l("Timeline")
        ],
        widgets: []
      ]
  end
end
