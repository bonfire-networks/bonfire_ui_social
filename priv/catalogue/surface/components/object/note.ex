defmodule Bonfire.UI.Social.Components.Object.Note do
  use Surface.Catalogue.Example,
    catalogue: Bonfire.UI.Social.Components.Catalogue,
    subject: Bonfire.UI.Social.Activity.NoteLive,
    height: "100px",
    direction: "vertical"

  def render(assigns) do
    ~F"""
    <NoteLive 
      object={%{
        name: "The title of a post",
        summary: "the summary of the post",
        html_body: "ciaoooo",
        id: "123",
        character: %{
          username: "bob"
        },
        profile: %{
          name: "Bob"
        }
      }}
      activity={%{
        id: "123",
        replied: %{
          reply_to_id: "123",
        },
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
    viewing_main_object={false},
    showing_within_thread={false},
    permalink="http://example.com",
    date_ago="1 day ago"    
    />
    """
  end
end
