defmodule Postern.DocumentStoreTest do
  use ExUnit.Case, async: true

  alias Postern.DocumentStore

  describe "apply_changes/2" do
    test "a change without a range replaces the document" do
      assert DocumentStore.apply_changes("old\n", [%{text: "new\n"}]) == "new\n"
    end

    test "a ranged change replaces only its span" do
      text = "host all all all trust\n"
      insert = %{range: range({0, 0}, {0, 0}), text: "\n"}
      assert DocumentStore.apply_changes(text, [insert]) == "\nhost all all all trust\n"

      edit = %{range: range({1, 17}, {1, 22}), text: "md5"}
      assert DocumentStore.apply_changes("\n" <> text, [edit]) == "\nhost all all all md5\n"
    end

    test "changes apply in order and positions count UTF-16 units" do
      changes = [
        %{"range" => range({0, 2}, {0, 2}), "text" => "\u{1F600}"},
        %{range: range({0, 4}, {0, 4}), text: "!"}
      ]

      assert DocumentStore.apply_changes("ab\n", changes) == "ab\u{1F600}!\n"
    end

    test "a position past the end of the document means its end" do
      assert DocumentStore.apply_changes("a\n", [%{range: range({5, 0}, {5, 0}), text: "b"}]) ==
               "a\nb"
    end
  end

  defp range({line, character}, {end_line, end_character}) do
    %{
      start: %{line: line, character: character},
      end: %{line: end_line, character: end_character}
    }
  end
end
