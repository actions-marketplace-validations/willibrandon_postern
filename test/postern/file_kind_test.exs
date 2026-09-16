defmodule Postern.FileKindTest do
  use ExUnit.Case, async: true

  alias Postern.FileKind

  describe "detect/1" do
    test "postgresql.conf" do
      assert FileKind.detect("file:///etc/postgresql/postgresql.conf") == :postgresql_conf
      assert FileKind.detect("/var/lib/postgresql.conf") == :postgresql_conf
    end

    test "postgresql.auto.conf" do
      assert FileKind.detect("file:///tmp/postgresql.auto.conf") == :postgresql_conf
    end

    test "pg_hba.conf" do
      assert FileKind.detect("file:///etc/pg_hba.conf") == :pg_hba_conf
      assert FileKind.detect("/etc/postgresql/15/main/pg_hba.conf") == :pg_hba_conf
    end

    test "pg_ident.conf" do
      assert FileKind.detect("file:///etc/pg_ident.conf") == :pg_ident_conf
    end

    test "unknown" do
      assert FileKind.detect("file:///home/user/file.txt") == :unknown
      assert FileKind.detect("file:///tmp/other.conf") == :unknown
    end

    test "handles file URIs with encoded paths" do
      assert FileKind.detect("file:///etc/postgresql/postgresql.conf") == :postgresql_conf
    end
  end

  describe "uri_to_path/1" do
    test "strips file:// prefix" do
      assert FileKind.uri_to_path("file:///tmp/pg_hba.conf") == "/tmp/pg_hba.conf"
      assert FileKind.uri_to_path("/tmp/pg_hba.conf") == "/tmp/pg_hba.conf"
    end
  end
end
