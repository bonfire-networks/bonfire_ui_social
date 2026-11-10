defmodule Bonfire.UI.Social.Activity.AltCaptionLive do
  @moduledoc """
  The small "alt" dropdown shown over a media item, revealing the author-provided
  alt text / caption on tap or click (not hover: iOS Safari doesn't focus a tapped
  button, so a hover menu wouldn't open on phones). Extracted from `media_live` where
  it was repeated verbatim across the logged-in / logged-out / GIF branches.

  `onclick="event.preventDefault(); event.stopPropagation()"` is always applied so
  clicking it never reaches the surrounding media button (open-modal) nor follows
  the image link it sits in when logged out.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "DOM id for the dropdown, unique per media item on the page"
  prop id, :string, required: true

  prop media_label, :any, required: true
end
