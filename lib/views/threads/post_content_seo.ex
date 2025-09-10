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
    # IO.inspect(post_content, label: "post_contentsss")
    creator =
      e(post_content, :pointer, :created, :creator, nil) ||
        e(post_content, :activity, :subject, nil) ||
        e(post_content, :pointer, :created, :creator_id, nil) ||
        e(post_content, :activity, :subject_id, nil)

    author =
      Bonfire.Me.Characters.display_username(creator, true) || e(creator, :profile, :name, nil)

    title =
      e(post_content, :title, nil) ||
        e(post_content, :activity, :replied, :thread, :named, :name, nil)

    first_media = List.first(e(post_content, :activity, :media, []))

    SEO.OpenGraph.build(
      title: title,
      detail:
        SEO.OpenGraph.Article.build(
          published_time: DatesTimes.date_from_pointer(post_content),
          # e(post_content, :pointer, :created, :creator, :profile, :name, nil) ||
          author: author,
          section: "Posts"
          # tag: post_content.tags
        ),
      #  TODO: do not generate image for non-public posts
      image:
        Bonfire.UI.Common.SEOImage.generate_path(
          Enums.id(post_content),
          Enums.id(creator),
          title,
          e(post_content, :summary, nil) || e(post_content, :html_body, nil),
          author,
          Path.absname(
            String.trim_leading(
              from_ok(Media.thumbnail_url(first_media)) ||
                from_ok(Media.media_url(first_media)) || "",
              "/"
            )
          )
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
