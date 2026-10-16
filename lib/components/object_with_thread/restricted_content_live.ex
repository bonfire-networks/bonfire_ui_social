defmodule Bonfire.UI.Social.RestrictedContentLive do
  @moduledoc """
  Shown in place of what the current user lacks permission to read (e.g. a paywall-style "upgrade to read this" message), in two sizes by `viewing_main_object`:

  - the object being opened (its page, or the preview modal): the full screen, instead of the standard permission error. Disabled by default via the standard `:modularity` key
  - one item of a list (`viewing_main_object: false`, eg. a feed card of something the viewer may find but not read): its name and summary and why the rest isn't shown, never its body or media. Always, whatever the setting, as this is what keeps the content back; only its wording comes from the settings

  A flavour or instance admin enables the full screen and provides the copy via config or instance settings (Settings > Instance > Restricted content screen):

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

  @doc "The full screen when true (the object being opened), else the card shown for it in a list"
  prop viewing_main_object, :boolean, default: true

  @doc "For the card: its name and summary are shown"
  prop object, :any, default: nil

  @doc "For the card: the group that keeps it to its members, named in why it isn't shown"
  prop published_in, :any, default: nil

  @doc "For the card: of its media, only the one flagged as its primary image (a cover), shown as an article's is"
  prop primary_image, :any, default: nil

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

  @doc """
  Whether to show this screen instead of the standard permission error (also
  checked by `Bonfire.Social.Objects.LiveHandler.not_found_fallback/3`).

  Opt-in: only an explicit `modularity: true` (or `:enabled`) turns it on —
  unset means off, unlike the usual modularity semantics. A boot-time default
  would be clobbered by/clobber flavour config (extension `RuntimeConfig`s run
  after compile-time config), so no default is written anywhere.
  """
  def enabled?(context \\ nil) do
    Settings.get(
      [__MODULE__, :modularity],
      nil,
      Settings.LiveHandler.scoped(:instance, context)
    )
    |> Bonfire.Common.Extend.enabled_value?()
  end

  @doc """
  Why it isn't shown, in either size: the instance's configured title when it has enabled the screen (eg. "Upgrade to read"), else the group that keeps it to its members, else plainly. No noun for the object, which is shown around it, and whose gender would change the sentence in many languages.
  """
  def title(settings, published_in, context) do
    (enabled?(context) && get_setting(settings, :title, nil)) ||
      case e(published_in, :profile, :name, nil) do
        nil -> l("You can't read this")
        group -> l("Only members of %{group} can read this", group: group)
      end
  end

  @doc "Read one of the configured copy fields, treating unset or empty values as `default`"
  def get_setting(settings, key, default) do
    e(settings, key, nil)
    |> e(default)
  end
end
