defmodule Bonfire.UI.Social.MediaOnlyActivityTest do
  @moduledoc """
  Regression tests for a media-only activity (the link/article `Bonfire.Files.Media`
  created by `comments_embed`):

    1. The Media's creator (profile + character) is resolved when the activity
       is loaded, so the author name/avatar render instead of a blank default.
    2. No duplicate/never-resolving media skeleton is emitted for an object
       that is itself a media (already rendered by its object component).
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Files.Media
  alias Bonfire.Posts
  alias Bonfire.Social.Activities
  alias Bonfire.Social.FeedLoader
  alias Bonfire.Social.Objects
  alias Bonfire.UI.Social.ActivityLive

  setup do
    account = fake_account!()
    user = fake_user!(account)
    {:ok, account: account, user: user}
  end

  defp media_only!(user) do
    url = "https://example.com/some/article"

    {:ok, media} =
      Media.insert(
        user,
        url,
        %{media_type: "link", size: 0},
        %{url: url, media_type: "link", metadata: %{"label" => "Some Article Title"}}
      )

    media
  end

  describe "#1 author/creator is resolved for a media-only activity" do
    test "after publish, reading the object resolves the Media creator's profile + character",
         %{user: user} do
      media = media_only!(user)
      assert {:ok, _published} = Media.publish(user, media, boundary: "public")

      # load it the way the thread/discussion view does
      read =
        case Objects.read(media.id, current_user: user) do
          {:ok, o} -> o
          o -> o
        end

      # the Media's direct `creator` must be preloaded with profile + character
      # so the activity subject line (name + @handle/avatar) can render
      assert e(read, :creator, :profile, :name, nil) == e(user, :profile, :name, nil)

      assert e(read, :creator, :character, :username, nil) ==
               e(user, :character, :username, nil)
    end
  end

  describe "#3 a media-only reply_to resolves its author through the real feed pipeline" do
    test "prepare_reply_to/1 self-preloads the Media reply_to's creator (incl. icon) + wires subject_id",
         %{account: account, user: author} do
      # `author` posts a link/article: a `Bonfire.Files.Media` (NOT a Post —
      # no `created` mixin, just a direct `belongs_to(:creator)`).
      media = media_only!(author)
      assert {:ok, _} = Media.publish(author, media, boundary: "public")

      # a different user replies to it, so the Media is the reply_to of the
      # reply activity in the feed
      replier = fake_user!(account)

      {:ok, _reply} =
        Posts.publish(
          current_user: replier,
          post_attrs: %{
            post_content: %{html_body: "Reply to a media-only article"},
            reply_to_id: media.id
          },
          boundary: "public"
        )

      author_name = e(author, :profile, :name, nil)
      author_username = e(author, :character, :username, nil)
      assert is_binary(author_name) and is_binary(author_username)

      # Load the explore feed to get a real reply activity (query-context
      # preloads only — `:with_reply_to` is NOT among them, exactly like
      # production at `prepare_subject_and_creator/2` time).
      %{edges: edges} = FeedLoader.feed(:explore, %{}, current_user: replier)

      reply_activity =
        edges
        |> Enum.map(&(e(&1, :activity, nil) || &1))
        |> Enum.find(fn a -> e(a, :replied, :reply_to_id, nil) == media.id end)

      assert reply_activity,
             "expected an explore-feed activity replying to the media-only object"

      # Resolve `replied.reply_to` to the %Media{} as the explore feed's
      # `:with_reply_to` postload does — but its direct creator is NOT loaded
      # here (only `created.creator` is, which a Media has none of). This is the
      # exact production state when `prepare_reply_to/1` runs.
      reply_activity =
        Activities.activity_preloads(reply_activity, [:with_replied, :with_reply_to],
          current_user: replier
        )

      reply_to = e(reply_activity, :replied, :reply_to, nil)

      assert is_struct(reply_to, Bonfire.Files.Media),
             "the :with_reply_to postload should have resolved reply_to to the %Media{}"

      # prepare_reply_to/1 must self-preload the Media's direct creator and
      # build the subject — NOT the `subject: nil` blank fallback that produced
      # the missing-author bug.
      prepared = ActivityLive.prepare_reply_to(reply_activity)

      refute e(prepared, :activity, :subject, nil) == nil
      assert e(prepared, :activity, :subject, :profile, :name, nil) == author_name
      assert e(prepared, :activity, :subject, :character, :username, nil) == author_username

      # The avatar needs `profile.icon` PRELOADED (a shallow load leaves it
      # `%Ecto.Association.NotLoaded{}` → name shows, blank avatar). It is `nil`
      # for a fixture user with no uploaded avatar, but must NOT be `NotLoaded`.
      prepared_profile = e(prepared, :activity, :subject, :profile, nil)
      assert prepared_profile

      refute match?(%Ecto.Association.NotLoaded{}, Map.get(prepared_profile, :icon)),
             "expected profile.icon to be preloaded (not NotLoaded) so the avatar can render"

      # `subject_id` must be set (and be the actor/user id) at every place
      # `SubjectLive` looks for it — it gates the whole avatar block via
      # `:if={@subject_id}`. Missing it = name/@username show but blank avatar.
      actor_id = id(author)
      assert is_binary(actor_id)
      assert e(prepared, :subject_id, nil) == actor_id
      assert e(prepared, :activity, :subject_id, nil) == actor_id
      assert e(prepared, :activity, :subject, :id, nil) == actor_id
    end
  end

  describe "#2 no duplicate media skeleton for a media-only activity" do
    test "media-typed objects emit NO attachment skeleton even with cached counts" do
      id = "act-#{System.unique_integer([:positive])}"
      # async: false — Cache.put writes in a background task by default, so a
      # read-immediately-after-write in the same test would race it
      Bonfire.Common.Cache.put("num_media:#{id}", [0, 0, 0, 1], async: false)

      for type <- [Bonfire.Files.Media, :link, :article, :image, :audio, :video] do
        assert {nil, []} =
                 ActivityLive.do_primary_image_and_component_maybe_attachments(id, nil, type),
               "expected no skeleton for object_type #{inspect(type)}"
      end
    end

    test "non-media objects reuse the richer cached media skeleton layout summary" do
      id = "act-#{System.unique_integer([:positive])}"

      Bonfire.Common.Cache.put(
        "num_media:#{id}",
        %{
          multimedia_count: 1,
          image_count: 1,
          video_count: 1,
          gif_count: 1,
          visual_count: 3,
          link_count: 2,
          visible_link_count: 1,
          link_preview_count: 1,
          no_cover_links?: true,
          small_icon_links?: true
        },
        async: false
      )

      assert {nil, [{Bonfire.UI.Social.Activity.MediaSkeletonLive, assigns}]} =
               ActivityLive.do_primary_image_and_component_maybe_attachments(id, nil, :post)

      assert assigns.multimedia_count == 1
      assert assigns.visual_count == 3
      assert assigns.link_count == 2
      assert assigns.visible_link_count == 1
      assert assigns.link_preview_count == 1
      assert Map.fetch!(assigns, :no_cover_links?)
      assert Map.fetch!(assigns, :small_icon_links?)
    end

    test "non-media objects emit no skeleton when the media count cache is missing" do
      id = "act-#{System.unique_integer([:positive])}"

      assert {nil, []} =
               ActivityLive.do_primary_image_and_component_maybe_attachments(id, nil, :post)
    end

    test "non-media objects still accept the previous cached media count list" do
      id = "act-#{System.unique_integer([:positive])}"
      Bonfire.Common.Cache.put("num_media:#{id}", [1, 2, 1, 2], async: false)

      assert {nil, [{Bonfire.UI.Social.Activity.MediaSkeletonLive, assigns}]} =
               ActivityLive.do_primary_image_and_component_maybe_attachments(id, nil, :post)

      assert assigns.multimedia_count == 1
      assert assigns.image_count == 2
      assert assigns.gif_count == 1
      assert assigns.visual_count == 3
      assert assigns.link_count == 2
      assert assigns.visible_link_count == 2
      assert assigns.link_preview_count == 0
      assert Map.fetch!(assigns, :no_cover_links?)
      assert Map.fetch!(assigns, :small_icon_links?)
    end
  end
end
