defmodule Bonfire.UI.Social.Activity.PublishedInLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop context, :any, default: nil

  # compact = inline variant chained onto an attribution line; default = standalone top-line row, the only variant using `class`
  prop compact, :boolean, default: false

  prop class, :css_class,
    default: [
      "flex items-center justify-start border-b-hair border-secondary pb-2 -mx-card px-card -mt-1.5 gap-3"
    ]

  # resolved by the caller, since `path/1` lazily preloads `:character`
  prop to, :any, default: nil

  @published_in_implied_by_context [:group, :topic, :thread, :thread_embed]
  @published_in_never_chained [:widget, :notifications, :smart_input, :pinned, :search]

  @doc "Whether the page itself already establishes the publication context, making a per-card mention redundant. Shared by `ActivityLive.published_in_placement/2` and `SubjectMinimalLive.hide_boost_reason?/4` so they can't disagree."
  def published_in_implied_by_context?(showing_within),
    do: showing_within in @published_in_implied_by_context

  @doc "Whether the compact chip may be chained onto an attribution line here. Must exclude every non-default `{#match}` arm of subject_minimal_live.sface's `{#case @showing_within}`, or a `:chained` placement points at a branch that never renders the chip."
  def chainable_context?(showing_within),
    do: showing_within not in @published_in_never_chained

  @doc """
  The name to show for a publication context, or `nil` when there's none to show without a database round-trip (eg. a bare ULID) — which callers treat as "render nothing" rather than an empty link.

  `Bonfire.UI.Social.WidgetThreadContextLive.category_name/1` delegates here, so a context can't resolve in one surface and vanish from another.
  """
  def context_label(context) do
    e(context, :profile, :name, nil) || e(context, :named, :name, nil) ||
      e(context, :character, :username, nil)
  end
end
