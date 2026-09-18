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

    # Notifications feed category chips, ordered. Each key is a verb, and `name_pluralized`/`icon` OVERRIDE what that verb declares; see `Bonfire.UI.Social.NotificationFiltersLive`
    config :bonfire_ui_social, Bonfire.UI.Social.NotificationFiltersLive,
      notification_chips: [
        # not "All": types switched off in preferences are excluded from this view
        latest: %{name_pluralized: l("Latest")},
        mention: %{
          name_pluralized: l("Mentions"),
          description: l("Posts that mention or address you"),
          # a non-reply post reaching your notifications feed mentioned or addressed you; a reply that mentions you is stored as a reply, so it shows under Replies until a filter can ask "does a tag point at me", at which point this will become Mentions vs Other replies
          filters: %{activity_types: [:create]},
          path_aliases: ["mentions"]
        },
        reply: %{
          name_pluralized: l("Replies"),
          filters: %{activity_types: [:reply]},
          path_aliases: ["replies"]
        },
        request: %{
          name_pluralized: l("Requests"),
          description: l("Follow and quote requests"),
          filters: %{activity_types: [:request]},
          path_aliases: ["requests"]
        },
        boost: %{
          name_pluralized: l("Boosts"),
          filters: %{activity_types: [:boost]},
          path_aliases: ["boosts"]
        },
        like: %{
          name_pluralized: l("Likes"),
          filters: %{activity_types: [:like]},
          path_aliases: ["likes"]
        },
        follow: %{
          name_pluralized: l("New followers"),
          # overrides the verb's own icon, which the other chips inherit (the `follow` verb declares none)
          icon: "ph:user-plus",
          filters: %{activity_types: [:follow]},
          path_aliases: ["follows", "followers"]
        },

        # shows the existing mod queue, whose preset supplies the label, icon, filters, opts and the `instance_permission_required: :mediate` gate that hides this chip from everyone else
        flag: %{preset: :flagged_content, path_aliases: ["flags"]}
        # TODO: accepted quotes ("X quoted your post") need a home once a filter can read `accepted_at`, or could be combined with mentions
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
