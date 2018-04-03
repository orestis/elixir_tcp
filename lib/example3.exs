defmodule Example2 do
  def server do
    {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary,
                                                  packet: 2,
                                                  reuseaddr: true])
    server_handler(listen_socket)
  end

  def client do
    {:ok, socket} = :gen_tcp.connect('localhost', 4001,
      [:binary,
       packet: 2,
       active: true])
    client_handler(socket)
  end

  def server_handler(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    :ok = :gen_tcp.send(socket, "HELLO?")
    receive do
      {:tcp, ^socket, data} ->
        :ok = :gen_tcp.send(socket, "Hello, #{data}!\r\n")
    end
    :ok = :gen_tcp.shutdown(socket, :read_write)
    server_handler(listen_socket)
  end

  def client_handler(socket) do
    receive do
      {:tcp, ^socket, "HELLO?"} ->
        d = IO.gets "Enter your name: "
        :ok = :gen_tcp.send(socket, String.trim(d))
        client_handler(socket)
      {:tcp, ^socket, data} ->
        IO.write data
        client_handler(socket)
      {:tcp_closed, ^socket} -> IO.puts "== CLOSED =="
    end
  end
end

case System.argv() do
  ["client"] -> Example2.client()
  ["server"] -> Example2.server()
end
