defmodule Bonfire.UI.Social.Components.Activity do
  use Surface.Catalogue.Example,
    catalogue: Bonfire.UI.Social.Components.Catalogue,
    subject: Bonfire.UI.Social.ActivityLive,
    height: "100px",
    direction: "vertical"

  def render(assigns) do
    ~F"""
    <ActivityLive 
      object={%{
        id: "123",
        name: "Bob",
        character: %{
          username: "bob"
        }
      }}
      character={%{
        username: "bob",
        profile: %{
          name: "Bob"
        }
      }}
      activity={%{
        subject_character: %{
          username: "alice",
          name: "Alice",
        },
        subject_profile: %{
          name: "Alice",
    
        },
        verb: "", 
      }
    }
    }
    permalink="http://example.com",
    date_ago="1 day ago",
    verb_display="created"    
  />
    """
  end
end
