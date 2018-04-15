defmodule Example1 do
  def server do
    {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary,
                                                 reuseaddr: true])
    for _ <- 0..10, do: spawn(fn -> server_handler(listen_socket) end)
    Process.sleep(:infinity)
  end

  def server_handler(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    d = DateTime.utc_now() |> DateTime.to_string()
    :ok = :gen_tcp.send(socket, d <> "\r\n")
    :ok = :gen_tcp.shutdown(socket, :read_write)
    server_handler(listen_socket)
  end

  def client do
    {:ok, socket} = :gen_tcp.connect('localhost', 4001,
                      [:binary, active: true])
    client_handler(socket)
  end

  def client_handler(socket) do
    receive do
      {:tcp, ^socket, data} ->
        IO.write data
        client_handler(socket)
      {:tcp_closed, ^socket} -> IO.puts "== CLOSED =="
    end
  end
end

case System.argv() do
  ["client"] -> Example1.client()
  ["server"] -> Example1.server()
end
