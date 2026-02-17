defmodule Lantern.Projects.ScannerTest do
  use ExUnit.Case, async: true

  alias Lantern.Projects.Scanner

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "lantern_scanner_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    on_cleanup(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  defp on_cleanup(fun) do
    ExUnit.Callbacks.on_exit(fun)
  end

  describe "scan_root/1" do
    test "finds only manifest-backed project directories", %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "project-a"))
      File.mkdir_p!(Path.join(tmp_dir, "project-b"))
      File.mkdir_p!(Path.join(tmp_dir, "project-c"))
      File.write!(Path.join(tmp_dir, "project-a/lantern.yaml"), "name: project-a\n")
      File.write!(Path.join(tmp_dir, "project-b/lantern.yml"), "name: project-b\n")
      File.write!(Path.join(tmp_dir, "not-a-dir.txt"), "hello")

      results = Scanner.scan_root(tmp_dir)
      assert length(results) == 2
      assert Path.join(tmp_dir, "project-a") in results
      assert Path.join(tmp_dir, "project-b") in results
      refute Path.join(tmp_dir, "project-c") in results
    end

    test "skips hidden directories", %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "visible-project"))
      File.write!(Path.join(tmp_dir, "visible-project/lantern.yaml"), "name: visible-project\n")
      File.mkdir_p!(Path.join(tmp_dir, ".hidden-dir"))
      File.write!(Path.join(tmp_dir, ".hidden-dir/lantern.yaml"), "name: hidden\n")
      File.mkdir_p!(Path.join(tmp_dir, ".git"))

      results = Scanner.scan_root(tmp_dir)
      assert length(results) == 1
      assert Path.join(tmp_dir, "visible-project") in results
    end

    test "skips node_modules and vendor", %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "my-project"))
      File.write!(Path.join(tmp_dir, "my-project/lantern.yaml"), "name: my-project\n")
      File.mkdir_p!(Path.join(tmp_dir, "node_modules"))
      File.write!(Path.join(tmp_dir, "node_modules/lantern.yaml"), "name: node-modules\n")
      File.mkdir_p!(Path.join(tmp_dir, "vendor"))
      File.write!(Path.join(tmp_dir, "vendor/lantern.yaml"), "name: vendor\n")

      results = Scanner.scan_root(tmp_dir)
      assert length(results) == 1
    end

    test "returns empty list for nonexistent directory" do
      results = Scanner.scan_root("/nonexistent/path")
      assert results == []
    end
  end
end
