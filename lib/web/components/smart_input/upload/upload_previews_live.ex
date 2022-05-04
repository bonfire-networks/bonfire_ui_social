defmodule Bonfire.UI.Social.UploadPreviewsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop uploads, :any

  def error_to_string(:too_large), do: l "The file is too large."
  def error_to_string(:not_accepted), do: l "You have selected a file type that is not permitted. Contact your instance admin if you want it added."
  def error_to_string(:too_many_files), do: l "You have selected too many files."
end
