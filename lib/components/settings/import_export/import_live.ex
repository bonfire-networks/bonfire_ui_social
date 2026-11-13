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
     |> assign_new(:report, fn -> nil end)
     |> allow_upload(:file,
       accept: ~w(.csv .json .zip),
       # an archive with media is much bigger than a list
       max_file_size:
         Bonfire.Common.Config.get([Bonfire.UI.Social.ImportLive, :max_upload_size], 500_000_000),
       max_entries: 1,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  # an archive is staged as soon as its upload finishes, so the person can pick from what it holds before importing anything
  def handle_progress(:file, %{done?: true, client_name: client_name} = entry, socket) do
    # an archive is a person's own account, never imported instance-wide
    if String.ends_with?(String.downcase(client_name), ".zip") and
         e(assigns(socket), :scope, nil) != :instance_wide do
      case consume_uploaded_entry(socket, entry, fn %{path: path} ->
             {:ok, Bonfire.Social.Import.stage_archive(path)}
           end) do
        {:ok, staged} ->
          {:noreply, assign(socket, staged: staged, report: nil)}

        e ->
          {:noreply, assign_error(socket, error_text(e) || l("Could not read this archive"))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_progress(_name, _entry, socket), do: {:noreply, socket}

  def handle_event("import_archive", params, %{assigns: %{staged: %{} = staged}} = socket) do
    current_user = current_user_required!(socket)
    ticked = List.wrap(params["keys"])

    # a ticked box's value is matched against the items the archive offered, never turned into an atom
    keys =
      for %{importable?: true, key: key} <- Bonfire.Social.Import.staged_items(staged),
          to_string(key) in ticked,
          do: key

    case Bonfire.Social.Import.import_staged(current_user, staged,
           only: keys,
           include_boosts: params["include_boosts"] == "true"
         ) do
      {:ok, result} ->
        report = archive_report(staged, result)

        {:noreply,
         socket
         |> assign(report: report)
         |> assign_flash(:info, Enum.map_join(report, "\n", &"#{&1.label}: #{&1.text}"))}

      e ->
        {:noreply, assign_error(socket, error_text(e) || l("Nothing was imported"))}
    end
  end

  def handle_event("import_archive", _params, socket),
    do: {:noreply, assign_error(socket, l("Please upload an archive first"))}

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
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
                      :outbox ->
                        Bonfire.Social.Import.import_from_json_file(:outbox, scope, path,
                          include_boosts: params["include_boosts"] == "true"
                        )

                      type ->
                        Bonfire.Social.Import.import_from_csv_file(type, scope, path)
                    end

                    #   {:ok, "#{num}"}
                    # end
                  end)
                end) do
          {
            :noreply,
            socket
            # what came in differently (eg. a post visible only to the person) or was left out is said too, as the archive import's report does
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

  # one line per thing imported (how many were queued, or that the profile was updated), then each thing left out with why
  defp archive_report(staged, result) do
    labels = Map.new(Bonfire.Social.Import.staged_items(staged), &{&1.key, &1.label})

    queued =
      for {key, %{} = counts} <- Map.drop(result, [:skipped, :notes, :profile]) do
        %{
          label: labels[key] || to_string(key),
          text:
            l("%{queued} queued, %{failed} failed",
              queued: Map.get(counts, :ok, 0),
              failed: Map.get(counts, :error, 0)
            )
        }
      end

    profile =
      if Map.has_key?(result, :profile),
        # the checkbox's long label already said what's filled in, so the report keeps it short
        do: [%{label: l("Profile"), text: l("Filled in what your profile didn't have yet")}],
        else: []

    # what came in differently from the rest (eg. a post visible only to the person), then what was left out
    notes_and_skipped =
      for %{key: key, reason: reason} <-
            List.wrap(result[:notes]) ++ List.wrap(result[:skipped]),
          do: %{label: to_string(key), text: reason}

    queued ++ profile ++ notes_and_skipped
  end

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
    do: %{
      "" => nil,
      l("Archive of another account (ZIP)") => :archive,
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
end
