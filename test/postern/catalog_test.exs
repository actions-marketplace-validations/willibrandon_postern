defmodule Postern.CatalogTest do
  use ExUnit.Case, async: true

  alias Postern.Catalog

  test "loads every generated major-version catalog" do
    assert Catalog.versions() == [13, 14, 15, 16, 17, 18]

    for version <- Catalog.versions() do
      catalog = Catalog.load(version)
      assert catalog.version == version
      assert map_size(catalog.settings) > 300

      assert Enum.all?(catalog.settings, fn {_name, setting} ->
               Enum.all?(Catalog.required_fields(), &Map.has_key?(setting, &1))
             end)
    end
  end

  test "selects the newest catalog and indexes setting rows by name" do
    assert Catalog.latest() == 18
    catalog = Catalog.load(16)
    assert Catalog.fetch(catalog, "shared_buffers")["vartype"] == "integer"
  end
end
