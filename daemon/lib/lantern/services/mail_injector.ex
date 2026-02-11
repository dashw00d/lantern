defmodule Lantern.Services.MailInjector do
  @moduledoc """
  Framework-aware mail config injection for Mailpit.
  Injects SMTP settings into project .env files using marker blocks.
  Supports backup, clean removal, and idempotent re-application.
  """

  @marker_start "# >>> lantern mailpit >>>"
  @marker_end "# <<< lantern mailpit <<<"

  @mailpit_vars %{
    "MAIL_MAILER" => "smtp",
    "MAIL_HOST" => "127.0.0.1",
    "MAIL_PORT" => "1025",
    "MAIL_USERNAME" => "",
    "MAIL_PASSWORD" => "",
    "MAIL_ENCRYPTION" => "",
    "MAIL_FROM_ADDRESS" => "dev@localhost",
    "MAIL_FROM_NAME" => "Lantern Dev"
  }

  @symfony_var "MAILER_DSN=smtp://127.0.0.1:1025"

  @doc """
  Injects Mailpit configuration into the appropriate file for the given framework.
  Returns :ok or {:error, reason}.
  """
  def inject(project_path, framework) do
    {target_file, content} = injection_target(project_path, framework)
    target_path = Path.join(project_path, target_file)

    backup(target_path)

    existing = read_file(target_path)

    if already_injected?(existing) do
      # Already injected, update in place
      new_content = replace_marker_block(existing, content)
      File.write(target_path, new_content)
    else
      # Append marker block
      block = marker_block(content)
      File.write(target_path, existing <> "\n" <> block)
    end
  end

  @doc """
  Removes the Mailpit configuration from the target file.
  """
  def remove(project_path, framework) do
    {target_file, _content} = injection_target(project_path, framework)
    target_path = Path.join(project_path, target_file)

    case File.read(target_path) do
      {:ok, existing} ->
        if already_injected?(existing) do
          new_content = remove_marker_block(existing)
          File.write(target_path, new_content)
        else
          :ok
        end

      {:error, _} ->
        :ok
    end
  end

  @doc """
  Returns a diff preview of what would be injected.
  Returns {:ok, {target_file, lines_to_add}} or {:ok, :already_injected}.
  """
  def preview(project_path, framework) do
    {target_file, content} = injection_target(project_path, framework)
    target_path = Path.join(project_path, target_file)

    existing = read_file(target_path)

    if already_injected?(existing) do
      {:ok, :already_injected}
    else
      {:ok, {target_file, marker_block(content)}}
    end
  end

  @doc """
  Checks if Mailpit config has been injected into the given file.
  """
  def injected?(file_path) do
    case File.read(file_path) do
      {:ok, content} -> already_injected?(content)
      _ -> false
    end
  end

  # Private helpers

  defp injection_target(project_path, framework) when framework in ["laravel", :laravel] do
    content = Enum.map_join(@mailpit_vars, "\n", fn {k, v} -> "#{k}=#{v}" end)
    target = if File.exists?(Path.join(project_path, ".env")), do: ".env", else: ".env"
    {target, content}
  end

  defp injection_target(_project_path, framework) when framework in ["symfony", :symfony] do
    {".env.local", @symfony_var}
  end

  defp injection_target(_project_path, framework)
       when framework in ["nextjs", "nuxt", "vite", :nextjs, :nuxt, :vite] do
    content = "SMTP_HOST=127.0.0.1\nSMTP_PORT=1025\nMAIL_FROM=dev@localhost"
    {".env.local", content}
  end

  defp injection_target(_project_path, framework) when framework in ["django", :django] do
    content = "EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend\nEMAIL_HOST=127.0.0.1\nEMAIL_PORT=1025\nEMAIL_USE_TLS=False"
    {".env", content}
  end

  defp injection_target(_project_path, _framework) do
    content = "SMTP_HOST=127.0.0.1\nSMTP_PORT=1025"
    {".env", content}
  end

  defp marker_block(content) do
    "#{@marker_start}\n#{content}\n#{@marker_end}\n"
  end

  defp already_injected?(content) do
    String.contains?(content, @marker_start)
  end

  defp replace_marker_block(content, new_inner) do
    regex = ~r/#{Regex.escape(@marker_start)}\n.*?\n#{Regex.escape(@marker_end)}/s
    Regex.replace(regex, content, marker_block(new_inner) |> String.trim_trailing("\n"))
  end

  defp remove_marker_block(content) do
    regex = ~r/\n?#{Regex.escape(@marker_start)}\n.*?\n#{Regex.escape(@marker_end)}\n?/s
    Regex.replace(regex, content, "")
  end

  defp backup(path) do
    backup_path = path <> ".lantern.bak"

    if File.exists?(path) and not File.exists?(backup_path) do
      File.cp(path, backup_path)
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> ""
    end
  end
end
