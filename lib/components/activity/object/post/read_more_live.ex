# The Read more and Read less buttons are now part of `Bonfire.UI.Common.TruncatableLive`, which clamps a post's body as well as bios and group descriptions, so nothing renders this component any more.
# defmodule Bonfire.UI.Social.Activity.ReadMoreLive do
#   use Bonfire.UI.Common.Web, :stateless_component
#
#   prop showing_within, :atom, default: nil
#   prop viewing_main_object, :boolean, default: false
#   prop object, :any
#   prop activity, :any, default: nil
#   prop parent_id, :any, default: nil
# end
