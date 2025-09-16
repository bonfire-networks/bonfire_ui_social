defmodule Bonfire.UI.Social.ExportController do
  use Bonfire.UI.Common.Web, :controller

  alias NimbleCSV.RFC4180, as: CSV

  # TODO: move some of the logic to backend module(s)

  def csv_download(conn, %{"type" => type} = params) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"export_#{type}.csv\"")
    |> put_root_layout(false)
    |> send_chunked(:ok)
    # |> send_resp(200, csv_content(conn, type))
    |> csv_content(type, scope: params["scope"])
    |> from_ok()
  end

  def json_download(conn, %{"type" => type} = params) do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", "attachment; filename=\"export_#{type}.json\"")
    |> put_root_layout(false)
    |> send_chunked(:ok)
    # |> send_resp(200, csv_content(conn, type))
    |> json_content(type, scope: params["scope"])
    |> from_ok()
  end

  def binary_download(conn, %{"type" => type, "ext" => ext} = _params) do
    conn
    |> put_resp_content_type("application/octet-stream")
    |> put_resp_header("content-disposition", "attachment; filename=\"export_#{type}.#{ext}\"")
    |> put_root_layout(false)
    |> send_chunked(:ok)
    # |> send_resp(200, csv_content(conn, type))
    |> binary_content(type)
    |> from_ok()
  end

  def archive_export(conn, _params) do
    conn
    |> put_resp_content_type("application/zip")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"bonfire_export_archive.zip\""
    )
    |> put_root_layout(false)
    |> send_chunked(:ok)
    # |> send_resp(200, csv_content(conn, type))
    |> zip_archive(current_user_required!(conn))
    |> from_ok()
  end

  def archive_download(conn, _params) do
    current_user = current_user_required!(conn)
    file = zip_filename(id(current_user))

    conn
    |> put_resp_content_type("application/zip")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"bonfire_export_archive.zip\""
    )
    |> put_root_layout(false)
    |> Plug.Conn.send_file(200, file)
  end

  def archive_delete(conn, _params) do
    current_user = current_user_required!(conn)
    _file = archive_delete(id(current_user))

    conn
    |> Plug.Conn.send_resp(200, "Deleted")
  end

  def archive_exists?(current_user_id) when is_binary(current_user_id) do
    file = zip_filename(current_user_id)

    File.exists?(file)
  end

  def archive_delete(current_user_id) when is_binary(current_user_id) do
    file = zip_filename(current_user_id)

    File.rm!(file)
  end

  def archive_previous_date(current_user_id) when is_binary(current_user_id) do
    file = zip_filename(current_user_id)

    with {:ok, %{ctime: date}} <- File.stat(file, time: :posix) do
      date
      |> DateTime.from_unix!()
      |> debug
      |> DateTime.diff(DateTime.utc_now(), :day)
      |> debug
    else
      _ ->
        false
    end
  end

  def trigger_prepare_archive_async(context) do
    current_user = current_user_required!(context)

    apply_task(:start, fn ->
      # Process.sleep(5000) # for debug only
      Bonfire.UI.Social.ExportController.zip_archive(context, current_user)
    end)
  end

  def zip_archive(conn_or_context, user) do
    # name = String.trim_trailing("bonfire_export", ".zip")

    Zstream.zip(
      [
        Zstream.entry("actor.json", [actor(user)]),
        Zstream.entry("outbox.json", [
          collection_header("outbox"),
          from_ok(outbox(user)),
          collection_footer()
        ]),
        Zstream.entry("following.csv", csv_with_headers(user, "following")),
        Zstream.entry("requests.csv", csv_with_headers(user, "requests")),
        Zstream.entry("followers.csv", csv_with_headers(user, "followers")),
        Zstream.entry("posts.csv", csv_with_headers(user, "posts")),
        Zstream.entry("messages.csv", csv_with_headers(user, "messages")),
        Zstream.entry("bookmarks.csv", from_ok(csv_content(user, "bookmarks"))),
        Zstream.entry("likes.csv", from_ok(csv_content(user, "likes"))),
        Zstream.entry("boosts.csv", from_ok(csv_content(user, "boosts"))),
        Zstream.entry("circles.csv", from_ok(csv_content(user, "circles"))),
        Zstream.entry("ghosted.csv", csv_with_headers(user, "ghosted")),
        Zstream.entry("silenced.csv", csv_with_headers(user, "silenced")),
        Zstream.entry("keys.asc", [keys(user)])
      ] ++
        for {path, uri} <- user_media(user) |> debug("user_mediaaa") do
          media_stream(path, uri, &Zstream.entry/2) || []
        end
    )
    |> zip_stream_process(id(user), conn_or_context)
  end

  defp zip_stream_process(stream, _, %Plug.Conn{} = conn) do
    stream
    |> Enum.reduce_while(conn, fn result, conn ->
      case maybe_chunk(conn, result) do
        {:ok, conn} ->
          {:cont, conn}

        other ->
          IO.inspect(other, label: "unexpected zip_stream_process with conn")
          {:halt, conn}
      end
    end)
  end

  defp zip_stream_process(stream, user_id, context) do
    {path, file} = zip_path_file(user_id)

    # just in case
    File.rm(file)

    with :ok <- File.mkdir_p(path),
         :ok <-
           stream
           |> Stream.into(File.stream!(file))
           |> Stream.run() do
      Bonfire.UI.Common.PersistentLive.notify(context, %{
        title: l("Your archive is ready"),
        message:
          "<a href='/settings/export/archive_download' download class='btn btn-success'>Download it here</a>"
      })

      :ok
    else
      other ->
        IO.inspect(other, label: "unexpected zip_stream_process without conn")

        Bonfire.UI.Common.PersistentLive.notify(context, %{
          title: l("Error preparing your archive"),
          message: inspect(other)
        })
    end
  end

  defp zip_path_file(user_id) do
    path = "/tmp/#{user_id}"

    {path, "#{path}/archive.zip"}
  end

  defp zip_filename(user_id) do
    {_path, file} =
      zip_path_file(user_id)
      |> debug()

    file
  end

  def create_json_stream(current_user, type, opts) do
    # Create a stream that mimics what json_content does but returns iodata
    Stream.concat([
      [collection_header(type)],
      json_inside_content(current_user, type, opts),
      [collection_footer()]
    ])
  end

  defp json_content(conn_or_user, type, opts \\ [])

  defp json_content(conn_or_user, type, opts) when type in ["thread", "outbox"] do
    {:ok, conn_or_user} = maybe_chunk(conn_or_user, collection_header(type))

    result = json_inside_content(conn_or_user, type, opts)

    case result do
      {:ok, conn} ->
        {:ok, final_conn} = maybe_chunk(conn, collection_footer())
        final_conn

      other ->
        other
    end
  end

  defp json_content(conn_or_user, "actor" = _type, _opts) do
    {:ok, _conn} = maybe_chunk(conn_or_user, actor(conn_or_user))
  end

  defp json_inside_content(conn_or_user, "outbox", opts) do
    outbox(conn_or_user, opts)
  end

  defp json_inside_content(conn_or_user, "thread", opts) do
    thread(conn_or_user, opts)
  end

  defp binary_content(conn_or_user, "private_key" = _type) do
    {:ok, _conn} = maybe_chunk(conn_or_user, fetch_private_key(conn_or_user))
  end

  defp binary_content(conn_or_user, "keys" = _type) do
    {:ok, _conn} = maybe_chunk(conn_or_user, keys(conn_or_user))
  end

  def outbox(conn_or_user, opts \\ []) do
    Process.put(:federating, :manual)

    user = current_user(conn_or_user)

    feed_id =
      Bonfire.Social.Feeds.feed_id(:outbox, user)
      |> debug("outbox feed")

    Bonfire.Social.FeedLoader.feed_filtered(
      # :user_activities,
      feed_id,
      %{exclude_activity_types: [], exclude_object_types: [], exclude_verb_ids: []},
      opts
      |> Keyword.merge(
        current_user: user,
        # by: user,
        paginate: false,
        preload: [],
        query_with_deferred_join: false,
        # select_only_activity_id: true,
        exclude_activity_types: [],
        exclude_object_types: [],
        exclude_verb_ids: [],
        return: :stream,
        stream_callback: fn stream ->
          stream
          |> debug("outbox stream")

          stream_callback("outbox", stream, conn_or_user)
        end
      )
    )
    |> debug("outbox res")
  end

  def thread(current_user, opts \\ []) do
    Process.put(:federating, :manual)

    limit = 5_000

    case (opts[:replies] ||
            Bonfire.Social.Threads.list_replies(
              opts[:thread_id],
              opts
              |> Keyword.merge(
                current_user: current_user,
                preload: [],
                select_only_activity_id: true,
                paginate: false,
                limit: limit,
                max_depth: limit,
                # sort_by: sort_by
                return: :stream,
                stream_callback: fn stream ->
                  stream_callback("collection", stream, opts)
                end
              )
            ))
         |> debug("threeead") do
      %{edges: replies} when replies != [] ->
        stream_callback("collection", replies, opts)

      replies when is_list(replies) and replies != [] ->
        stream_callback("collection", replies, opts)

      other ->
        debug(other, "ressss")
    end
  end

  # Simple helper for zip files that includes headers
  defp csv_with_headers(user, type, opts \\ []) do
    header = [csv_header_for_type(type)] |> CSV.dump_to_iodata()
    data = csv_content(user, type, opts) |> from_ok()
    [header, data]
  end

  # Extract header definitions to avoid duplication
  defp csv_header_for_type("following"), do: ["Account address"]
  defp csv_header_for_type("followers"), do: ["Account address"]
  defp csv_header_for_type("requests"), do: ["Account address"]
  defp csv_header_for_type("posts"), do: ["ID", "Date", "CW", "Summary", "Text"]
  defp csv_header_for_type("messages"), do: ["ID", "Date", "From", "To", "CW", "Summary", "Text"]
  # defp csv_header_for_type("bookmarks"), do: ["URI"] #, "Date", "Author", "Text"]
  defp csv_header_for_type(type) when type in ["silenced", "ghosted", "blocked"],
    do: ["Account address"]

  defp csv_content(conn, type, opts \\ [])

  defp csv_content(conn, "following" = type, _opts) do
    fields = csv_header_for_type(type)
    current_user = current_user_required!(conn)

    {:ok, conn} =
      if is_struct(conn, Plug.Conn) do
        maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())
      end || {:ok, conn}

    Utils.maybe_apply(
      Bonfire.Social.Graph.Follows,
      :list_my_followed,
      [
        current_user,
        [
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ]
    )
  end

  defp csv_content(conn, "followers" = type, _opts) do
    fields = csv_header_for_type(type)
    current_user = current_user_required!(conn)

    {:ok, conn} =
      if is_struct(conn, Plug.Conn) do
        maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())
      end || {:ok, conn}

    Utils.maybe_apply(
      Bonfire.Social.Graph.Follows,
      :list_my_followers,
      [
        current_user,
        [
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ]
    )
  end

  defp csv_content(conn, "requests" = type, _opts) do
    fields = csv_header_for_type(type)
    current_user = current_user_required!(conn)

    {:ok, conn} =
      if is_struct(conn, Plug.Conn) do
        maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())
      end || {:ok, conn}

    Utils.maybe_apply(
      Bonfire.Social.Requests,
      :list_my_requested,
      [
        [
          current_user: current_user,
          type: Bonfire.Data.Social.Follow,
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ]
    )
  end

  defp csv_content(conn, "bookmarks" = type, _opts) do
    current_user = current_user_required!(conn)

    # no headers
    # fields = csv_header_for_type(type)
    # {:ok, conn} =
    #   if is_struct(conn, Plug.Conn) do
    #     maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())
    #   end || {:ok, conn}

    Utils.maybe_apply(
      Bonfire.Social.Bookmarks,
      :list_by,
      [
        current_user,
        [
          current_user: current_user,
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ],
      fallback_return: []
    )
  end

  defp csv_content(conn, "likes" = type, _opts) do
    current_user = current_user_required!(conn)

    Utils.maybe_apply(
      Bonfire.Social.Likes,
      :list_my,
      [
        [
          current_user: current_user,
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ],
      fallback_return: []
    )
  end

  defp csv_content(conn, "boosts" = type, _opts) do
    current_user = current_user_required!(conn)

    Utils.maybe_apply(
      Bonfire.Social.Boosts,
      :list_my,
      [
        [
          current_user: current_user,
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ],
      fallback_return: []
    )
  end

  defp csv_content(conn, "posts" = type, _opts) do
    fields = csv_header_for_type(type)
    current_user = current_user_required!(conn)

    {:ok, conn} =
      if is_struct(conn, Plug.Conn) do
        maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())
      end || {:ok, conn}

    Utils.maybe_apply(
      Bonfire.Posts,
      :list_by,
      [
        current_user,
        [
          current_user: current_user,
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ]
    )
  end

  defp csv_content(conn, "messages" = type, _opts) do
    fields = csv_header_for_type(type)
    current_user = current_user_required!(conn)

    {:ok, conn} =
      if is_struct(conn, Plug.Conn) do
        maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())
      end || {:ok, conn}

    Utils.maybe_apply(
      Bonfire.Messages,
      :list,
      [
        current_user,
        nil,
        [
          paginate: false,
          return: :stream,
          stream_callback: fn stream ->
            stream_callback(type, stream, conn)
          end
        ]
      ],
      fallback_return: []
    )

    # |> IO.inspect(label: "msgs")
  end

  defp csv_content(conn, type, opts) when type in ["silenced", "ghosted", "blocked"] do
    fields = csv_header_for_type(type)
    current_user = current_user_required!(conn)

    block_type =
      case type do
        "ghosted" -> :ghost
        "silenced" -> :silence
        "blocked" -> [:ghost, :silence]
      end

    {:ok, conn} =
      if is_struct(conn, Plug.Conn) do
        maybe_chunk(conn, [fields] |> CSV.dump_to_iodata())
      end || {:ok, conn}

    if to_string(opts[:scope]) == "instance_wide" do
      Bonfire.Boundaries.Blocks.instance_wide_circles(block_type)
      |> List.first()
      |> Bonfire.Boundaries.Circles.get_for_instance()
    else
      Bonfire.Boundaries.Blocks.user_block_circles(current_user, block_type)
      |> List.first()
    end
    |> repo().maybe_preload(encircles: [subject: [:character]])
    |> e(:encircles, [])
    |> prepare_rows(type, ...)
    # |> IO.inspect(label: "bloq")
    |> maybe_chunk(conn, ...)
  end

  defp csv_content(conn, "circles" = type, _opts) do
    current_user = current_user_required!(conn)

    # TODO: only load the assocs/fields we need
    # Get all circles and their members, then flatten for direct processing (like blocks)
    circles = Bonfire.Boundaries.Circles.list_my(current_user, exclude_stereotypes: true)

    all_memberships =
      Enum.flat_map(circles, fn circle ->
        members = Bonfire.Boundaries.Circles.list_members(circle, paginate: false)

        Enum.map(members, fn member ->
          %{
            circle: e(circle, :named, :name, nil) || "Unnamed Circle",
            member: Bonfire.Me.Characters.display_username(e(member, :subject, nil), true)
          }
        end)
      end)

    # Process directly like blocks export does
    all_memberships
    |> prepare_rows(type, ...)
    |> maybe_chunk(conn, ...)
  end

  defp csv_content(conn, type, opts) do
    error(type, "CSV export type not implemented")
    conn
  end

  defp stream_callback(type, stream, %Plug.Conn{} = conn) do
    Enum.reduce_while(stream, conn, fn result, conn ->
      case maybe_chunk(conn, prepare_rows(type, result)) do
        {:ok, conn} ->
          {:cont, conn}

        other ->
          error(other, "unexpected stream_callback")
          {:halt, conn}
      end
    end)
  end

  defp stream_callback(type, stream, _user) do
    prepare_rows(type, stream)
  end

  defp maybe_chunk(%Plug.Conn{} = conn, data) do
    Plug.Conn.chunk(conn, data)
  end

  defp maybe_chunk(_conn, data) do
    {:ok, data}
  end

  defp prepare_rows(type, records) when type in ["outbox", "collection"] and is_list(records) do
    records
    |> preload_assocs(type)
    |> Enum.map(&prepare_record_json(type, &1))
  end

  defp prepare_rows(type, %Stream{} = stream) when type in ["outbox", "collection"] do
    stream
    |> Enum.map(&prepare_record_json(type, &1 |> preload_assocs(type)))
  end

  defp prepare_rows(type, record) when type in ["outbox", "collection"] do
    prepare_record_json(type, record |> preload_assocs(type))
  end

  defp prepare_rows(type, records) when is_list(records) do
    records |> preload_assocs(type) |> Enum.map(&prepare_record(type, &1)) |> prepare_csv()
  end

  defp prepare_rows(type, %Stream{} = stream) do
    stream
    |> Enum.map(&prepare_record(type, &1))
    |> prepare_csv()
  end

  defp prepare_rows(type, record) when is_struct(record) do
    [prepare_record(type, record)]
    |> prepare_csv()
  end

  defp preload_assocs(records, type) when type in ["following", "requests"] do
    records |> repo().preload(edge: [object: [:character]])
  end

  defp preload_assocs(records, type) when type in ["followers"] do
    records |> repo().preload(edge: [subject: [:character]])
  end

  defp preload_assocs(records, type) when type in ["messages"] do
    # records |> repo().preload([:post_content, :peered, created: [creator: [:character]]])

    Bonfire.Social.Activities.activity_preloads(
      records,
      [:with_post_content, :with_subject, :with_reply_to, :tags],
      skip_boundary_check: true
    )
  end

  defp preload_assocs(records, type) when type in ["posts"] do
    records |> repo().preload([:post_content, :peered])
  end

  defp preload_assocs(records, type) when type in ["bookmarks", "likes", "boosts"] do
    records
    # object: [:post_content, :created]])
    |> repo().preload(edge: [:object])
  end

  defp preload_assocs(records, type) when type in ["outbox"] do
    records |> repo().preload([:activity])
  end

  defp preload_assocs(records, _type) do
    records
  end

  defp prepare_record(type, record) when type in ["following", "requests"] do
    [
      record
      |> preload_assocs(type)
      |> e(:edge, :object, nil)
      |> Bonfire.Me.Characters.display_username(true)
    ]
  end

  defp prepare_record(type, record) when type in ["followers"] do
    [
      record
      |> preload_assocs(type)
      |> e(:edge, :subject, nil)
      |> Bonfire.Me.Characters.display_username(true)
    ]
  end

  defp prepare_record(type, record) when type in ["silenced", "ghosted"] do
    [
      record
      |> e(:subject, nil)
      |> Bonfire.Me.Characters.display_username(true)
    ]
  end

  defp prepare_record(type, record) when type in ["posts"] do
    record =
      record
      |> preload_assocs(type)

    # |> debug()

    [
      URIs.canonical_url(record),
      DatesTimes.date_from_pointer(record),
      e(record, :post_content, :name, nil),
      e(record, :post_content, :summary, nil),
      e(record, :post_content, :html_body, nil)
    ]
  end

  defp prepare_record(type, record) when type in ["messages"] do
    record =
      record
      |> preload_assocs(type)
      |> debug()

    participants =
      Utils.maybe_apply(
        Bonfire.Messages.LiveHandler,
        :thread_participants,
        [nil, record, nil, []]
      )
      |> debug()

    msg = e(record, :activity, :object, :post_content, nil) || e(record, :post_content, nil)

    [
      URIs.canonical_url(record),
      DatesTimes.date_from_pointer(record),
      e(record, :activity, :subject, :character, :username, nil),
      Enum.map(participants, &e(&1, :character, :username, nil)) |> Enum.join(" ; "),
      e(msg, :name, nil),
      e(msg, :summary, nil),
      e(msg, :html_body, nil)
    ]
  end

  defp prepare_record(type, record) when type in ["bookmarks", "likes", "boosts"] do
    record =
      record
      |> preload_assocs(type)

    record = e(record, :edge, :object, nil) || record

    [
      URIs.canonical_url(record)
      # DatesTimes.date_from_pointer(bookmarked_object),
      # e(bookmarked_object, :created, :creator, :character, :username, nil),
      # e(bookmarked_object, :post_content, :html_body, nil)
    ]
  end

  defp prepare_record(type, record) when type in ["circles"] do
    [e(record, :circle, nil), e(record, :member, nil)]
  end

  defp prepare_record_json(_type \\ nil, record) do
    case object_json(record, true) do
      {:ok, json} ->
        """
        #{json},
        """

      _ ->
        ""
    end
    |> debug("jsoon")
  end

  def object_json(record, skip_json_context_header \\ false) do
    debug(record, "an_act")

    cond do
      e(record, :activity, :verb_id, nil) == "4REATE0RP0STBRANDNEW0BJECT" ->
        # Get the object from the activity, then get its AP ID, then find the corresponding ActivityPub Create activity

        with {:ok, object} <- ActivityPub.Object.get_cached(pointer: record),
             ap_object_id when is_binary(ap_object_id) <- e(object, :data, "id", nil),
             ap_activity when not is_nil(ap_activity) <-
               ActivityPub.Object.get_activity_for_object_ap_id(ap_object_id, "Create") do
          do_object_json(ap_activity, skip_json_context_header)
        else
          e ->
            error(e)
            do_object_json(id(record), skip_json_context_header)
        end

      true ->
        do_object_json(id(record), skip_json_context_header)
    end

    # |> debug("jssson")
  end

  defp do_object_json(activity, skip_json_context_header \\ false) do
    ActivityPub.Web.ActivityPubController.json_object_with_cache(nil, activity,
      exporting: true,
      skip_json_context_header: skip_json_context_header
    )
  end

  defp prepare_csv(records) do
    records
    |> CSV.dump_to_iodata()

    # |> IO.iodata_to_binary()
  end

  defp actor(conn_or_user) do
    with {:ok, actor} = ActivityPub.Actor.get_cached(pointer: current_user(conn_or_user)),
         {:ok, json} <-
           ActivityPub.Web.ActorView.render("actor.json", %{actor: actor})
           #    |> Map.merge(%{"likes" => "likes.json", "bookmarks" => "bookmarks.json"})
           |> Jason.encode() do
      json
    end
  end

  defp fetch_private_key(conn_or_user) do
    current_user = current_user(conn_or_user)

    {:ok, actor} =
      ActivityPub.Actor.get_cached(pointer: current_user)
      ~> ActivityPub.Safety.Keys.ensure_keys_present()

    # |> debug("actor to sure a key exists")

    e(actor, :keys, nil)
    # |> debug("made sure a key exists")

    # current_user
    # |> repo().maybe_preload(character: [:actor], force: true)
    # |> e(:character, :actor, :signing_key, nil)
    # |> debug("private key")
  end

  defp keys(conn_or_user) do
    keys = fetch_private_key(conn_or_user)

    """
    #{keys}

    #{from_ok(ActivityPub.Safety.Keys.public_key_from_data(%{keys: keys}))}
    """
  end

  defp collection_header(name) do
    """
    {
      "@context": #{ActivityPub.Utils.make_json_ld_context_list(:object) |> Jason.encode!()},
      "id": "#{name}.json",
      "type": "OrderedCollection",
      "orderedItems": [
    """
  end

  defp collection_footer() do
    # includes an empty object to support trailing commas
    "\n  {}]\n}"
  end

  def user_media(user) do
    user_id = id(user)

    Bonfire.Files.Media.many(creator: user_id)
    ~> Enum.map(fn
      %{path: "http" <> _ = uri, id: id} = _media ->
        {"/data/links/#{id}.html", uri}

      %{file: %{id: path} = locator} = _media ->
        # debug(path)
        {path, locator}

      media ->
        path =
          case Bonfire.Files.remote_url(media)
               |> debug() do
            nil -> nil
            path -> String.trim(path, "/")
          end

        if not is_nil(path) and File.exists?(path), do: {path, path}
    end)
    |> Enum.filter(fn
      {_path, _locator} -> true
      _ -> false
    end)
    |> Enums.filter_empty([])
  end

  def media_stream(path, "http" <> _ = uri, fun) do
    fun.(path, ["<!DOCTYPE HTML>
    <html>
      <head>
        <title>Automatic redirect to #{uri}</title>
        <meta http-equiv=\"refresh\" content=\"0; url=#{uri}\" />
      </head>
      <body>
        <h3>Automatic redirect to #{uri}</h3>
        <p><a href=\"#{uri}\">For older browsers, click here</a></p>
      </body>
    </html>"])
  end

  # def media_stream(path, %Entrepot.Locator{storage: storage} = locator, fun) when storage in [Entrepot.Storages.Disk, "Elixir.Entrepot.Storages.Disk"] do
  #  # stream files from Disk
  #   path = Entrepot.Storages.Disk.path(locator)

  #   if is_binary(path) and File.exists?(path) do
  #     fun.(path, File.stream!(path, [], 512))
  #   else
  #     fun.("#{path}.txt", ["File not found"])
  #   end
  # end
  def media_stream(path, %struct{id: id} = locator, fun) when struct == Entrepot.Locator do
    # stream files from Disk or S3 with error handling
    try do
      source_storage = Entrepot.storage!(locator)

      case source_storage.stream(id) do
        nil ->
          warn(path, "File not found in storage")
          fun.("#{path}.txt", ["File not found"])

        stream ->
          fun.(path, stream)
      end
    rescue
      error in ExAws.Error ->
        warn(error, "Could not access file #{path} from S3, skipping")

        fun.("#{path}.txt", ["File could not be downloaded from cloud storage: #{inspect(error)}"])

      error ->
        warn(error, "Unexpected error accessing file #{path}, skipping")
        fun.("#{path}.txt", ["File could not be accessed: #{inspect(error)}"])
    end
  end

  # def media_stream(path, %Entrepot.Locator{} = locator, fun) do
  #  # copy S3 files to Disk
  #   with {:ok, new_locator} <- Entrepot.copy(locator, Entrepot.Storages.Disk, skip_existing: true)
  #     |> debug() do
  #     media_stream(path, new_locator, fun)
  #   else
  #     {:error, error} when is_binary(error) -> fun.("#{path}.txt", [error])
  #     other -> raise other
  #   end
  # end
  def media_stream(path, path, fun) when is_binary(path) do
    try do
      if File.exists?(path) do
        fun.(path, File.stream!(path, [], 512))
      else
        warn(path, "Local file not found")
        fun.("#{path}.txt", ["Local file not found"])
      end
    rescue
      error ->
        warn(error, "Could not read local file #{path}, skipping")
        fun.("#{path}.txt", ["File could not be read: #{inspect(error)}"])
    end
  end

  # defp likes(user) do
  #   user.ap_id
  #   |> Activity.Queries.by_actor()
  #   |> Activity.Queries.by_type("Like")
  #   |> select([like], %{id: like.id, object: fragment("(?)->>'object'", like.data)})
  #   |> output("likes", fn a -> {:ok, a.object} end)
  # end
end
