defmodule Bonfire.UI.Social.HomeLive do
  use Bonfire.UI.Common.Web, :surface_view
  alias Bonfire.UI.Me.LivePlugs
  alias Bonfire.Social.Feeds.LiveHandler

  def mount(params, session, socket) do
    live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.UserRequired,
      # LivePlugs.LoadCurrentAccountUsers,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3,
    ]
  end

  defp mounted(params, _session, socket) do
    {:ok, socket
    |> assign(
      [
        selected_tab: "feed",
        page: "feed",
        page_title: l("My feed"),
        page_header_drawer: true,
        feedback_title: l("Your home feed is empty"),
        feedback_message: l("You can start by following some people or by writing a new post."),
        sidebar_widgets: [
          users: [
            secondary: [
              {Bonfire.UI.Social.WidgetTagsLive, []},
              {Bonfire.UI.Common.WidgetInstanceInfoLive, []},
              {Bonfire.UI.Common.WidgetFeedbackLive, []}
            ]
          ]
        ],
        page_header_aside:
        [{Bonfire.UI.Social.HeaderAsideFeedsLive, [
          page_title: l("Discussion"),
          page: "feed",
        ]}]
      ])
    }
  end

  def do_handle_params(%{"tab" => "federation" = tab} = params, _url, socket) do
    {:noreply, assign(socket, LiveHandler.feed_assigns_maybe_async(:fediverse, socket))}
  end

  def do_handle_params(%{"tab" => "local" = tab} = params, _url, socket) do

    {:noreply, assign(socket, LiveHandler.feed_assigns_maybe_async(:local, socket)) }
  end

  def do_handle_params(_params, _url, socket) do
    # debug("param")

    {:noreply, assign(socket, LiveHandler.feed_assigns_maybe_async(:default, socket))}
  end


  # defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers
  def handle_params(params, uri, socket) do
    # poor man's hook I guess
    with {_, socket} <- Bonfire.UI.Common.LiveHandlers.handle_params(params, uri, socket) do
      undead_params(socket, fn ->
        do_handle_params(params, uri, socket)
      end)
    end
  end
  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)


end
