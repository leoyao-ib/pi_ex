defmodule PiEx.DeepAgent.SkillsTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.{Skill, Skills}

  @moduletag :tmp_dir

  defp make_skill(root, name, description \\ "Does something") do
    dir = Path.join(root, name)
    File.mkdir_p!(dir)
    content = "---\nname: #{name}\ndescription: #{description}\n---\n"
    File.write!(Path.join(dir, "SKILL.md"), content)
    dir
  end

  describe "load_all/1" do
    test "returns empty list for nil" do
      assert {:ok, []} = Skills.load_all(nil)
    end

    test "returns error when skills_root does not exist" do
      assert {:error, reason} = Skills.load_all("/nonexistent/skills")
      assert reason =~ "skills_root"
    end

    test "loads a single skill from skills_root", %{tmp_dir: tmp} do
      make_skill(tmp, "my-skill")

      assert {:ok, [%Skill{name: "my-skill"}]} = Skills.load_all(tmp)
    end

    test "loads multiple skills", %{tmp_dir: tmp} do
      make_skill(tmp, "skill-a", "Does A")
      make_skill(tmp, "skill-b", "Does B")

      assert {:ok, skills} = Skills.load_all(tmp)
      names = Enum.map(skills, & &1.name) |> Enum.sort()
      assert names == ["skill-a", "skill-b"]
    end

    test "deduplicates skills with the same name, first wins", %{tmp_dir: tmp} do
      dir_a = Path.join(tmp, "group_a")
      dir_b = Path.join(tmp, "group_b")
      File.mkdir_p!(dir_a)
      File.mkdir_p!(dir_b)

      File.write!(Path.join(dir_a, "SKILL.md"), "---\nname: dupe\ndescription: First\n---\n")
      File.write!(Path.join(dir_b, "SKILL.md"), "---\nname: dupe\ndescription: Second\n---\n")

      assert {:ok, skills} = Skills.load_all(tmp)
      assert length(skills) == 1
      [skill] = skills
      assert skill.name == "dupe"
    end

    test "skips _build and deps directories", %{tmp_dir: tmp} do
      for ignored <- ["_build", "deps"] do
        dir = Path.join(tmp, ignored)
        File.mkdir_p!(dir)
        File.write!(
          Path.join(dir, "SKILL.md"),
          "---\nname: should-be-skipped\ndescription: Ignored\n---\n"
        )
      end

      make_skill(tmp, "real-skill", "Should load")

      assert {:ok, skills} = Skills.load_all(tmp)
      names = Enum.map(skills, & &1.name)
      assert "real-skill" in names
      refute "should-be-skipped" in names
    end
  end

  describe "load_from_dir/1" do
    test "returns empty list for empty directory", %{tmp_dir: tmp} do
      assert [] = Skills.load_from_dir(tmp)
    end

    test "finds skills nested in subdirectories", %{tmp_dir: tmp} do
      nested = Path.join(tmp, "category/subdir")
      File.mkdir_p!(nested)

      File.write!(
        Path.join(nested, "SKILL.md"),
        "---\nname: nested-skill\ndescription: Nested\n---\n"
      )

      assert [%Skill{name: "nested-skill"}] = Skills.load_from_dir(tmp)
    end

    test "does not recurse into a skill's own subdirectory", %{tmp_dir: tmp} do
      skill_dir = Path.join(tmp, "my-skill")
      inner_dir = Path.join(skill_dir, "assets")
      File.mkdir_p!(inner_dir)

      File.write!(
        Path.join(skill_dir, "SKILL.md"),
        "---\nname: my-skill\ndescription: Top skill\n---\n"
      )

      # This inner SKILL.md should NOT be discovered
      File.write!(
        Path.join(inner_dir, "SKILL.md"),
        "---\nname: inner-skill\ndescription: Inner\n---\n"
      )

      assert [%Skill{name: "my-skill"}] = Skills.load_from_dir(tmp)
    end
  end
end
