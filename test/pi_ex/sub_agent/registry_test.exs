defmodule PiEx.SubAgent.RegistryTest do
  use ExUnit.Case, async: false

  alias PiEx.SubAgent.{Definition, Registry}

  # Each test uses unique names to avoid cross-test contamination since
  # the registry is a global ETS table.
  defp unique_name(base), do: "#{base}_#{System.unique_integer([:positive])}"

  defp def_for(name) do
    %Definition{name: name, description: "Test agent #{name}"}
  end

  describe "register/1 and lookup/1" do
    test "registers a definition and makes it findable by name" do
      name = unique_name("basic")
      :ok = Registry.register(def_for(name))
      assert {:ok, %Definition{name: ^name}} = Registry.lookup(name)
    end

    test "overwrites an existing entry when registered twice" do
      name = unique_name("overwrite")
      :ok = Registry.register(%Definition{name: name, description: "first"})
      :ok = Registry.register(%Definition{name: name, description: "second"})
      assert {:ok, %Definition{description: "second"}} = Registry.lookup(name)
    end

    test "returns :not_found for an unknown name" do
      assert :not_found = Registry.lookup("does_not_exist_#{System.unique_integer()}")
    end
  end

  describe "deregister/1" do
    test "removes a registered definition" do
      name = unique_name("remove")
      :ok = Registry.register(def_for(name))
      :ok = Registry.deregister(name)
      assert :not_found = Registry.lookup(name)
    end

    test "is a no-op for unknown names" do
      assert :ok = Registry.deregister("never_existed_#{System.unique_integer()}")
    end
  end

  describe "list/0" do
    test "includes all registered definitions" do
      n1 = unique_name("list_a")
      n2 = unique_name("list_b")
      :ok = Registry.register(def_for(n1))
      :ok = Registry.register(def_for(n2))

      names = Registry.list() |> Enum.map(& &1.name)
      assert n1 in names
      assert n2 in names
    end
  end
end
