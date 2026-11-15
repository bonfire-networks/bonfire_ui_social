# delegated events ("Module:event", sent from any page through `mod_delegate`) must check who sends them: each test asserts the safe outcome
defmodule Bonfire.UI.Social.DelegatedEventsAuthzTest do
  use ExUnit.Case, async: false
  @moduletag :ui
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Bonfire.UI.Common.Testing.Helpers
  import Ecto.Query

  @endpoint Application.compile_env!(:bonfire, :endpoint_module)

  alias Bonfire.Me.Fake

  setup tags do
    Bonfire.Common.Test.Interactive.setup_test_repo(tags)
    owner_account = Fake.fake_account!()
    owner = Fake.fake_user!(owner_account)

    # a post guests may NOT read (local users only)
    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: owner,
        post_attrs: %{post_content: %{html_body: "not for guests"}},
        boundary: "local"
      )

    %{owner: owner, owner_account: owner_account, post: post}
  end

  # any LiveView page will do; a profile page is served to guests too (with a LiveView session)
  defp send_event(conn, page_user, name, params) do
    {:ok, view, _} = live(conn, "/@" <> page_user.character.username)

    try do
      render_hook(view, name, params)
    rescue
      _ -> :error
    catch
      _, _ -> :error
    end
  end

  defp stranger do
    account = Fake.fake_account!()
    {Fake.fake_user!(account), account}
  end

  # Bonfire.Social.Feeds:delete

  test "Feeds:delete: a GUEST cannot delete someone else's activity", %{owner: owner} do
    {:ok, public_post} =
      Bonfire.Posts.publish(
        current_user: owner,
        post_attrs: %{post_content: %{html_body: "do not delete"}},
        boundary: "public"
      )

    activity_id = Bonfire.Common.Types.uid(public_post.activity)
    assert is_binary(activity_id)

    send_event(build_conn(), owner, "Bonfire.Social.Feeds:delete", %{"id" => activity_id})

    assert Bonfire.Common.Repo.exists?(
             from(a in Bonfire.Data.Social.Activity, where: a.id == ^activity_id)
           )
  end

  # Bonfire.Social.Objects:reset_boundary

  test "Objects:reset_boundary \"private\": someone who may only read cannot wipe the post's ACLs (a grant stays)",
       %{owner: owner, post: post} do
    other = Fake.fake_user!()
    {:ok, acl} = Bonfire.Boundaries.Acls.get_or_create_object_custom_acl(post, owner)

    Bonfire.Boundaries.Grants.grant(other.id, acl.id, [:see, :read], true,
      skip_boundary_check: true
    )

    {reader, account} = stranger()

    Bonfire.Boundaries.Grants.grant(reader.id, acl.id, [:see, :read], true,
      skip_boundary_check: true
    )

    assert Bonfire.Boundaries.can?(other, :read, post)

    send_event(
      conn(user: reader, account: account),
      owner,
      "Bonfire.Social.Objects:reset_boundary",
      %{"boundary" => "private", "object_id" => post.id}
    )

    assert Bonfire.Boundaries.can?(other, :read, post)
  end
end
