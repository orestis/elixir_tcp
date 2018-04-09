defmodule Example2b do
  def server do
    {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary,
                                                  active: false,
                                                 reuseaddr: true])
    server_handler(listen_socket)
  end

  def server_handler(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    :ok = :gen_tcp.send(socket, "HELLO?")
    {:ok, data} = :gen_tcp.recv(socket, 0, 5000)
    :ok = :gen_tcp.send(socket, "Hello, #{data}!\r\n")
    :ok = :gen_tcp.shutdown(socket, :read_write)
    server_handler(listen_socket)
  end

  def client do
    {:ok, socket} = :gen_tcp.connect('localhost', 4001,
      [:binary, active: false])
    client_handler(socket)
  end

  def client_handler(socket) do
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, "HELLO?"} ->
        d = IO.gets("Enter your name: ") |> String.trim()
        :ok = :gen_tcp.send(socket, d)
        client_handler(socket)
      {:ok, data} ->
        IO.write data
        client_handler(socket)
      {:error, :closed} -> IO.puts "== CLOSED =="
    end
  end
end

case System.argv() do
  ["client"] -> Example2b.client()
  ["server"] -> Example2b.server()
end
