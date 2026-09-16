Application.put_env(:gen_lsp, :exit_on_end, false)
ExUnit.start(exclude: if(match?({:win32, _}, :os.type()), do: [:unix], else: []))
ExUnit.configure(assert_receive_timeout: 2000, refute_receive_timeout: 2000)
