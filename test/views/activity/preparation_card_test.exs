defmodule Bonfire.UI.Social.PreparationCardTest do
  @moduledoc """
  The card for an AS2 `Preparation` (a recipe, e.g. federated from cuisine.social).

  A recipe is kept whole as an `APActivity` rather than flattened into a `Post` (see
  `AP_HANDLE_OBJECT_TYPES`), so the card is what makes its ingredients and steps visible at all.

  A feed entry shows only what the recipe is and how big it is; the recipe itself would crowd out
  everything around it, so it appears on the object's own page.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  @photo "https://cuisine.local/blobs/1596.jpg"

  # The language maps a real sender uses (`nameMap` and friends) are derived into these plain
  # properties at ingest by `ActivityPub.Federator.Transformer.fix_language_maps/1`.
  defp recipe_object do
    %{
      "type" => ["Note", "Preparation"],
      "name" => "Salade de boulgour",
      "url" => "https://cuisine.local/dmathieu/p/213",
      "description" => "Sur une base de boulgour, avec des lardons.",
      # the stub body a `Note` reader would see: title, tags and a link back, all of which the card
      # already shows structurally, so it must NOT be rendered
      "content" => "<p><strong>Salade de boulgour</strong></p><p>#salade</p>",
      "serving" => 6,
      "servingType" => "personnes",
      "ingredients" => [
        %{"name" => "Boulgour", "position" => 1, "quantity" => 250.0, "unit" => "g"},
        %{"name" => "Lardons", "position" => 2, "quantity" => 200.0, "unit" => "g"},
        %{"name" => "Aubergine", "position" => 3, "quantity" => 1.0, "unit" => ""}
      ],
      "steps" => [
        %{"type" => "PreparationContent", "position" => 2, "content" => "Griller les lardons."},
        %{"type" => "PreparationContent", "position" => 1, "content" => "Cuire le boulgour."}
      ],
      "tag" => [%{"type" => "Hashtag", "name" => "#salade"}],
      "attachment" => [
        %{
          "type" => "Image",
          "mediaType" => "image/jpeg",
          "name" => "La salade, dans son saladier.",
          "url" => [%{"type" => "Link", "mediaType" => "image/jpeg", "href" => @photo}]
        }
      ]
    }
  end

  defp fake_recipe!(user) do
    activity_json = %{
      "type" => "Create",
      "actor" => Bonfire.Common.URIs.canonical_url(user),
      "published" => DateTime.to_iso8601(DateTime.utc_now()),
      "to" => ["https://www.w3.org/ns/activitystreams#Public"]
    }

    {:ok, activity} =
      Bonfire.Social.APActivities.ap_receive(user, activity_json, recipe_object(), true)

    activity
  end

  setup do
    account = fake_account!()
    me = fake_user!(account)
    {:ok, conn: conn(user: me, account: account), me: me, account: account}
  end

  describe "in a feed" do
    test "says what the recipe is and how much it makes", %{conn: conn, me: me} do
      fake_recipe!(me)

      conn
      |> visit("/feed/explore")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "Salade de boulgour")
      |> assert_has("[data-id=feed]", text: "6 personnes")
      |> assert_has("[data-id=feed]", text: "3 ingredients")
      |> assert_has("[data-id=feed]", text: "Sur une base de boulgour")
    end

    test "leaves the recipe itself for the object's own page", %{conn: conn, me: me} do
      fake_recipe!(me)

      conn
      |> visit("/feed/explore")
      |> wait_async()
      |> refute_has("[data-id=feed]", text: "Cuire le boulgour")
    end
  end

  describe "on the object's own page" do
    # `content` is the stub a `Note` reader gets, restating what the card shows structurally, so
    # rendering it would repeat the title and the hashtag back at the reader.
    test "shows the sender's description, not the stub body", %{conn: conn, me: me} do
      activity = fake_recipe!(me)

      conn
      |> visit(path(activity))
      |> wait_async()
      |> assert_has("article", text: "Sur une base de boulgour, avec des lardons.")
      |> refute_has("article", text: "Salade de boulgour#salade")
    end

    test "lists the ingredients with their quantities", %{conn: conn, me: me} do
      activity = fake_recipe!(me)

      session =
        conn
        |> visit(path(activity))
        |> wait_async()

      session
      |> assert_has("li", text: "250 g")
      |> assert_has("li", text: "Boulgour")

      # a recipe asks for 1 aubergine, not 1.0, and an unmeasured ingredient has no unit to show
      session
      |> assert_has("li", text: "1 Aubergine")
    end

    # The card deliberately does not render the dish's photo, because the `attachment` becomes Media
    # (see `APActivities.maybe_attach_media/3`). If that ever stops being true the photo silently
    # disappears, so assert it is there.
    #
    # Images are lazy-loaded, so the server HTML carries the URL as `data-src` on the LazyImage hook
    # and the `<img>` has no `src` until the hook runs.
    test "shows the dish's photo, via the attachment's Media", %{conn: conn, me: me} do
      activity = fake_recipe!(me)

      conn
      |> visit(path(activity))
      |> wait_async()
      |> assert_has("[phx-hook*='LazyImage'][data-src='#{@photo}']")
      |> assert_has("img[alt='La salade, dans son saladier.']")
    end

    # A `Hashtag` in the object's `tag` is cast as a real tag at ingest (see
    # `APActivities.maybe_cast_tags/3`), so it links to the hashtag feed like a local post's would.
    # The card renders no badges of its own, which would duplicate this.
    test "links the recipe's hashtag to its feed", %{conn: conn, me: me} do
      activity = fake_recipe!(me)

      conn
      |> visit(path(activity))
      |> wait_async()
      |> assert_has("a[href='/hashtag/salade']", text: "#salade")
    end

    test "lists the steps in the order the sender numbered them", %{conn: conn, me: me} do
      activity = fake_recipe!(me)

      conn
      |> visit(path(activity))
      |> wait_async()
      |> assert_has("ol li:first-child", text: "Cuire le boulgour")
      |> assert_has("ol li:last-child", text: "Griller les lardons")
    end
  end
end
