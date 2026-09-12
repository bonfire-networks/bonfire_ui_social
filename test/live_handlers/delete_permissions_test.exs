defmodule Bonfire.UI.Social.DeletePermissionsTest do
  @moduledoc "Tests delete events directly because menu visibility cannot authorize a client-supplied object ID."

  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Me.{Accounts, Fake}
  alias Bonfire.Posts
  alias Bonfire.Social.Objects.LiveHandler

  @moduletag capture_log: true

  setup do
    Process.put([:bonfire, :skip_all_boundary_checks], false)
    refute Bonfire.Common.Config.get(:skip_all_boundary_checks)

    owner_account = Fake.fake_account!()
    owner = Fake.fake_user!(owner_account)
    other_account = Fake.fake_account!()
    other = Fake.fake_user!(other_account)
    refute Accounts.is_admin?(owner)
    refute Accounts.is_admin?(other)

    {:ok, post} =
      Posts.publish(
        current_user: owner,
        post_attrs: %{post_content: %{html_body: "Delete event #{Faker.UUID.v4()}"}},
        boundary: "public"
      )

    {:ok,
     owner: owner,
     post: post,
     owner_socket: delete_socket(owner_account, owner),
     other_socket: delete_socket(other_account, other)}
  end

  test "a non-owner's direct delete event leaves the post intact", context do
    result = LiveHandler.handle_event("delete", %{"id" => context.post.id}, context.other_socket)

    assert result == {:error, :not_found}
    assert {:ok, saved_post} = Posts.read(context.post.id, current_user: context.owner)
    assert saved_post.id == context.post.id
    assert Posts.count_for_user(context.owner) == 1
  end

  test "the owner's direct delete event deletes the post", context do
    result = LiveHandler.handle_event("delete", %{"id" => context.post.id}, context.owner_socket)

    assert {:noreply, %Phoenix.LiveView.Socket{}} = result
    assert {:error, _} = Posts.read(context.post.id, current_user: context.owner)
  end

  defp delete_socket(account, user) do
    %Phoenix.LiveView.Socket{
      endpoint: @endpoint,
      private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}},
      assigns: %{
        __changed__: %{},
        flash: %{},
        __context__: %{
          current_account_id: account.id,
          current_user_id: user.id,
          current_user: user
        },
        current_account_id: account.id,
        current_user_id: user.id,
        current_user: user
      }
    }
  end
end
