defmodule Example1 do
  def server do
    {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary,
                                                 reuseaddr: true])
    server_handler(listen_socket)
  end

  def server_handler(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    :ok = :gen_tcp.send(socket, "Hello!\r\n")
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

#Example1.server()
Example1.client()
