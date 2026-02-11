defmodule Lantern.Services.MailInjectorTest do
  use ExUnit.Case, async: true

  alias Lantern.Services.MailInjector

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "lantern_mail_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, project_path: tmp_dir}
  end

  describe "inject/2 for Laravel" do
    test "injects marker block into .env", %{project_path: path} do
      File.write!(Path.join(path, ".env"), "APP_NAME=Laravel\nAPP_ENV=local\n")

      assert :ok = MailInjector.inject(path, "laravel")

      content = File.read!(Path.join(path, ".env"))
      assert content =~ "# >>> lantern mailpit >>>"
      assert content =~ "MAIL_HOST=127.0.0.1"
      assert content =~ "MAIL_PORT=1025"
      assert content =~ "# <<< lantern mailpit <<<"
    end

    test "creates backup on first injection", %{project_path: path} do
      File.write!(Path.join(path, ".env"), "APP_NAME=Laravel\n")

      MailInjector.inject(path, "laravel")

      assert File.exists?(Path.join(path, ".env.lantern.bak"))
      backup = File.read!(Path.join(path, ".env.lantern.bak"))
      assert backup == "APP_NAME=Laravel\n"
    end

    test "is idempotent", %{project_path: path} do
      File.write!(Path.join(path, ".env"), "APP_NAME=Laravel\n")

      MailInjector.inject(path, "laravel")
      MailInjector.inject(path, "laravel")

      content = File.read!(Path.join(path, ".env"))
      # Should only have one marker block
      assert length(String.split(content, "# >>> lantern mailpit >>>")) == 2
    end
  end

  describe "inject/2 for Symfony" do
    test "injects MAILER_DSN into .env.local", %{project_path: path} do
      assert :ok = MailInjector.inject(path, "symfony")

      content = File.read!(Path.join(path, ".env.local"))
      assert content =~ "MAILER_DSN=smtp://127.0.0.1:1025"
      assert content =~ "# >>> lantern mailpit >>>"
    end
  end

  describe "inject/2 for Vite/Next.js" do
    test "injects SMTP vars into .env.local", %{project_path: path} do
      assert :ok = MailInjector.inject(path, "vite")

      content = File.read!(Path.join(path, ".env.local"))
      assert content =~ "SMTP_HOST=127.0.0.1"
      assert content =~ "SMTP_PORT=1025"
    end
  end

  describe "remove/2" do
    test "removes marker block", %{project_path: path} do
      File.write!(Path.join(path, ".env"), "APP_NAME=Laravel\n")
      MailInjector.inject(path, "laravel")

      assert :ok = MailInjector.remove(path, "laravel")

      content = File.read!(Path.join(path, ".env"))
      refute content =~ "# >>> lantern mailpit >>>"
      refute content =~ "MAIL_HOST"
      assert content =~ "APP_NAME=Laravel"
    end

    test "is safe when not injected", %{project_path: path} do
      File.write!(Path.join(path, ".env"), "APP_NAME=Laravel\n")
      assert :ok = MailInjector.remove(path, "laravel")
    end

    test "is safe when file doesn't exist", %{project_path: path} do
      assert :ok = MailInjector.remove(path, "laravel")
    end
  end

  describe "preview/2" do
    test "shows what would be injected", %{project_path: path} do
      File.write!(Path.join(path, ".env"), "APP_NAME=Laravel\n")

      assert {:ok, {".env", block}} = MailInjector.preview(path, "laravel")
      assert block =~ "MAIL_HOST"
      assert block =~ "# >>> lantern mailpit >>>"
    end

    test "reports already injected", %{project_path: path} do
      File.write!(Path.join(path, ".env"), "APP_NAME=Laravel\n")
      MailInjector.inject(path, "laravel")

      assert {:ok, :already_injected} = MailInjector.preview(path, "laravel")
    end
  end

  describe "injected?/1" do
    test "returns false for clean file", %{project_path: path} do
      File.write!(Path.join(path, ".env"), "APP_NAME=Laravel\n")
      refute MailInjector.injected?(Path.join(path, ".env"))
    end

    test "returns true for injected file", %{project_path: path} do
      File.write!(Path.join(path, ".env"), "APP_NAME=Laravel\n")
      MailInjector.inject(path, "laravel")
      assert MailInjector.injected?(Path.join(path, ".env"))
    end
  end
end
