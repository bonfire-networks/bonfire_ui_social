defmodule Bonfire.UI.Social.ImportStagingGuestTest do
  @moduledoc "Someone with no session cannot get an uploaded archive staged: the finished upload is left alone."
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  test "a finished archive upload is not staged for a guest" do
    entry = %Phoenix.LiveView.UploadEntry{
      ref: "0",
      client_name: "archive.zip",
      done?: true,
      progress: 100
    }

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, scope: nil}}

    assert {:noreply, socket} =
             Bonfire.UI.Social.ImportLive.handle_progress(:file, entry, socket)

    refute socket.assigns[:staging], "the archive of a guest was staged"
  end
end
