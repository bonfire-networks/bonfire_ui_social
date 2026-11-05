# TEMPORARY CI probe: a deeper stacktrace so the CI-only `:peered` raise in `Bonfire.UI.Social.WidgetTrendingDomIdsTest` names the component that renders the unpreloaded post (the default depth of 8 frames stops inside the Copy link helpers). Remove once that component preloads at its source.
:erlang.system_flag(:backtrace_depth, 50)

ExUnit.start(exclude: Bonfire.Common.RuntimeConfig.skip_test_tags())
Ecto.Adapters.SQL.Sandbox.mode(Bonfire.Common.Config.repo(), :manual)
