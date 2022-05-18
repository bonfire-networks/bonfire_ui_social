import Config

config :bonfire_ui_social,
  localisation_path: "priv/localisation"

config :bonfire, :ui,
  invites_component: Bonfire.Invite.Links.Web.InvitesLive
