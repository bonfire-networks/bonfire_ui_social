defmodule Bonfire.UI.Social.ImportHistoryLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    current_user = current_user(socket)

    if current_user do
      filters = %{type: nil, status: nil}
      page = 1
      per_page = 20

      jobs = fetch_import_jobs(current_user, filters, page, per_page)
      stats = fetch_import_stats(current_user)

      {:ok,
       assign(
         socket,
         page_title: l("Import Dashboard"),
         page: "import_history",
         back: true,
         page_header_aside: [
           {Bonfire.UI.Social.ImportRefreshLive,
            [
              feed_id: :import_history
            ]}
         ],
         selected_tab: :import_history,
         nav_items: Bonfire.Common.ExtensionModule.default_nav(),
         jobs: jobs,
         stats: stats,
         filters: filters,
         current_page: page,
         per_page: per_page,
         has_more: length(jobs) == per_page
       )}
    else
      throw(l("You need to log in to view import history"))
    end
  end

  def handle_params(params, _url, socket) do
    filters = %{
      type: params["type"],
      status: params["status"]
    }

    page = String.to_integer(params["page"] || "1")

    current_user = current_user(socket)
    jobs = fetch_import_jobs(current_user, filters, page, socket.assigns.per_page)

    {:noreply,
     assign(socket,
       jobs: jobs,
       filters: filters,
       current_page: page,
       has_more: length(jobs) == socket.assigns.per_page
     )}
  end

  def handle_event("refresh", _attrs, socket) do
    current_user = current_user(socket)

    jobs =
      fetch_import_jobs(
        current_user,
        socket.assigns.filters,
        socket.assigns.current_page,
        socket.assigns.per_page
      )

    stats = fetch_import_stats(current_user)

    {:noreply, assign(socket, jobs: jobs, stats: stats)}
  end

  def handle_event("filter", %{"type" => type}, socket) do
    new_filters = %{socket.assigns.filters | type: if(type == "", do: nil, else: type)}
    params = filter_params(new_filters, 1)

    {:noreply,
     push_patch(socket,
       to:
         "/settings/import_history" <>
           if(map_size(params) > 0, do: "?" <> URI.encode_query(params), else: "")
     )}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    new_filters = %{socket.assigns.filters | status: if(status == "", do: nil, else: status)}
    params = filter_params(new_filters, 1)

    {:noreply,
     push_patch(socket,
       to:
         "/settings/import_history" <>
           if(map_size(params) > 0, do: "?" <> URI.encode_query(params), else: "")
     )}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/settings/import_history"
     )}
  end

  def handle_event("next_page", _params, socket) do
    next_page = socket.assigns.current_page + 1
    params = filter_params(socket.assigns.filters, next_page)

    {:noreply,
     push_patch(socket,
       to:
         "/settings/import_history" <>
           if(map_size(params) > 0, do: "?" <> URI.encode_query(params), else: "")
     )}
  end

  def handle_event("prev_page", _params, socket) do
    prev_page = max(1, socket.assigns.current_page - 1)
    params = filter_params(socket.assigns.filters, prev_page)

    {:noreply,
     push_patch(socket,
       to:
         "/settings/import_history" <>
           if(map_size(params) > 0, do: "?" <> URI.encode_query(params), else: "")
     )}
  end

  def handle_event("cancel_jobs_by_type", %{"type" => type}, socket) do
    current_user = current_user(socket)
    user_id = id(current_user)
    # |> type_to_op_code()
    op_code = type

    try do
      {count, _} =
        Bonfire.Common.ObanHelpers.cancel_jobs_by_type_for_user(repo(), user_id, op_code)

      # Refresh data
      jobs =
        fetch_import_jobs(
          current_user,
          socket.assigns.filters,
          socket.assigns.current_page,
          socket.assigns.per_page
        )

      stats = fetch_import_stats(current_user)

      {:noreply,
       socket
       |> assign(jobs: jobs, stats: stats)
       |> assign_flash(
         :info,
         l("Cancelled %{count} jobs of type %{type}", count: count, type: type)
       )}
    rescue
      error ->
        debug(error, "Error cancelling jobs")
        {:noreply, assign_error(socket, l("Failed to cancel jobs"))}
    end
  end

  defp filter_params(filters, page) do
    %{}
    |> Enums.maybe_put("type", filters.type)
    |> Enums.maybe_put("status", filters.status)
    |> Enums.maybe_put("page", if(page > 1, do: page, else: nil))
  end

  defp fetch_import_jobs(current_user, filters \\ %{}, page \\ 1, per_page \\ 20) do
    user_id = id(current_user)
    offset = (page - 1) * per_page

    try do
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
      jobs = Enum.take(jobs, per_page)

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
    rescue
      error ->
        debug(error, "Error fetching import jobs")
        []
    end
  end

  defp identifier(%{"identifier" => identifier}), do: identifier
  defp identifier(%{"id" => identifier}), do: identifier
  defp identifier(%{"activity_id" => identifier}), do: identifier
  defp identifier(%{"activity" => %{"id" => identifier}}), do: identifier
  defp identifier(%{"params" => %{"id" => identifier}}), do: identifier
  defp identifier(_), do: nil

  defp apply_filters(jobs, %{type: nil, status: nil}), do: jobs

  defp apply_filters(jobs, %{type: type, status: status}) do
    jobs
    |> Enum.filter(fn job ->
      type_match =
        if type, do: format_operation_type(get_in(job.args, ["op"])) == type, else: true

      status_match = if status, do: normalize_status(job.state) == status, else: true
      type_match and status_match
    end)
  end

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

  defp fetch_import_stats(current_user) do
    user_id = id(current_user)

    try do
      # Get basic job state counts
      basic_stats =
        Bonfire.Common.ObanHelpers.job_stats_for_user(repo(), user_id)
        |> debug("actual_job_states_in_db")

      # Get all jobs for detailed analysis
      # FIXME: do this with DB query rather than fetching all and doing in memory
      jobs =
        Bonfire.Common.ObanHelpers.list_jobs_for_user(
          repo(),
          user_id,
          e(current_user, :character, :username, nil),
          limit: 10000
        )

      # Debug: show actual states that exist
      actual_states = jobs |> Enum.map(& &1.state) |> Enum.uniq() |> debug("unique_states_found")

      # Compute enhanced statistics
      compute_enhanced_stats(basic_stats, jobs)
    rescue
      _error ->
        %{}
    end
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
    operation_counts = count_by_operation_type(jobs)

    %{
      # Enhanced metrics
      total: total_jobs,
      successful: successful,
      active: active_jobs,
      failed: failed_jobs,
      success_rate: success_rate,
      by_operation: operation_counts,

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
    all_operations = all_operation_types()

    # Count actual jobs by operation type
    actual_counts =
      jobs
      |> Enum.group_by(fn job -> get_in(job.args, ["op"]) end)
      |> Enum.map(fn {op_code, job_list} ->
        {format_operation_type(op_code), length(job_list)}
      end)
      |> Enum.into(%{})

    # Merge actual counts with all types (actual counts override 0 defaults)
    Map.merge(all_operations, actual_counts)
  end

  defp all_operation_types do
    %{
      l("Follow") => 0,
      l("Block") => 0
      # l("Silence") => 0,
      # l("Ghost") => 0,
      # l("Bookmark") => 0,
      # l("Like") => 0,
      # l("Boost") => 0,
      # l("Circle") => 0
    }
  end

  defp pre_existing_data_errors,
    do: [
      "Subject id: has already been taken",
      "You already boosted this."
    ]

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
  defp format_operation_type("fetch_remote"), do: l("Fetch Content")
  defp format_operation_type("publish"), do: l("Federate")
  defp format_operation_type("publish_one"), do: l("Federate")
  defp format_operation_type("incoming_ap_doc"), do: l("Incoming federated activity")
  defp format_operation_type("incoming_unverified_ap_doc"), do: l("Incoming federated activity")
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
