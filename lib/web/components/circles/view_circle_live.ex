defmodule Bonfire.UI.Social.ViewCircleLive do
  use Bonfire.Web, :live_component
  import Bonfire.UI.Social.Integration

  def update(assigns, socket) do
    # FIXME: what's the difference with EditCircleLive?

      with {:ok, circle} <- Bonfire.Me.Users.Circles.get(assigns.id, e(assigns, :current_user, nil)) |> repo().maybe_preload(encircles: [:subject_profile, :subject_character]) do
        IO.inspect(circle)

      # TODO: paginate?
      followed = Bonfire.Social.Follows.list_my_followed(e(assigns, :current_user, nil)) #|> IO.inspect
      followers = Bonfire.Social.Follows.list_my_followers(e(assigns, :current_user, nil)) #|> IO.inspect

      {:ok, assign(socket, assigns
      |> assigns_merge(%{
        circle: circle,
        followers: followers,
        followed:  followed,
        settings_section_title: "View " <> e(circle, :named, :name, "Circle name") <> " circle",
        settings_section_description: "Create and manage your circle."}))}
    end
  end
end
