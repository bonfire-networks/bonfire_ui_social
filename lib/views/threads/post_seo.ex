defimpl SEO.Site.Build, for: Bonfire.Data.Social.PostContent do
  use Bonfire.UI.Common

  def build(post_content, _conn) do
    debug(post_content)

    SEO.Site.build(
      title:
        e(post_content, :title, nil) ||
          e(post_content, :activity, :replied, :thread, :named, :name, nil),
      description: e(post_content, :summary, nil)
    )
  end

  # def unfurl(_page) do
  #   SEO.Unfurl.build([])
  # end
end

# defimpl SEO.Twitter.Build, for: Bonfire.Data.Social.PostContent do
#   use Bonfire.UI.Common

#   def build(post_content, _conn) do
#     SEO.Twitter.build(
#       creator: e(post_content, :pointer, :created, :creator, nil)
#     )
#   end
# end

defimpl SEO.OpenGraph.Build, for: Bonfire.Data.Social.PostContent do
  use Bonfire.UI.Common

  def build(post_content, _conn) do
    SEO.OpenGraph.build(
      title:
        e(post_content, :title, nil) ||
          e(post_content, :activity, :replied, :thread, :named, :name, nil),
      detail:
        SEO.OpenGraph.Article.build(
          published_time: DatesTimes.date_from_pointer(post_content),
          # e(post_content, :pointer, :created, :creator, :profile, :name, nil) ||
          author: e(post_content, :pointer, :created, :creator, :character, :username, nil),
          section: "Posts"
          # tag: post_content.tags
        ),
      # image: put_image(post_content),
      # url: Pages.page_path(post_content),
      # locale: "en_US",
      type: :article,
      description: e(post_content, :summary, nil)
    )
  end
end

# defimpl SEO.Breadcrumb.Build, for: Bonfire.Data.Social.PostContent do
#   use Bonfire.UI.Common
#   alias Bonfire.Pages

#   def build(post_content, _conn) do
#     SEO.Breadcrumb.List.build(
#       [name: "Posts", item: "/posts"],
#       [name: e(post_content, :title, nil), 
#       #item: Pages.page_path(post_content)
#     ]
#     )
#   end
# end

# defp put_image(post_content) do
#   file = "/images/blog/#{post_content.id}.png"

#   exists? =
#     [Application.app_dir(:my_app), "/priv/static", file]
#     |> Path.join()
#     |> File.exists?()

#   if exists? do
#     Routes.static_url(@endpoint, file), image_alt: post_content.title}
#   else
#     nil
#   end
# end
