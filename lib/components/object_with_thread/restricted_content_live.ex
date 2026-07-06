defmodule Bonfire.UI.Social.RestrictedContentLive do
  @moduledoc """
  Shown in place of a thread/post when the current user lacks permission to
  read it (e.g. a paywall-style "upgrade to read this" message).

  Disabled by default via the standard `:modularity` key. A flavour or
  instance admin enables it and provides the copy via config or instance
  settings (Settings > Instance > Restricted content screen):

      config :bonfire_ui_social, Bonfire.UI.Social.RestrictedContentLive,
        modularity: true,
        title: "This post is for members only",
        message: "Upgrade your account to read it.",
        cta_label: "Upgrade",
        cta_url: "https://example.com/upgrade"
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop object_type_name, :string, default: nil
  prop object_id, :any, default: nil

  def render(assigns) do
    assigns
    |> assign(
      :rc_settings,
      Settings.get(
        [__MODULE__],
        nil,
        Settings.LiveHandler.scoped(:instance, assigns[:__context__])
      )
    )
    |> render_sface()
  end

  @doc "Whether to show this screen instead of the standard permission error (also checked by `Bonfire.Social.Objects.LiveHandler.not_found_fallback/3`)"
  def enabled?(context \\ nil) do
    module_enabled?(__MODULE__, context || [])
  end

  @doc "Read one of the configured copy fields, treating unset or empty values as `default`"
  def get_setting(settings, key, default) do
    e(settings, key, nil)
    |> e(default)
  end
end
