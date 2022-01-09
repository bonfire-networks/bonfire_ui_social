defmodule Bonfire.UI.Social.ViewCircleLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do
    # FIXME: what's the difference with EditCircleLive?

      with {:ok, circle} <- Bonfire.Me.Users.Circles.get(assigns.id, current_user(assigns)) |> repo().maybe_preload(encircles: [subject: [:profile, :character]]) do
        IO.inspect(circle)

      # TODO: paginate?
      followed = Bonfire.Social.Follows.list_my_followed(current_user(assigns)) #|> IO.inspect
      followers = Bonfire.Social.Follows.list_my_followers(current_user(assigns)) #|> IO.inspect

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
