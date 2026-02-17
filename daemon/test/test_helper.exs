# Ensure test state_dir exists
test_state_dir = Application.get_env(:lantern, :state_dir)
if test_state_dir, do: File.mkdir_p!(test_state_dir)

ExUnit.start()

# Clean up test state dir after suite
ExUnit.after_suite(fn _results ->
  if test_state_dir && String.contains?(test_state_dir, "lantern-test-") do
    File.rm_rf!(test_state_dir)
  end
end)
