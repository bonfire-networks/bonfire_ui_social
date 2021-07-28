defmodule Bonfire.UI.Social.Components.Subject.SubjectReplied do
  use Surface.Catalogue.Example,
    catalogue: Bonfire.UI.Social.Components.Catalogue,
    subject: Bonfire.UI.Social.Activity.SubjectRepliedLive,
    height: "100px",
    direction: "vertical"

  def render(assigns) do
    ~F"""
    <SubjectRepliedLive 
      activity={%{
        subject_character: %{
          username: "alice",
          name: "Alice",
        },
        subject_profile: %{
          name: "Alice",
        },
        replied: %{
          reply_to_id: 1,
        }
      }
    }
    permalink="https://example.com"
    date_ago="1 minute ago"   
  />
    """
  end
end
