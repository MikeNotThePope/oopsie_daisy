defmodule DaisyuiGen.Cloner do
  @moduledoc """
  Clones the DaisyUI repository into the tmp directory.

  This module provides functionality to clone a shallow copy (depth 1) of the DaisyUI
  repository from GitHub into `tmp/daisyui`. If the directory already exists, it will
  be deleted first to ensure a clean clone.

  ## Usage

      iex> DaisyuiGen.Cloner.clone()
      {:ok, "/path/to/project/tmp/daisyui"}

      iex> DaisyuiGen.Cloner.clone(output_callback: &IO.puts/1)
      {:ok, "/path/to/project/tmp/daisyui"}

  ## Options

    * `:output_callback` - A function that receives output messages (default: &IO.puts/1)
    * `:base_dir` - The base directory to clone into (default: current working directory)

  ## Return Values

    * `{:ok, path}` - Clone succeeded, returns the path to the cloned repository
    * `{:error, reason}` - Clone failed with the given reason
  """

  @type clone_option :: {:output_callback, (String.t() -> any())} | {:base_dir, String.t()}
  @type clone_result :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Clones the DaisyUI repository into tmp/daisyui.

  ## Options

    * `:output_callback` - A function that receives output messages
    * `:base_dir` - The base directory (defaults to current working directory)

  ## Examples

      iex> DaisyuiGen.Cloner.clone()
      {:ok, "/path/to/tmp/daisyui"}

      iex> DaisyuiGen.Cloner.clone(base_dir: "/custom/path")
      {:ok, "/custom/path/tmp/daisyui"}
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
  Ensures the DaisyUI repository is available, cloning it if necessary.

  This function checks if the DaisyUI repository exists at tmp/daisyui.
  If it doesn't exist, it clones it. If it does exist, it does nothing.

  ## Options

  Same as `clone/1`.

  ## Examples

      iex> DaisyuiGen.Cloner.ensure_available()
      {:ok, "/path/to/tmp/daisyui"}
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
