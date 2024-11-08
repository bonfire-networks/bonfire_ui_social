import Config

config :bonfire_common,
  localisation_path: "priv/localisation"

config :bonfire, :ui,
  # used by ActivityLive - TODO: autogenerate?
  verb_families: [
    reply: ["Reply", "Respond"],
    create: ["Create", "Write"],
    react: ["Like", "Boost", "Flag", "Tag", "Pin"],
    simple_action: ["Assign", "Label", "Schedule"]
  ]
