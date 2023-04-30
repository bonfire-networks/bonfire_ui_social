defmodule Bonfire.Social.Moderation.BlockTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Follows
  alias Bonfire.Me.Users
  alias Bonfire.Files.Test
  import Bonfire.Common.Enums

  test "Ghosting a user works" do

  end

  test "Silencing a user works" do

  end

  test "I can see a list of ghosted users" do

  end

  test "I can see a list of silenced users" do

  end

  test "I can unghost a previously ghosted user" do

  end

  test "I can unsilence a previously silenced user" do

  end

  test "I can see if I silenced a user from their profile page" do

  end

  test "I can see if I ghosted a user from their profile page" do

  end

  describe "if I silenced a user i will not receive any update from it" do
    test "i'll not see anything they publish in feeds" do

    end

    test "i'll be able to view their profile or read post via direct link" do

    end

    test "i'll not see any @ mentions or DMs from them" do

    end

    test "I'll not be able to follow them" do

    end

    test "if I unsilence them i'll not be able to see previously missed updates" do

    end
  end


  describe "if I ghosted a user they will not be able to interact with me or with my content" do
    test "Nothing I post privately will be shown to them from now on" do

    end

    test "They will still be able to see things I post publicly. " do

    end

    test "I won't be able to @ mention or message them. " do

    end

    test "they won't be able to follow me" do

    end

    test "You will be able to undo this later but they may not be able to see any activities they missed." do

    end
  end


  describe "Admin" do

    test "As an admin I can ghost a user instance-wide" do

    end

    test "As an admin I can silence a user instance-wide" do

    end

    test "As an admin I can see a list of instance-wide ghosted users" do

    end

    test "As an admin I can see a list of instance-wide silenced users" do

    end

    test "As an admin I can unghost a previously ghosted user instance-wide" do

    end

    test "As an admin I can unsilence a previously silenced user instance-wide" do

    end

  end

end
