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

  def render(assigns), do: render_sface(assigns)

  # its wording is the instance's, read through `Bonfire.Social.RestrictedContent` (`why_not_shown/2`, `call_to_action/1`, `setting/3`, `enabled?/1`, moved there from here on 2 November), so the API's statuses say the same as this card
end
