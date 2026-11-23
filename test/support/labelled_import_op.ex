defmodule Bonfire.UI.Social.Test.LabelledImportOp do
  @moduledoc """
  Import ops only tests know, so a test can tell the import status page names a job from the op's own extension (see `Bonfire.Common.Import.op_label/1` and `op_phrase/1`), never from copies of its own. Test support compiles into the app in the test env, so it's discovered like any adopter.

  `test_labelled_import` has a label and a phrase the page has no copy of. `test_follow_labelled_import` shares its label with following ("Follow") but has a phrase of its own, so a page that picked the phrase by matching the label (which also breaks once labels are translated) would show the wrong one.
  """
  @behaviour Bonfire.Common.ImportModule

  @impl true
  def import_ops, do: ["test_labelled_import", "test_follow_labelled_import"]

  @impl true
  def import_op_label("test_labelled_import"), do: "Labelled by its extension"
  def import_op_label("test_follow_labelled_import"), do: "Follow"

  @impl true
  def import_op_phrase("test_labelled_import"), do: "Doing a labelled import"
  def import_op_phrase("test_follow_labelled_import"), do: "Doing something else than following"

  @impl true
  def perform_import(_op, _identifier, _opts), do: :ok
end
