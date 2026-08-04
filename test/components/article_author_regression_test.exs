defmodule Bonfire.UI.Social.ArticleAuthorRegressionTest do
  use Bonfire.UI.Social.ConnCase, async: false

  @moduletag :ui

  alias Bonfire.Social.Boosts

  doctest Bonfire.UI.Articles.ArticleLive, only: [resolve_author: 3]

  test "an article keeps its author's byline on the booster's profile feed" do
    author = fake_user!("joshua_author")
    booster = fake_user!("loren_booster")
    title = "Article byline regression #{System.unique_integer()}"

    article =
      Bonfire.Articles.Fake.fake_article!(author, "public", %{
        post_content: %{
          name: title,
          html_body: "The article body"
        }
      })

    {:ok, _boost} = Boosts.boost(booster, id(article))

    conn(user: booster)
    |> visit("/@#{booster.character.username}")
    |> assert_has("[data-id=activity_article] [data-role=article_byline]",
      text: author.profile.name
    )
    |> refute_has("[data-id=activity_article] [data-role=article_byline]",
      text: booster.profile.name
    )
  end
end
