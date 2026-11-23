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

  test "an article's feed card has no byline when its author is the activity's subject" do
    author = fake_user!("article_feed_author")

    Bonfire.Articles.Fake.fake_article!(author, "public", %{
      post_content: %{
        name: "Article by the subject #{System.unique_integer()}",
        html_body: "The article body"
      }
    })

    conn(user: author)
    |> visit("/@#{author.character.username}")
    |> assert_has("[data-id=activity_article]")
    |> refute_has("[data-id=activity_article] [data-role=article_byline]")
  end

  test "an article reading view has no byline when its author is the activity's subject" do
    author = fake_user!("article_byline_author")

    article =
      Bonfire.Articles.Fake.fake_article!(author, "public", %{
        post_content: %{
          name: "Article with a constrained byline",
          html_body: "The article body"
        }
      })

    conn(user: author)
    |> visit("/discussion/#{article.id}")
    |> assert_has("[data-id=activity_article]")
    |> refute_has("[data-id=activity_article] [data-role=article_byline]")
  end
end
