defmodule Bonfire.UI.Social.TitleMarkupXSSTest do
  @moduledoc """
  A title (`name`) and a content warning (`summary`) are plain text: whatever way they were typed or imported, the page shows the text and never a tag of it.
  """
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  @encoded "&lt;script&gt;alert(1)&lt;/script&gt; Safe"
  @encoded_img "&lt;img src=x onerror=alert(1)&gt; Safe"

  setup do
    alice = fake_user!()
    %{alice: alice, conn: conn(user: alice, account: alice.account)}
  end

  defp publish(module, alice, content) do
    {:ok, object} =
      module.publish(
        current_user: alice,
        post_attrs: %{post_content: Map.put_new(content, :html_body, "Some body text")},
        boundary: "public"
      )

    object
  end

  for {kind, module} <- [post: Bonfire.Posts, article: Bonfire.Articles],
      field <- [:name, :summary] do
    describe "#{field} of a #{kind}" do
      test "entity-encoded markup is shown as text, not as a tag", %{alice: alice, conn: conn} do
        object = publish(unquote(module), alice, %{unquote(field) => @encoded})

        conn
        |> visit(Bonfire.Common.URIs.path(object))
        |> wait_async()
        |> assert_has("[data-id=main_section]", text: "Safe")
        |> refute_has("[data-id=main_section] [data-role=#{unquote(field)}] script")
      end

      test "entity-encoded markup with an event handler is not a live tag", %{
        alice: alice,
        conn: conn
      } do
        object = publish(unquote(module), alice, %{unquote(field) => @encoded_img})

        conn
        |> visit(Bonfire.Common.URIs.path(object))
        |> wait_async()
        |> assert_has("[data-id=main_section]", text: "Safe")
        |> refute_has("[data-id=main_section] [onerror*='alert(1)']")
      end

      test "typed markup is removed (control)", %{alice: alice, conn: conn} do
        object =
          publish(unquote(module), alice, %{unquote(field) => "<script>alert(1)</script>Safe"})

        conn
        |> visit(Bonfire.Common.URIs.path(object))
        |> wait_async()
        |> assert_has("[data-id=main_section]", text: "Safe")
        |> refute_has("[data-id=main_section] [data-role=#{unquote(field)}] script")
      end
    end
  end

  for {kind, body} <- [
        raw: "<script>alert(1)</script><img src=x onerror=alert(1)>Safe",
        encoded: "&lt;script&gt;alert(1)&lt;/script&gt;&lt;img src=x onerror=alert(1)&gt; Safe"
      ] do
    test "a body with #{kind} markup shows no live tag", %{alice: alice, conn: conn} do
      object = publish(Bonfire.Posts, alice, %{html_body: unquote(body)})

      conn
      |> visit(Bonfire.Common.URIs.path(object))
      |> wait_async()
      |> assert_has("[data-id=main_section]", text: "Safe")
      |> refute_has("[data-id=object_body] script")
      |> refute_has("[data-id=object_body] [onerror*='alert(1)']")
    end
  end

  test "a title with `&` and `<` as text is shown as typed", %{alice: alice, conn: conn} do
    object = publish(Bonfire.Articles, alice, %{name: "Tom & Jerry: a < b"})

    conn
    |> visit(Bonfire.Common.URIs.path(object))
    |> wait_async()
    |> assert_has("[data-id=main_section] [data-role=name]", text: "Tom & Jerry: a < b")
  end
end
