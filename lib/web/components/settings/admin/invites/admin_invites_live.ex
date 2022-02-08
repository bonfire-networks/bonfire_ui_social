defmodule Bonfire.UI.Social.SettingsViewsLive.AdminInvitesLive do
  use Bonfire.Web, :stateful_component

  prop invites, :list, default: []

  def update(assigns, socket) do
    %{edges: invites, page_info: page_info} = Bonfire.Invite.Links.list_paginated([], socket: socket)
    {:ok, socket
    |> assign(
      invites: invites,
      page_info: page_info
    )
    }
  end

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
