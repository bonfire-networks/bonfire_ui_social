defmodule Bonfire.UI.Social.Activity.AltCaptionLive do
  @moduledoc """
  The small "alt" dropdown shown over a media item, revealing the author-provided
  alt text / caption on hover. Extracted from `media_live` where it was repeated
  verbatim across the logged-in / logged-out / GIF branches.

  `onclick="event.stopPropagation()"` is always applied so clicking the label
  never bubbles to the surrounding media button/link (open-modal or navigate).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop media_label, :any, required: true
end
