defmodule Active do
  def hello do
    {:ok, socket} = :gen_tcp.connect('www.google.com', 80, [:binary, active: true])
    :ok = :gen_tcp.send(socket, "GET / HTTP/1.0 \r\n\r\n")
    recv()
  end

  def recv do
    receive do
      {:tcp, socket, msg} ->
        IO.puts msg
        recv()
      {:tcp_closed, socket} -> IO.puts "=== Closed ==="
      {:tcp_error, socket, reason} -> IO.puts "=== Error #{inspect reason} ==="
    end
  end

end

Active.hello()
