# Bonfire.UI.Social Usage Rules

Bonfire.UI.Social provides the core user interface components for building federated social network applications. It implements Surface-based LiveView components for feeds, activities, threads, and social interactions.

## Core Concepts

### Component Types
Bonfire.UI.Social uses two types of Surface components:

- **Stateful Components**: Components that maintain their own state and handle events (e.g., FeedLive, ActivityLive)
- **Stateless Components**: Pure presentational components (e.g., SubjectLive, MediaLive)

### Component Architecture
- Components are organized by feature domain (activity, feeds, threads, etc.)
- Each component has an `.ex` file and often a corresponding `.sface` template
- Complex components may have associated CSS files and JavaScript hooks

### LiveHandlers
Shared event handling logic is extracted into LiveHandler modules to keep components DRY:
- `Bonfire.Social.Feeds.LiveHandler` - Feed-related events
- `Bonfire.Social.Threads.LiveHandler` - Thread interactions
- `Bonfire.Social.Objects.LiveHandler` - Object manipulations

## Setup and Module Structure

### Component Declaration

Always use the provided module templates:

```elixir
# For stateful components
defmodule Bonfire.UI.Social.MyComponentLive do
  use Bonfire.UI.Common.Web, :stateful_component
  
  # Props are declared with type and defaults
  prop my_prop, :string, default: nil
  prop required_prop, :any, required: true
end

# For stateless components  
defmodule Bonfire.UI.Social.MyStatelessLive do
  use Bonfire.UI.Common.Web, :stateless_component
end
```

### Including Components

Include stateless components:
```elixir
<StatelessComponent 
  module={maybe_component(Bonfire.UI.Social.SubjectLive, @__context__)} 
  subject={@subject}
/>
```

Include stateful components with an ID:
```elixir
<StatefulComponent 
  id="activity-#{@activity_id}"
  module={maybe_component(Bonfire.UI.Social.ActivityLive, @__context__)}
  activity={@activity}
/>
```

## Core Components

### ActivityLive
The main component for rendering activities (posts, likes, follows, etc.):

```elixir
<StatefulComponent
  id={"activity-#{activity_id}"}
  module={maybe_component(Bonfire.UI.Social.ActivityLive, @__context__)}
  activity={activity}
  feed_id={@feed_id}
  showing_within={:feed}
/>
```

Key props:
- `activity` - The activity struct
- `feed_id` - ID of the containing feed
- `showing_within` - Context (`:feed`, `:thread`, `:profile`)
- `viewing_main_object` - Whether this is the main object view

### FeedLive
Container component for activity feeds:

```elixir
<StatefulComponent
  id={@feed_id || "feed"}
  module={maybe_component(Bonfire.UI.Social.FeedLive, @__context__)}
  feed_name={@feed_name}
  feed_id={@feed_id}
  selected_tab={@selected_tab}
  hide_filters={false}
/>
```

Key props:
- `feed_name` - Named feed (`:my`, `:local`, `:notifications`)
- `feed_id` - Custom feed ID
- `page_info` - Pagination info
- `hide_filters` - Show/hide feed controls

### ThreadLive
Displays threaded discussions:

```elixir
<StatefulComponent
  id="thread"
  module={maybe_component(Bonfire.UI.Social.ThreadLive, @__context__)}
  thread_id={@thread_id}
  thread_mode={:replies}
  max_depth={3}
/>
```

## Feed Patterns

### Creating Custom Feeds

```elixir
# In your LiveView
def mount(_params, _session, socket) do
  feed = Bonfire.Social.FeedLoader.feed(:custom, current_user: current_user(socket))
  
  {:ok, 
    socket
    |> assign(
      feed_id: "my_custom_feed",
      feed: feed,
      page_info: feed.page_info
    )}
end
```

### Handling Feed Events

Use the LiveHandler for consistent feed behavior:

```elixir
defmodule MyApp.MyFeedLive do
  use Bonfire.UI.Common.Web, :live_view
  
  # Delegate feed events to the LiveHandler
  def handle_event("load_more" = event, params, socket) do
    Bonfire.Social.Feeds.LiveHandler.handle_event(event, params, socket)
  end
end
```

## Activity Actions

### Reply Component
```elixir
<StatelessComponent
  module={maybe_component(Bonfire.UI.Social.ReplyLive, @__context__)}
  object={@object}
  object_type={@object_type}
  activity={@activity}
/>
```

### More Actions Menu
```elixir
<StatelessComponent
  module={maybe_component(Bonfire.UI.Social.MoreActionsLive, @__context__)}
  object={@object}
  object_type={@object_type}
  activity={@activity}
/>
```

## Media Handling

