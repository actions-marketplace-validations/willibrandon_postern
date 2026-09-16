Application.put_env(:gen_lsp, :exit_on_end, false)
ExUnit.start()
ExUnit.configure(assert_receive_timeout: 2000, refute_receive_timeout: 2000)
