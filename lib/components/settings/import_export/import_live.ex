defmodule Bonfire.UI.Social.ImportLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop selected_tab, :any
  prop scope, :atom, default: nil
  prop type, :atom, default: nil

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       trigger_submit: false,
       uploaded_files: [],
       page_title: "Blocks Import"
     )
     |> assign_new(:staged, fn -> nil end)
     |> assign_new(:staging, fn -> false end)
     # set once an import of a staged file is queued, to say it started and where to follow it
     |> assign_new(:import_started, fn -> false end)
     # the type picked in the dropdown, as the form sent it, so an upload is staged by the source that type names
     |> assign_new(:import_type, fn -> nil end)
     |> allow_upload(:file,
       accept: ~w(.csv .json .zip .xml),
       # an archive with media is much bigger than a list
       max_file_size:
         Bonfire.Common.Config.get([Bonfire.UI.Social.ImportLive, :max_upload_size], 500_000_000),
       max_entries: 1,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  # a whole file (an account archive, a WordPress export…) is staged as soon as its upload finishes, so the person can pick from what it holds before importing anything
  def handle_progress(:file, %{done?: true, client_name: client_name} = entry, socket) do
    type = staging_type(e(assigns(socket), :import_type, nil), client_name)

    # only someone signed in has an archive to stage, and an archive is a person's own account, never imported instance-wide
    if not is_nil(current_user(socket)) and
         not is_nil(Bonfire.Common.Import.archive_source(type)) and
         e(assigns(socket), :scope, nil) != :instance_wide do
      # LiveView deletes its copy of the upload once this callback returns, so it's copied for the staging that runs after
      copy =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          copy =
            Path.join(
              System.tmp_dir!(),
              "upload-#{Needle.UID.generate()}#{String.downcase(Path.extname(client_name))}"
            )

          File.cp!(path, copy)
          {:ok, copy}
        end)

      # read in the background, so the page says it's being read rather than freezing until it's done
      {:noreply,
       socket
       |> assign(staging: true, staged: nil, import_started: false)
       |> start_async(:stage_archive, fn ->
         try do
           Bonfire.Common.Import.stage_archive(type, copy)
         after
           File.rm(copy)
         end
       end)}
    else
      {:noreply, socket}
    end
  end

  def handle_progress(_name, _entry, socket), do: {:noreply, socket}

  # the dropdown's pick, or the account archive for a zip uploaded before picking anything
  defp staging_type(type, client_name) when type in [nil, ""],
    do: if(String.ends_with?(String.downcase(client_name), ".zip"), do: "archive")

  defp staging_type(type, _client_name), do: type

  def handle_async(:stage_archive, {:ok, {:ok, staged}}, socket),
    do: {:noreply, assign(socket, staging: false, staged: staged)}

  def handle_async(:stage_archive, {:ok, e}, socket),
    do:
      {:noreply,
       socket
       |> assign(staging: false)
       |> assign_error(error_text(e) || l("Could not read this archive"))}

  def handle_async(:stage_archive, {:exit, reason}, socket) do
    error(reason, "Staging an uploaded archive failed")

    {:noreply,
     socket
     |> assign(staging: false)
     |> assign_error(l("Could not read this archive"))}
  end

  def handle_event("import_archive", params, %{assigns: %{staged: %{} = staged}} = socket) do
    current_user = current_user_required!(socket)
    ticked = List.wrap(params["keys"])

    # a ticked box's value is matched against the items the archive offered, never turned into an atom
    keys =
      for %{importable?: true, key: key} <- Bonfire.Common.Import.staged_items(staged),
          to_string(key) in ticked,
          do: key

    # the import is prepared and done in the background, so a big import never holds up the page: what it will do was shown before the click, and its progress is on the import status page. The ticked options are matched against what was offered there, never turned into atoms
    case Bonfire.Common.Import.queue_import(
           current_user,
           staged,
           keys,
           List.wrap(params["options"])
         ) do
      {:ok, _job} ->
        {:noreply, assign(socket, staged: nil, import_started: true)}

      e ->
        {:noreply, assign_error(socket, error_text(e) || l("Nothing was imported"))}
    end
  end

  def handle_event("import_archive", _params, socket),
    do: {:noreply, assign_error(socket, l("Please upload an archive first"))}

  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, import_type: params["type"])}
  end

  def handle_event("import", %{"type" => type} = params, socket) do
    current_user = current_user_required!(socket)
    #  TODO check permission
    scope = e(assigns(socket), :scope, nil) || id(current_user)

    case uploaded_entries(socket, :file) |> debug() do
      {[_ | _] = entries, []} ->
        # no `:ok` when nothing was queued (eg. an outbox holding only boosts, which weren't asked for), which still has something to report
        with [%{} = result] <-
               (for entry <- entries do
                  maybe_consume_uploaded_entry(socket, entry, fn %{path: path} ->
                    debug(path)
                    # debug(entry)
                    # with %{ok: num} <-
                    # do
                    case maybe_to_atom(type) do
                      # an ActivityPub outbox, read by the federation extension
                      :outbox ->
                        Bonfire.Common.Utils.maybe_apply(
                          Bonfire.Federate.ActivityPub.Import.OutboxOps,
                          :import_from_json_file,
                          [
                            :outbox,
                            scope,
                            path,
                            [include_boosts: params["include_boosts"] == "true"]
                          ]
                        )

                      type ->
                        Bonfire.Common.Import.import_from_csv_file(type, scope, path)
                    end

                    #   {:ok, "#{num}"}
                    # end
                  end)
                end) do
          {
            :noreply,
            socket
            # what came in differently (eg. a post visible only to the person) or was left out is said too, as the archive import's checklist does
            |> assign_flash(
              :info,
              Enum.join(
                [
                  "#{Map.get(result, :ok, 0)} items queued for import :-)"
                  | for(
                      %{key: key, reason: reason} <-
                        List.wrap(result[:notes]) ++ List.wrap(result[:skipped]),
                      do: "#{key}: #{reason}"
                    )
                ],
                "\n"
              )
            )
            # |> update(:uploaded_files, &(&1 ++ uploaded_files))
          }
        else
          e ->
            error(e)

            {
              :noreply,
              socket
              |> assign_error("No items queued for import")
            }
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp error_text({:error, msg}) when is_binary(msg), do: msg
  defp error_text(_), do: nil

  # def handle_progress(
  #       type,
  #       entry,
  #       socket
  #     ),
  #     do:
  #       Bonfire.UI.Common.LiveHandlers.handle_progress(
  #         type,
  #         entry,
  #         socket,
  #         __MODULE__,
  #         Bonfire.Files.LiveHandler
  #       )

  def options_list(:instance_wide, :blocks, _),
    do: %{
      "" => nil,
      l("List of profiles/instances to ghost instance-wide (CSV)") => :ghosts,
      l("List of profiles/instances to silence instance-wide (CSV)") => :silences,
      l("List of profiles/instances to block instance-wide (CSV)") => :blocks
    }

  def options_list(_, type, federating?) when type == :blocks or federating? == false,
    do: %{
      "" => nil,
      l("List of profiles/instances to ghost (CSV)") => :ghosts,
      l("List of profiles/instances to silence (CSV)") => :silences,
      l("List of profiles/instances to block (CSV)") => :blocks
    }

  def options_list(_, _, _),
    do:
      Map.merge(
        archive_source_options(),
        %{
          "" => nil,
          l("List of profiles to follow (CSV)") => :following,
          l("Posts/creations in outbox (JSON)") => :outbox,
          l("List of bookmarks (CSV)") => :bookmarks,
          l("List of likes (CSV)") => :likes,
          l("List of boosts (CSV)") => :boosts,
          l("List of lists/circles and their members (CSV))") => :circles,
          l("List of profiles/instances to ghost (CSV)") => :ghosts,
          l("List of profiles/instances to silence (CSV)") => :silences,
          l("List of profiles/instances to block (CSV)") => :blocks
        }
      )

  # one option per source a whole file can be staged from (the account archive, and any an extension registers), named by the source
  defp archive_source_options do
    for {key, source} <- Bonfire.Common.Import.archive_sources(), into: %{} do
      label =
        if Code.ensure_loaded?(source) and function_exported?(source, :import_source_label, 0),
          do: source.import_source_label(),
          else: to_string(key)

      {label, key}
    end
  end
end
