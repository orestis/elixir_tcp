defmodule Passive1 do
  def hello do
    {:ok, socket} = :gen_tcp.connect('www.google.com', 80, [:binary, active: false])
    :ok = :gen_tcp.send(socket, "GET / HTTP/1.0 \r\n\r\n")
    {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
    IO.puts response
  end

  def large do
    {:ok, socket} = :gen_tcp.connect('www.gutenberg.org', 80,
                                      [:binary, active: false])
    :ok = :gen_tcp.send(socket,
                        ["GET /files/84/84-0.txt HTTP/1.1\r\n",
                        "Host: www.gutenberg.org\r\n",
                        "Accept: */*\r\n\r\n"])
    {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
    IO.puts response
    IO.puts "==== Received #{byte_size(response)} bytes ===="
  end

  def large_correct do
    {:ok, socket} = :gen_tcp.connect('www.gutenberg.org', 80,
      [:binary, active: false])
    :ok = :gen_tcp.send(socket,
      ["GET /files/84/84-0.txt HTTP/1.1\r\n",
       "Host: www.gutenberg.org\r\n",
       "Accept: */*\r\n\r\n"])
    response = _recv(socket, [])
    IO.puts response
    IO.puts "==== Received #{byte_size(response)} bytes ===="
  end

  def _recv(socket, acc) do
    r = :gen_tcp.recv(socket, 0, 5000)
    case r do
      {:ok, data} -> _recv(socket, [data|acc])
      other ->
        IO.puts("other")
        IO.inspect(other)
        Enum.reverse(acc) |> IO.iodata_to_binary()
    end
  end

  def opts do
    {:ok, socket} = :gen_tcp.connect('www.gutenberg.org', 80,
      [:binary, active: false])
    {:ok, values} = :inet.getopts(socket, [:buffer, :recbuf])
    IO.puts "Options: #{inspect values}"
  end
end

Passive1.large_correct()
