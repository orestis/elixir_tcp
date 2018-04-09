defmodule Protocols do
  def memcached_client_set do
      {:ok, socket} = :gen_tcp.connect('localhost', 11211,
                          [:binary,  active: false,
                          packet: :line])
      message = "Hello from Warsaw!!\n"
      :gen_tcp.send(socket, "set elixirconf 0 0 #{byte_size(message)}\r\n")
      :gen_tcp.send(socket, message)
      :gen_tcp.send(socket, "\r\n")
      {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
      IO.inspect response
  end

  def memcached_client_get do
    {:ok, socket} = :gen_tcp.connect('localhost', 11211,
      [:binary,  active: false,
       packet: :line])
    :gen_tcp.send(socket, "get elixirconf\r\n")
    {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
    IO.puts "Raw response:"
    IO.inspect response
    <<"VALUE elixirconf ", resp::binary>> = response
    [_, length] = resp |> String.trim() |> String.split() |> Enum.map(&String.to_integer/1)
    :inet.setopts(socket, [packet: 0])
    {:ok, data} = :gen_tcp.recv(socket, length, 5000)
    IO.puts "Actual data:"
    IO.inspect data
  end
end

case System.argv() do
  ["memcached_set"] -> Protocols.memcached_client_set()
  ["memcached_get"] -> Protocols.memcached_client_get()
end
