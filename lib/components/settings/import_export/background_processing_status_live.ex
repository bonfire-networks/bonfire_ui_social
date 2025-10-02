defmodule Bonfire.UI.Social.BackgroundProcessingStatusLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop selected_tab, :string, default: nil
  prop filters, :map, default: %{}
  prop per_page, :integer, default: 20
  prop page_title, :string, default: "Background Processing Status"
  prop page, :string, default: "background_processing_status_live"
  # current_user by default
  prop scope, :atom, default: nil

  @impl true
  def update(assigns, socket) do
    current_user = current_user(assigns) || current_user(socket)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:filters, normalize_filters(assigns.filters, assigns.selected_tab))
     |> assign_new(:current_page, fn -> 1 end)
     #  |> assign(:back, true)
     #  |> assign(:page_header_aside, [
     #    {Bonfire.UI.Social.ImportRefreshLive, [feed_id: :import_history]}
     #  ])
     # |> assign(:nav_items, Bonfire.Common.ExtensionModule.default_nav())
     |> load_jobs_and_maybe_stats(current_user)}
  end

  @impl true
  def handle_event("refresh", _attrs, socket) do
    {:noreply, load_jobs_and_maybe_stats(socket)}
  end

  @impl true
  def handle_event("filter", %{"type" => type}, socket) do
    filters = Map.put(socket.assigns.filters || %{}, :type, if(type == "", do: nil, else: type))
    socket = assign(socket, filters: filters, current_page: 1)
    {:noreply, assign_jobs(socket)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    filters =
      Map.put(socket.assigns.filters || %{}, :status, if(status == "", do: nil, else: status))

    socket = assign(socket, filters: filters, current_page: 1)
    {:noreply, assign_jobs(socket)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(
       filters:
         normalize_filters(
           Map.merge(socket.assigns.filters || %{}, %{type: nil, status: nil}),
           socket.assigns.selected_tab
         ),
       current_page: 1
     )
     |> load_jobs_and_maybe_stats()}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    socket = assign(socket, current_page: socket.assigns.current_page + 1)
    {:noreply, assign_jobs(socket)}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    socket = assign(socket, current_page: max(1, socket.assigns.current_page - 1))
    {:noreply, assign_jobs(socket)}
  end

  @impl true
  def handle_event("cancel_jobs_by_type", %{"type" => type}, socket) do
    current_user = current_user(socket)
    user_id = id(current_user)
    username = e(current_user, :character, :username, nil)

    {count, _} =
      Bonfire.Common.ObanHelpers.cancel_jobs_by_type_for_user(repo(), user_id, username, type)

    {:noreply,
     load_jobs_and_maybe_stats(socket)
     |> assign_flash(:info, l("Cancelled %{count} jobs", count: count))}
  rescue
    error ->
      debug(error, "Error cancelling jobs")
      {:noreply, assign_error(socket, l("Failed to cancel jobs"))}
  end

  defp load_jobs(socket, current_user \\ nil) do
    current_user = current_user || current_user(socket)
    filters = socket.assigns.filters
    page = socket.assigns.current_page || 1
    per_page = socket.assigns.per_page || 20
    scope = socket.assigns.scope

    {user_id, username} =
      if scope == :instance_wide do
        {nil, nil}
      else
        {id(current_user), e(current_user, :character, :username, nil)}
      end

    jobs =
      Bonfire.Common.ObanHelpers.list_jobs(
        repo(),
        user_id,
        username,
        limit: per_page + 1,
        offset: (page - 1) * per_page,
        filters: filters
      )

    has_more = length(jobs) == per_page + 1

    %{jobs: Enum.take(jobs, per_page), has_more: has_more}
  end

  defp assign_jobs(socket, current_user \\ nil) do
    %{jobs: jobs, has_more: has_more} = load_jobs(socket, current_user)
    assign(socket, jobs: jobs |> format_jobs(), has_more: has_more)
  end

  defp load_jobs_and_maybe_stats(socket, current_user \\ nil) do
    %{jobs: jobs, has_more: has_more} = load_jobs(socket, current_user)
    scope = socket.assigns.scope

    if jobs != [] do
      stats =
        if has_more or (socket.assigns.current_page || 1) != 1 do
          fetch_import_stats(current_user, e(socket.assigns, :selected_tab, nil), nil, scope)
        else
          fetch_import_stats(current_user, e(socket.assigns, :selected_tab, nil), jobs, scope)
        end
        |> debug("computed_stats")

      assign(socket, stats: stats, jobs: jobs |> format_jobs(), has_more: has_more)
    else
      assign(socket, stats: %{}, jobs: jobs |> format_jobs(), has_more: has_more)
    end
  end

  defp normalize_filters(filters, nil), do: filters

  defp normalize_filters(filters, type_group) do
    filters
    # |> Map.put(:type, type_group_op_codes(type_group))
    |> Map.put(:queue, type_group_queues(type_group))
  end

  defp fetch_import_jobs(current_user, filters \\ %{}, page \\ 1, per_page \\ 20) do
    user_id = id(current_user)
    offset = (page - 1) * per_page

    # Bonfire.Common.ObanHelpers.list_jobs_queue_for_user(repo(), "import", 
    jobs =
      Bonfire.Common.ObanHelpers.list_jobs_for_user(
        repo(),
        user_id,
        e(current_user, :character, :username, nil),
        # Fetch one extra to check if there are more
        limit: per_page + 1,
        offset: offset,
        filters: filters
      )

    # Take only the requested amount (the extra one is just for pagination check)
    Enum.take(jobs, per_page)
  end

  defp identifier(%{"identifier" => identifier}), do: identifier
  defp identifier(%{"id" => identifier}), do: identifier
  defp identifier(%{"activity_id" => identifier}), do: identifier
  defp identifier(%{"activity" => %{"id" => identifier}}), do: identifier
  defp identifier(%{"params" => %{"id" => identifier}}), do: identifier
  defp identifier(_), do: nil

  defp normalize_status("completed"), do: "successful"
  defp normalize_status("pre_existing"), do: "successful"

  defp normalize_status(status)
       when status in ["executing", "available", "scheduled", "retryable"],
       do: "active"

  defp normalize_status(status) when status in ["discarded", "cancelled"], do: "failed"
  defp normalize_status(_), do: "other"

  defp fetch_users_by_identifiers(identifiers) when identifiers != [] do
    # Try to fetch users by username first, but only for string identifiers
    string_identifiers = Enum.filter(identifiers, &is_binary/1)

    users_by_username =
      if string_identifiers != [] do
        Bonfire.Me.Characters.by_usernames(string_identifiers)
        |> debug("lsited")
        |> Map.new(fn user -> {e(user, :username, nil), user} end)
        |> debug("maopped")
      else
        %{}
      end

    # # For remaining identifiers, try fetching by AP ID or other methods
    # remaining_identifiers = identifiers -- Map.keys(users_by_username)

    # users_by_ap_id =
    #   if remaining_identifiers != [] do
    #     remaining_identifiers
    #     |> Enum.map(fn identifier ->
    #       case Bonfire.Federate.ActivityPub.AdapterUtils.get_by_url_ap_id_or_username(identifier) do
    #         {:ok, user} -> {identifier, user}
    #         _ -> nil
    #       end
    #     end)
    #     |> Enum.reject(&is_nil/1)
    #     |> Map.new()
    #   else
    #     %{}
    #   end

    users_by_username
    # |> Map.merge(users_by_ap_id)
  end

  defp fetch_users_by_identifiers([]), do: %{}

  defp fetch_import_stats(current_user, selected_tab, jobs \\ nil, scope \\ nil) do
    scope = scope || @scope

    {user_id, username} =
      if scope == :instance_wide do
        {nil, nil}
      else
        {id(current_user), e(current_user, :character, :username, nil)}
      end

    # types = selected_tab && type_group_op_codes(selected_tab)
    queues = selected_tab && type_group_queues(selected_tab)

    # Only apply type group filter if selected_tab is set and not a single type filter
    jobs =
      cond do
        is_list(jobs) ->
          jobs

        is_list(queues) ->
          Bonfire.Common.ObanHelpers.list_jobs(
            repo(),
            user_id,
            username,
            limit: 10000,
            filters: %{queue: queues}
          )

        # is_list(types) ->
        #   Bonfire.Common.ObanHelpers.list_jobs(
        #     repo(),
        #     user_id,
        #     username,
        #     limit: 10000,
        #     filters: %{type: types}
        #   )

        true ->
          Bonfire.Common.ObanHelpers.list_jobs(
            repo(),
            user_id,
            username,
            limit: 10000
          )
      end

    basic_stats =
      Bonfire.Common.ObanHelpers.job_stats(
        repo(),
        user_id,
        username,
        %{
          # type: types || nil,
          queue: queues || nil
        }
      )
      |> debug("actual_job_states_in_db")

    # Debug: show actual states that exist
    actual_states = jobs |> Enum.map(& &1.state) |> Enum.uniq() |> debug("unique_states_found")

    # Compute enhanced statistics
    compute_enhanced_stats(basic_stats, jobs)
    # rescue
    #   error ->
    #     error(error, "Error fetching import stats")
    #     %{}
  end

  defp compute_enhanced_stats(basic_stats, jobs) do
    total_jobs = Enum.sum(Map.values(basic_stats))

    # Calculate meaningful metrics
    completed = Map.get(basic_stats, "completed", 0)
    pre_existing = count_pre_existing_jobs(jobs)
    successful = completed + pre_existing

    active_jobs =
      Map.get(basic_stats, "executing", 0) +
        Map.get(basic_stats, "available", 0) +
        Map.get(basic_stats, "scheduled", 0) +
        Map.get(basic_stats, "retryable", 0)

    failed_jobs =
      Map.get(basic_stats, "discarded", 0) +
        Map.get(basic_stats, "cancelled", 0) - pre_existing

    success_rate = if total_jobs > 0, do: Float.round(successful / total_jobs * 100, 1), else: 0

    # Count by operation type

    %{
      # Enhanced metrics
      total: total_jobs,
      successful: successful,
      active: active_jobs,
      failed: failed_jobs,
      success_rate: success_rate,
      by_operation: count_by_operation_type(jobs),

      # Original basic stats for backward compatibility
      raw_stats: basic_stats
    }
  end

  defp count_pre_existing_jobs(jobs) do
    jobs
    |> Enum.count(fn job ->
      format_errors(job.errors) in pre_existing_data_errors()
    end)
  end

  defp count_by_operation_type(jobs) do
    # Start with all operation types set to 0
    # all_operations = all_operation_types()

    # Count actual jobs by operation type
    actual_counts =
      jobs
      |> Enum.group_by(fn job -> get_in(job.args, ["op"]) end)
      |> Enum.map(fn {op_code, job_list} ->
        {op_code, format_operation_type(op_code), length(job_list)}
      end)

    # |> Enum.into(%{})

    # Merge actual counts with all types (actual counts override 0 defaults)
    # Map.merge(all_operations, actual_counts)
  end

  # defp all_operation_types do
  #   %{
  #     l("Follow") => 0,
  #     l("Block") => 0
  #     # l("Silence") => 0,
  #     # l("Ghost") => 0,
  #     # l("Bookmark") => 0,
  #     # l("Like") => 0,
  #     # l("Boost") => 0,
  #     # l("Circle") => 0
  #   }
  # end

  defp pre_existing_data_errors,
    do: [
      "Subject id: has already been taken",
      "You already boosted this."
    ]

  defp format_jobs(jobs) do
    # Extract all identifiers for batch user lookup
    identifiers =
      jobs
      |> Enum.map(&identifier/1)
      |> debug("idds")
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    # Batch fetch users to avoid N+1
    users_by_identifier = fetch_users_by_identifiers(identifiers)

    jobs
    |> Enum.map(&format_job(&1, users_by_identifier))

    # rescue
    #   error ->
    #     error(error, "Error fetching job identifers")
    #     []
  end

  defp format_job(job, users_by_identifier \\ %{}) do
    op_code = get_in(job.args, ["op"])
    op_type = op_code |> format_operation_type()
    identifier = identifier(job.args)
    target_user = if identifier, do: Map.get(users_by_identifier, identifier)

    # Extract error for special handling
    extracted_error =
      job.errors
      |> format_errors()
      |> case do
        nil -> nil
        err -> String.trim(err)
      end

    # Special case: circles_import + "Subject id: has already been taken"
    is_pre_existing = extracted_error in pre_existing_data_errors()

    %{
      id: job.id,
      op_code: op_code,
      operation: op_type,
      identifier: identifier,
      context: e(job.args, "context", nil) || e(job.args, "params", "inbox", nil),
      target_user: target_user,
      state: if(is_pre_existing, do: "pre_existing", else: job.state),
      inserted_at: job.inserted_at,
      completed_at: job.completed_at,
      attempted_at: job.attempted_at,
      error: if(!is_pre_existing, do: extracted_error),
      attempt: job.attempt,
      max_attempts: job.max_attempts
    }
  end

  # defp type_group_op_codes("import"),
  #   do: [
  #     "follows_import",
  #     "blocks_import",
  #     "silences_import",
  #     "ghosts_import",
  #     "bookmarks_import",
  #     "circles_import",
  #     "outbox_import",
  #     "outbox_creations_import",
  #     "likes_import",
  #     "boosts_import"
  #   ]

  # defp type_group_op_codes("federation"),
  #   do: [
  #     "fetch_remote",
  #     "publish",
  #     "publish_one",
  #     "incoming_ap_doc",
  #     "incoming_unverified_ap_doc"
  #   ]

  # defp type_group_op_codes(_), do: []

  @doc """
  Returns the list of Oban queue names for a given type group.

  ## Examples

      iex> type_group_queues("federation")
      ["federator_incoming", "federator_outgoing", "remote_fetcher"]

      iex> type_group_queues("import")
      ["import", "deletion", "video_transcode", "fetch_open_science"]

      iex> type_group_queues("other")
      []

  """
  defp type_group_queues("federation"),
    do: ["federator_incoming", "federator_outgoing", "remote_fetcher"]

  defp type_group_queues("import"),
    do: ["import", "deletion", "video_transcode", "fetch_open_science"]

  defp type_group_queues(_), do: nil

  defp format_operation_type("follows_import"), do: l("Follow")
  defp format_operation_type("blocks_import"), do: l("Block")
  defp format_operation_type("silences_import"), do: l("Silence")
  defp format_operation_type("ghosts_import"), do: l("Ghost")
  defp format_operation_type("bookmarks_import"), do: l("Bookmark")
  defp format_operation_type("circles_import"), do: l("Circle")
  defp format_operation_type("outbox_import"), do: l("Posts & boosts")
  defp format_operation_type("outbox_creations_import"), do: l("Posts/Creations")
  defp format_operation_type("likes_import"), do: l("Like")
  defp format_operation_type("boosts_import"), do: l("Boost")
  defp format_operation_type("fetch_remote"), do: l("Fetch content")
  defp format_operation_type("publish"), do: l("Prep for federation")
  defp format_operation_type("publish_one"), do: l("Outgoing federation")
  defp format_operation_type("incoming_ap_doc"), do: l("Incoming federation")

  defp format_operation_type("incoming_unverified_ap_doc"),
    do: l("Incoming federation (unverified)")

  defp format_operation_type(other), do: other

  defp format_state("pre_existing"), do: {l("Pre-existing"), "text-info/70"}
  defp format_state("completed"), do: {l("Completed"), "text-success"}
  defp format_state("failed"), do: {l("Failed (will attempt again)"), "text-error"}
  defp format_state("executing"), do: {l("Running"), "text-warning"}
  defp format_state("available"), do: {l("Queued"), "text-info"}
  defp format_state("scheduled"), do: {l("Scheduled"), "text-info"}
  defp format_state("retryable"), do: {l("Retrying"), "text-warning"}
  defp format_state("cancelled"), do: {l("Cancelled"), "text-base-content/60"}
  defp format_state("discarded"), do: {l("Failed"), "text-error"}
  defp format_state(other), do: {other, "text-base-content"}

  defp format_errors(errors) when is_list(errors) do
    errors
    |> Enum.map_join("\n", fn
      %{"error" => error} -> extract_core_error(error)
      error when is_binary(error) -> extract_core_error(error)
      error -> inspect(error)
    end)
  end

  defp format_errors(errors), do: extract_core_error(errors)

  defp extract_core_error(error) when is_binary(error) do
    case Regex.run(~r/failed with (.+)$/, error) do
      [_, core_error] ->
        core_error
        |> String.trim_leading("{")
        |> String.trim_trailing("}")
        |> String.replace(":error, ", "")
        |> String.replace("\"", "")
        |> String.replace("\\n", "\n")
        |> Types.maybe_to_atom()
        |> Bonfire.Common.Errors.error_msg({:error, ...})

      _ ->
        error
    end
  end

  defp extract_core_error(error), do: inspect(error)
end
