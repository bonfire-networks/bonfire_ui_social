defmodule Bonfire.UI.Social.WidgetGettingStartedLive do
  @moduledoc """
  Sidebar widget that walks a new user through a small set of starter actions.

  All available steps live in `actions_registry/0`, with every user-facing
  string wrapped in `l/1` so they translate per request. Each flavour
  selects and orders the steps it wants by listing their keys in config:

      config :bonfire_ui_social, Bonfire.UI.Social.WidgetGettingStartedLive,
        actions: [:profile, :first_post, :first_follow, :read_coc, :wishes]

  To add a step, add an entry to `actions_registry/0` (in code, not config),
  so its copy stays translatable and its completion detector stays in code.
  Instance-specific URLs (e.g. the Code of Conduct path) are read from
  config so flavours can override them without duplicating any copy.

  Completion is auto-detected from the data layer via each step's optional
  `:done?` detector; the user can also mark a step done manually. Both the
  manual marks and the dismissal flag are stored as per-user settings under
  `[:ui, :getting_started, ...]`, so they follow the user across browsers
  and devices.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.Common.Config
  alias Bonfire.Common.Settings
  alias Bonfire.Common.Utils

  @default_actions [:profile, :first_post, :first_follow]
  @settings_path [:ui, :getting_started]

  data dismissed?, :boolean, default: false
  data celebrating?, :boolean, default: false
  data steps, :list, default: []
  data current, :any, default: nil
  data viewing_index, :integer, default: 0
  data done_count, :integer, default: 0
  data total_count, :integer, default: 0
  data manual_done, :list, default: []

  @doc """
  Closed registry of supported actions. Flavours pick keys from here in
  their config; they cannot invent new keys without code, by design.

  All copy is wrapped in `l/1` so it translates per request. Steps without
  a `:done?` detector (e.g. reading the Code of Conduct) complete manually.
  Instance-specific URLs are read from config with sensible defaults.
  """
  def actions_registry do
    %{
      profile: %{
        title: l("Add a profile picture and bio"),
        rationale: l("Letting people see who you are makes following you a real choice."),
        cta_label: l("Edit your profile"),
        cta_path: "/settings/",
        done?: &profile_complete?/1
      },
      first_post: %{
        title: l("Write your first post"),
        rationale: l("Your voice is what makes the feed worth coming back to."),
        cta_label: l("Compose a post"),
        cta_kind: :composer,
        cta_path: nil,
        done?: &has_posted?/1
      },
      first_follow: %{
        title: l("Follow someone"),
        rationale: l("Your feed comes alive once you follow a few people. Start with one."),
        cta_label: l("Find people"),
        cta_path: "/users",
        done?: &has_followed?/1
      },
      read_coc: %{
        title: l("Read the Code of Conduct"),
        rationale: l("A short read so you know what to expect from the community."),
        cta_label: l("Open the Code of Conduct"),
        cta_path: Config.get([__MODULE__, :code_of_conduct_path], "/conduct", :bonfire_ui_social)
      },
      wishes: %{
        title: l("Tell us about your wishes"),
        rationale: l("Help us shape what comes next — your input drives the roadmap."),
        cta_label: l("Share your wishes"),
        cta_path: Config.get([__MODULE__, :wishes_url], nil, :bonfire_ui_social)
      }
    }
  end

  @doc """
  Action specs configured for this instance, falling back to the default
  seed. Each configured key is looked up in `actions_registry/0`; unknown
  keys are silently dropped.
  """
  def configured_actions do
    Config.get([__MODULE__, :actions], @default_actions, :bonfire_ui_social)
    |> List.wrap()
    |> Enum.flat_map(&normalize_action/1)
  end

  defp normalize_action(key) when is_atom(key) do
    case Map.fetch(actions_registry(), key) do
      {:ok, spec} -> [Map.put(spec, :key, key)]
      :error -> []
    end
  end

  defp normalize_action(_), do: []

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    {dismissed?, manual} = load_state(current_user(socket))

    # Skip per-step `done?` detectors (which hit the DB) when the widget
    # would render hidden anyway.
    if dismissed? do
      {:ok, assign(socket, dismissed?: true, manual_done: manual)}
    else
      {:ok, recompute(socket, dismissed?, manual)}
    end
  end

  def handle_event("mark_done", %{"key" => key}, socket) do
    user = current_user(socket)

    manual =
      (List.wrap(socket.assigns.manual_done) ++ [to_string(key)])
      |> Enum.uniq()

    _ = Settings.put(@settings_path ++ [:manual_done], manual, current_user: user)

    {:noreply, recompute(socket, socket.assigns.dismissed?, manual)}
  end

  def handle_event("dismiss", _params, socket) do
    _ = Settings.put(@settings_path ++ [:dismissed], true, current_user: current_user(socket))
    {:noreply, assign(socket, dismissed?: true, celebrating?: false)}
  end

  def handle_event("prev", _params, socket) do
    total = socket.assigns.total_count
    next_index = rem(socket.assigns.viewing_index - 1 + total, max(total, 1))
    {:noreply, assign(socket, viewing_index: next_index)}
  end

  def handle_event("next", _params, socket) do
    total = socket.assigns.total_count
    next_index = rem(socket.assigns.viewing_index + 1, max(total, 1))
    {:noreply, assign(socket, viewing_index: next_index)}
  end

  @doc false
  def load_state(nil), do: {true, []}

  def load_state(user) do
    dismissed? = !!Settings.get(@settings_path ++ [:dismissed], false, current_user: user)

    manual =
      Settings.get(@settings_path ++ [:manual_done], [], current_user: user)
      |> List.wrap()
      |> Enum.map(&to_string/1)

    {dismissed?, manual}
  end

  defp recompute(socket, dismissed?, manual_done) do
    user = current_user(socket)
    actions = configured_actions()

    steps =
      Enum.map(actions, fn spec ->
        manual? = to_string(spec.key) in manual_done
        done? = manual? || run_done(spec, user)
        Map.put(spec, :done?, done?)
      end)

    # Persist newly auto-detected completions so subsequent renders
    # short-circuit on the `manual? || ...` guard above and skip the
    # per-step DB hit. One write per transition; zero writes once a
    # user is fully complete.
    manual_done = persist_newly_done(steps, manual_done, user)

    total = length(steps)
    done_count = Enum.count(steps, & &1.done?)
    current = Enum.find(steps, &(!&1.done?))
    all_done? = total > 0 and is_nil(current)

    # Celebrate only when this LV process witnesses the transition from
    # "had work left" to "all done". On the first compute `current` is nil
    # by default, so users who were already complete stay hidden.
    fresh_completion? = all_done? and not is_nil(socket.assigns[:current])

    viewing_index =
      case Enum.find_index(steps, &(!&1.done?)) do
        nil -> 0
        idx -> idx
      end

    socket
    |> assign(
      manual_done: manual_done,
      dismissed?: dismissed?,
      steps: steps,
      current: current,
      viewing_index: viewing_index,
      done_count: done_count,
      total_count: total,
      celebrating?: socket.assigns[:celebrating?] || fresh_completion?
    )
  end

  defp run_done(%{done?: fun}, user) when is_function(fun, 1) do
    try do
      !!fun.(user)
    rescue
      _ -> false
    end
  end

  defp run_done(_, _), do: false

  defp persist_newly_done(_steps, manual_done, nil), do: manual_done

  defp persist_newly_done(steps, manual_done, user) do
    newly_done =
      for step <- steps,
          step.done?,
          key = to_string(step.key),
          key not in manual_done,
          do: key

    case newly_done do
      [] ->
        manual_done

      _ ->
        updated = manual_done ++ newly_done
        _ = Settings.put(@settings_path ++ [:manual_done], updated, current_user: user)
        updated
    end
  end

  # --- detection signals ---

  @doc false
  def profile_complete?(nil), do: false

  def profile_complete?(user) do
    summary = e(user, :profile, :summary, "")
    has_bio? = is_binary(summary) and String.trim(summary) != ""

    has_avatar? =
      not is_nil(e(user, :profile, :icon_id, nil)) or
        not is_nil(e(user, :profile, :icon, :id, nil)) or
        not is_nil(e(user, :profile, :icon, :url, nil))

    has_avatar? and has_bio?
  end

  @doc false
  def has_posted?(nil), do: false

  def has_posted?(user) do
    case Utils.maybe_apply(Bonfire.Posts, :count_for_user, [user], fallback_return: nil) do
      n when is_integer(n) and n > 0 -> true
      _ -> false
    end
  end

  @doc false
  def has_followed?(nil), do: false

  def has_followed?(user) do
    case Utils.maybe_apply(
           Bonfire.Social.Graph.Follows,
           :all_by_subject,
           [user, [limit: 1]],
           fallback_return: []
         ) do
      [_ | _] -> true
      _ -> false
    end
  end

  @doc """
  Drives the template's top-level case.

  - `:hidden` — render nothing (dismissed, no actions configured, or all
    actions were already done before this LV process started).
  - `:celebrate` — final beat after the user freshly completes everything
    in this session.
  - `:step` — the normal one-action-at-a-time view.
  """
  def render_state(%{dismissed?: true}), do: :hidden
  def render_state(%{total_count: 0}), do: :hidden
  def render_state(%{celebrating?: true}), do: :celebrate
  def render_state(%{current: nil}), do: :hidden
  def render_state(_), do: :step

  @doc "The step currently focused in the viewer (defaults to first undone)."
  def viewing_step(%{steps: steps, viewing_index: idx}) when is_list(steps) and steps != [] do
    Enum.at(steps, idx) || List.first(steps)
  end

  def viewing_step(_), do: nil
end
