defmodule Lantern.Projects.PortAllocatorTest do
  use ExUnit.Case

  alias Lantern.Projects.PortAllocator

  # The PortAllocator and Store are started by the application supervisor.
  # We use the existing instances and just clean up assignments between tests.

  setup do
    # Clean up any existing assignments
    for {name, _port} <- PortAllocator.assignments() do
      PortAllocator.release(name)
    end

    :ok
  end

  describe "allocate/1" do
    test "allocates a port for a project" do
      assert {:ok, port} = PortAllocator.allocate("test-project")
      assert is_integer(port)
      assert port >= 41000
      assert port <= 42000
    end

    test "returns same port for same project" do
      {:ok, port1} = PortAllocator.allocate("test-project")
      {:ok, port2} = PortAllocator.allocate("test-project")
      assert port1 == port2
    end

    test "allocates different ports for different projects" do
      {:ok, port1} = PortAllocator.allocate("project-a")
      {:ok, port2} = PortAllocator.allocate("project-b")
      assert port1 != port2
    end
  end

  describe "release/1" do
    test "releases a port assignment" do
      {:ok, _port} = PortAllocator.allocate("test-project")
      assert :ok = PortAllocator.release("test-project")
      assert PortAllocator.get("test-project") == nil
    end
  end

  describe "get/1" do
    test "returns nil for unassigned project" do
      assert PortAllocator.get("unknown-project") == nil
    end

    test "returns port for assigned project" do
      {:ok, port} = PortAllocator.allocate("test-project")
      assert PortAllocator.get("test-project") == port
    end
  end

  describe "assignments/0" do
    test "returns all assignments" do
      {:ok, _} = PortAllocator.allocate("project-a")
      {:ok, _} = PortAllocator.allocate("project-b")
      assignments = PortAllocator.assignments()
      assert map_size(assignments) == 2
      assert Map.has_key?(assignments, "project-a")
      assert Map.has_key?(assignments, "project-b")
    end
  end
end
