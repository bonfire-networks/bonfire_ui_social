import Config

config :bonfire_ui_social,
  localisation_path: "priv/localisation"

config :bonfire, :ui,
  invites_component: Bonfire.Invite.Links.Web.InvitesLive,
  # used by ActivityLive - TODO: autogenerate?
  verb_families: [
    reply: ["Reply", "Respond"],
    create: ["Create", "Write"],
    react: ["Like", "Boost", "Flag", "Tag", "Pin"],
    simple_action: ["Assign", "Label", "Schedule"]
  ]
