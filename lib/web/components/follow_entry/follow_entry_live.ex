defmodule Bonfire.UI.Social.FollowEntryLive do
  use Bonfire.Web, :live_component

  def update(%{follow: follow} = assigns, socket) do

    follow = case follow do
      %{followed_profile: %{id: _} = profile, followed_character: %{id: _} = character} ->
        %{profile: profile, character: character}

      %{follower_profile: %{id: _} = profile, follower_character: %{id: _} = character} ->
        %{profile: profile, character: character}

      other ->

        user = other |> Bonfire.Repo.maybe_preload([:subject_profile, :subject_character]) |> IO.inspect

        %{profile: e(user, :subject_profile, nil), character: e(user, :subject_character, nil)}
    end

    {:ok, assign(socket, assigns
    |> assigns_merge(%{
      follow: follow,
      })) }
  end
end
