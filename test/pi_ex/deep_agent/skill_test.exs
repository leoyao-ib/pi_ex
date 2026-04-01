defmodule PiEx.DeepAgent.SkillTest do
  use ExUnit.Case, async: true

  alias PiEx.DeepAgent.Skill

  @moduletag :tmp_dir

  defp write_skill(tmp, content) do
    path = Path.join(tmp, "SKILL.md")
    File.write!(path, content)
    path
  end

  describe "from_file/1" do
    test "parses valid frontmatter", %{tmp_dir: tmp} do
      path =
        write_skill(tmp, """
        ---
        name: my-skill
        description: Does something useful
        ---
        # Instructions
        """)

      assert {:ok, %Skill{} = skill} = Skill.from_file(path)
      assert skill.name == "my-skill"
      assert skill.description == "Does something useful"
      assert skill.file_path == path
      assert skill.base_dir == tmp
      assert skill.disable_model_invocation == false
    end

    test "parses disable-model-invocation: true", %{tmp_dir: tmp} do
      path =
        write_skill(tmp, """
        ---
        name: hidden-skill
        description: Hidden from model
        disable-model-invocation: true
        ---
        """)

      assert {:ok, %Skill{disable_model_invocation: true}} = Skill.from_file(path)
    end

    test "disable-model-invocation defaults to false when absent", %{tmp_dir: tmp} do
      path =
        write_skill(tmp, """
        ---
        name: visible-skill
        description: Visible to model
        ---
        """)

      assert {:ok, %Skill{disable_model_invocation: false}} = Skill.from_file(path)
    end

    test "returns error when name is missing", %{tmp_dir: tmp} do
      path =
        write_skill(tmp, """
        ---
        description: No name here
        ---
        """)

      assert {:error, reason} = Skill.from_file(path)
      assert reason =~ "name"
    end

    test "returns error when description is missing", %{tmp_dir: tmp} do
      path =
        write_skill(tmp, """
        ---
        name: no-desc
        ---
        """)

      assert {:error, reason} = Skill.from_file(path)
      assert reason =~ "description"
    end

    test "returns error when frontmatter is absent", %{tmp_dir: tmp} do
      path = write_skill(tmp, "# Just markdown, no frontmatter\n")

      assert {:error, reason} = Skill.from_file(path)
      assert reason =~ "frontmatter"
    end

    test "returns error when file does not exist" do
      assert {:error, reason} = Skill.from_file("/nonexistent/SKILL.md")
      assert reason =~ "not found"
    end
  end
end