### Media Component
Renders various media types with appropriate viewers:

```elixir
<StatelessComponent
  module={maybe_component(Bonfire.UI.Social.MediaLive, @__context__)}
  media={@media}
  media_type={:image}
/>
```

Supported types: `:image`, `:video`, `:audio`, `:pdf`, `:link`

## Routes Integration

### Adding Routes

```elixir
defmodule MyApp.Router do
  use MyApp, :router
  use Bonfire.UI.Social.Routes
  
  # Routes are automatically added:
  # /feed, /feed/:tab, /discussion/:id, /notifications, etc.
end
```

### Custom Routes

```elixir
scope "/", MyApp do
  pipe_through :browser
  
  # Override default routes
  live "/timeline", MyTimelineLive, :index
end
```

## Event Handling Patterns

### Component Events

```elixir
def handle_event("toggle_" <> property, _params, socket) do
  {:noreply, 
    socket
    |> toggle_prop(property)
    |> maybe_reload_feed()}
end

def handle_event("select_tab", %{"tab" => tab}, socket) do
  {:noreply, 
    socket  
    |> assign(selected_tab: tab)
    |> push_patch(to: current_path(socket) <> "?tab=#{tab}")}
end
```

### PubSub Integration

Components automatically subscribe to relevant topics:

```elixir
# In mount or handle_params
PubSub.subscribe("feed:#{feed_id}", socket)

# Handle incoming activities
def handle_info({:new_activity, activity}, socket) do
  {:noreply, insert_activity(socket, activity)}
end
```

## Styling and Assets

### Component CSS
```css
/* In component_name_live.css */
[data-id="my-component"] {
  @apply flex flex-col gap-2;
}
```

### JavaScript Hooks
```javascript
// In component_name_live.hooks.js
export default {
  mounted() {
    // Hook logic
  }
}
```

## Testing Components

### Component Testing

```elixir
defmodule Bonfire.UI.Social.ActivityLiveTest do
  use Bonfire.UI.Social.ConnCase, async: true
  
  test "renders activity", %{conn: conn} do
    user = fake_user!()
    {:ok, activity} = post(user, "Hello world")
    
    html = render_stateful(Bonfire.UI.Social.ActivityLive, %{
      activity: activity,
      __context__: %{current_user: user}
    })
    
    assert html =~ "Hello world"
  end
end
```

### LiveView Testing

```elixir
test "loads more activities", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/feed")
  
  # Trigger load more
  assert view
    |> element("[data-role=load_more]")
    |> render_click()
    
  # Verify new activities loaded
  assert has_element?(view, "[data-id=activity]", count: 20)
end
```

## Performance Optimization

### Deferred Loading
Use `:showing_within` to defer expensive queries:

```elixir
showing_within={if @feed_loading, do: :deferred, else: :feed}
```

### Stream Management
Activities are managed via LiveView streams:

```elixir
socket
|> stream(:activities, activities, reset: true)
|> assign(page_info: page_info)
```

## Common Anti-Patterns

### ❌ Direct Component Inclusion
```elixir
# Bad - bypasses availability checks
<Bonfire.UI.Social.ActivityLive activity={@activity} />

# Good - uses maybe_component
<StatefulComponent 
  module={maybe_component(Bonfire.UI.Social.ActivityLive, @__context__)}
  activity={@activity}
/>
```

### ❌ Hardcoded IDs
```elixir
# Bad - causes duplicate ID errors
<div id="activity">

# Good - use unique IDs
<div id={"activity-#{@activity_id}"}>
```

### ❌ Missing Context
```elixir
# Bad - components need context
<MyComponent />

# Good - always pass context
<MyComponent {...@__context__} />
```

## Integration with Other Extensions

### Using with Bonfire.UI.Me
```elixir
# Include user components
<StatelessComponent
  module={maybe_component(Bonfire.UI.Me.ProfileHeroLive, @__context__)}
  user={@user}
/>
```

### Using with Bonfire.UI.Reactions
```elixir
# Reactions are automatically included in ActivityLive
# But can be used standalone:
<StatelessComponent
  module={maybe_component(Bonfire.UI.Reactions.LikeActionLive, @__context__)}
  object={@object}
/>
```

## Debugging Tips

### Component State
```elixir
# Add to your component
def handle_event("debug", _, socket) do
  debug(socket.assigns, "Current assigns")
  {:noreply, socket}
end
```

### Feed Issues
- Check `feed_id` is consistent across components
- Verify PubSub subscriptions match
- Use `showing_within: :debug` to see all data

### Missing Components
- Ensure extension is enabled in Config
- Check `maybe_component` is returning the module
- Verify module name matches exactly