defmodule Bonfire.UI.Social.SmartInputLive do
  use Bonfire.UI.Common.Web, :stateful_component

  # prop user_image, :string, required: true
  # prop target_component, :string
  prop reply_to_id, :string, default: ""
  prop thread_id, :string, default: "", required: false
  prop create_activity_type, :any
  prop smart_input_component, :atom
  prop to_circles, :list
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
  prop full_screen, :boolean, default: false
  prop showing_within, :any
  prop with_rich_editor, :boolean, required: false
  prop activity, :any
  prop object, :any
  prop activity_inception, :any
  prop preset_boundary, :any, default: "public"
  prop title_open, :boolean, default: false
  prop title_prompt, :string

  # Classes to customize the smart input appearance
  prop textarea_class, :string, default: "textarea w-full prose prose-sm bg-slate-50 text-slate-800"
  prop smart_input_class, :string, default: "rounded-md shadow bg-slate-50"
  prop replied_activity_class, :string, default: "relative p-3 mb-2 rounded bg-base-100 hover:bg-base-100 hover:bg-opacity-100 showing_within:smart_input"


  def mount(socket),
    do: {:ok,
      socket
      |> assign(
        trigger_submit: false,
        uploaded_files: []
      )
      |> allow_upload(:files,
        accept: ~w(.jpg .jpeg .png .gif .svg .tiff .webp .pdf .md .rtf .mp3 .mp4), # make configurable
        max_file_size: 10_000_000, # make configurable, expecially once we have resizing
        max_entries: 10,
        auto_upload: false,
        # progress: &handle_progress/3
      )
    } # |> IO.inspect

  def all_smart_input_components do
    Bonfire.Common.Config.get([:ui, :smart_input_components], [post: Bonfire.UI.Social.WritePostContentLive])
  end

  def active_smart_input_component(assigns) do
    e(assigns, :smart_input_component, nil) || Bonfire.Common.Config.get([:ui, :default_smart_input]) || Bonfire.UI.Social.WritePostContentLive
  end

  def smart_input_name(component) do
    all_smart_input_components()
    |> Keyword.filter(fn {_key, val} -> val==component end)
    |> Keyword.keys()
    |> List.first()
    |> display_name()
  end

  defp display_name(name) do
    name
    |> maybe_to_string()
  end

  # defp handle_progress(_, entry, socket) do
  #   debug(entry, "progress")

  #   user = current_user(socket)

  #   if entry.done? and entry.valid? and user do
  #     with %{} = uploaded_media <-
  #       consume_uploaded_entry(socket, entry, fn %{path: path} = meta ->
  #         # debug(meta, "icon consume_uploaded_entry meta")
  #         Bonfire.Files.upload(nil, user, path)
  #         |> debug("uploaded")
  #       end) do
  #         # debug(uploaded_media)
  #         {:noreply,
  #           socket
  #           |> update(:uploaded_files, &(&1 ++ [uploaded_media]))
  #           |> put_flash(:info, l "File uploaded!")
  #         }
  #     end
  #   else
  #     {:noreply, socket}
  #   end
  # end


  # def update(%{activity: activity, object: object, reply_to_id: reply_to_id, thread_id: thread_id} = assigns, socket) do
  #   socket = assign(socket, activity: activity, reply_to_id: reply_to_id, thread_id: thread_id)
  #   {:ok, socket
  #   |> assign(assigns)
  #   }
  #   # {:ok, assign(socket, activity_id: activity_id)}
  # end

  # def update(%{activity: activity, object: object} = assigns, socket) do
  #   socket = assign(socket, activity: activity)
  #   {:ok, socket
  #   |> assign(assigns)
  #   }
  #   # {:ok, assign(socket, activity_id: activity_id)}
  # end

  # def update(assigns, socket) do
  #   IO.inspect(assigns, label: "HEHO")
  #   {:ok, socket |> assign(assigns)}
  # end

  def handle_event("select_smart_input", %{"component" => component}, socket) do
    {:noreply, socket
      |> assign(smart_input_component: maybe_to_module(component))
    }
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
  defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers


end
