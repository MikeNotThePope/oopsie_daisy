defmodule OopsieDaisy.Cloner do
  @moduledoc """
  Clones the DaisyUI repository for parsing.

  Internal module used by the generator. Phoenix developers don't typically
  interact with this directly - use `mix oopsie_daisy.gen` instead.

  Clones DaisyUI from GitHub into `tmp/daisyui` at depth 1 (shallow clone).
  """

  @type clone_option :: {:output_callback, (String.t() -> any())} | {:base_dir, String.t()}
  @type clone_result :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Clones DaisyUI repository to `tmp/daisyui`.

  Returns `{:ok, path}` on success, `{:error, reason}` on failure.
  """
  @spec clone([clone_option()]) :: clone_result()
  def clone(opts \\ []) do
    output_callback = Keyword.get(opts, :output_callback, &IO.puts/1)
    base_dir = Keyword.get(opts, :base_dir, File.cwd!())

    tmp_dir = Path.join(base_dir, "tmp")
    daisyui_path = Path.join(tmp_dir, "daisyui")

    with :ok <- ensure_tmp_directory(tmp_dir),
         :ok <- remove_existing_directory(daisyui_path, output_callback),
         :ok <- clone_repository(tmp_dir, output_callback) do
      output_callback.(
        "\n✓ DaisyUI cloned successfully to #{Path.relative_to(daisyui_path, base_dir)}"
      )

      {:ok, daisyui_path}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Ensures DaisyUI repository is available, cloning if needed.

  Checks if `tmp/daisyui` exists. If not, clones it. If yes, does nothing.
  """
  @spec ensure_available([clone_option()]) :: clone_result()
  def ensure_available(opts \\ []) do
    base_dir = Keyword.get(opts, :base_dir, File.cwd!())
    daisyui_path = Path.join([base_dir, "tmp", "daisyui"])

    if File.dir?(daisyui_path) do
      {:ok, daisyui_path}
    else
      clone(opts)
    end
  end

  # Private functions

  defp ensure_tmp_directory(tmp_dir) do
    File.mkdir_p!(tmp_dir)
    :ok
  rescue
    e -> {:error, "Failed to create tmp directory: #{Exception.message(e)}"}
  end

  defp remove_existing_directory(daisyui_path, output_callback) do
    if File.dir?(daisyui_path) do
      output_callback.("Removing existing daisyui directory...")

      case File.rm_rf(daisyui_path) do
        {:ok, _} ->
          output_callback.("✓ Removed existing directory")
          :ok

        {:error, reason, _} ->
          {:error, "Failed to remove existing directory: #{inspect(reason)}"}
      end
    else
      :ok
    end
  end

  defp clone_repository(tmp_dir, output_callback) do
    output_callback.("Cloning DaisyUI repository (depth 1)...")

    case System.cmd("git", ["clone", "--depth", "1", "git@github.com:saadeghi/daisyui.git"],
           cd: tmp_dir,
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} ->
        :ok

      {_, exit_code} ->
        {:error, "Git clone failed with exit code #{exit_code}"}
    end
  end
end
