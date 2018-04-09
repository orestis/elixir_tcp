#slidenumbers: true
#slidecount: true
build-lists: true

# Going low level with TCP sockets and `:gen_tcp`

<br>

### Orestis Markou

#### `@orestis`
#### `orestis.gr`

---

## Why bother?

* Foundation of the Internet
* Will make you wonder how everything even *works*
* Will make you appreciate the engineers that designed it


---

## Internet Protocol (IP in TCP/IP)

* Like passing notes in school
* Put data in a packet, pass it on
* Hope for the best
* Optionally, put the packet in an envelope

---

## Internet Protocol (IP in TCP/IP) (issues)

* How do you know that your packet arrived at the destination? 
* What happens if your data won't fit the packet?
* If you have multiple packets, how do you guarantee order?
* etc.


---

## [fit] Transport Control Protocol (TCP in TCP/IP)

![original](annie-spratt-593479-unsplash.jpg)

[.footer: Photo by Annie Spratt on Unsplash]

---

## TCP/IP

* Gives you a **point-to-point**, **two-way stream** abstraction on top of the chaos
* Make a connection to the other party
* Write data to your end, appears on the other end
* and vice-versa

![](annie-spratt-593479-unsplash.jpg)

---

## BSD Sockets API

* Most common TCP/IP API
* Breaks the illusion slightly, adapting to real-life implementations

---

## `:gen_tcp`

* Exposes a BSD Socket API in the BEAM
* Highly configurable and intricate

---

## Hello world, server

* Accept connections on port 4001
* Send the string "Hello!"
* Close the connection
* Repeat

---

## Server Code

```elixir
def server do
  {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary,
                                                reuseaddr: true])
  for _ <- 0..10, do: spawn(fn -> server_handler(listen_socket) end)
  Process.sleep(:infinity)
end

def server_handler(listen_socket) do
  {:ok, socket} = :gen_tcp.accept(listen_socket)
  :ok = :gen_tcp.send(socket, "Hello!\r\n")
  :ok = :gen_tcp.shutdown(socket, :read_write)
  server_handler(listen_socket)
end
```
---


## Server Code

```[.highlight: 2-3] elixir
def server do
  {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary,
                                                reuseaddr: true])
  for _ <- 0..10, do: spawn(fn -> server_handler(listen_socket) end)
  Process.sleep(:infinity)
end

def server_handler(listen_socket) do
  {:ok, socket} = :gen_tcp.accept(listen_socket)
  :ok = :gen_tcp.send(socket, "Hello!\r\n")
  :ok = :gen_tcp.shutdown(socket, :read_write)
  server_handler(listen_socket)
end
```

^ `:binary` vs charlist for data
^ `reuseaddr` useful for demo purposes

---

## Server Code

```[.highlight: 4-5] elixir
def server do
  {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary,
                                                reuseaddr: true])
  for _ <- 0..10, do: spawn(fn -> server_handler(listen_socket) end)
  Process.sleep(:infinity)
end

def server_handler(listen_socket) do
  {:ok, socket} = :gen_tcp.accept(listen_socket)
  :ok = :gen_tcp.send(socket, "Hello!\r\n")
  :ok = :gen_tcp.shutdown(socket, :read_write)
  server_handler(listen_socket)
end
```

^ One process listens, multiple processes accept
^ Use Ranch for this: https://github.com/ninenines/ranch

---

## Server Code

```[.highlight: 8-13] elixir
def server do
  {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary,
                                                reuseaddr: true])
  for _ <- 0..10, do: spawn(fn -> server_handler(listen_socket) end)
  Process.sleep(:infinity)
end

def server_handler(listen_socket) do
  {:ok, socket} = :gen_tcp.accept(listen_socket)
  :ok = :gen_tcp.send(socket, "Hello!\r\n")
  :ok = :gen_tcp.shutdown(socket, :read_write)
  server_handler(listen_socket)
end
```

^ Listen socket vs actual socket
^ accept is blocking
^ shutdown is more gentle
^ recurse for the next connection

---


## Client code

```elixir
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
```

---

## Client code

```[.highlight: 2-3] elixir
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
```

^ Host is always a charlist 
^ `active` mode turns incomning data into erlang messages (default)

---

## Demo 

example1.exs

---



## Two-way - server

```elixir
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
```

^ two way communications

---

## Two-way - client

```elixir
def client_handler(socket) do
  receive do
    {:tcp, ^socket, "HELLO?"} ->
      d = IO.gets("Enter your name: ") |> String.trim()
      :ok = :gen_tcp.send(socket, d)
      client_handler(socket)
    {:tcp, ^socket, data} ->
      IO.write data
      client_handler(socket)
    {:tcp_closed, ^socket} -> IO.puts "== CLOSED =="
  end
end
```

---

## Two-way - client

```[.highlight: 2,3,7,10] elixir
def client_handler(socket) do
  receive do
    {:tcp, ^socket, "HELLO?"} ->
      d = IO.gets("Enter your name: ") |> String.trim()
      :ok = :gen_tcp.send(socket, d)
      client_handler(socket)
    {:tcp, ^socket, data} ->
      IO.write data
      client_handler(socket)
    {:tcp_closed, ^socket} -> IO.puts "== CLOSED =="
  end
end
```

---

## Two way - demo

example2b.exs

---


## Passive mode

* Instead of receiving data as messages, directly read from the socket
* Blocking API with timeouts
* Provides back-pressure
* Closer to the original BSD API

---

## Passive mode server

```elixir
def server do
  {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary, reuseaddr: true
                                                active: false])
  server_handler(listen_socket)
end

def server_handler(listen_socket) do
  {:ok, socket} = :gen_tcp.accept(listen_socket)
  :ok = :gen_tcp.send(socket, "HELLO?")
  {:ok, data} = :gen_tcp.recv(socket, 0)
  :ok = :gen_tcp.send(socket, "Hello, #{data}!\r\n")
  :ok = :gen_tcp.shutdown(socket, :read_write)
  server_handler(listen_socket)
end
```

---

## Passive mode server

```[.highlight: 3,10] elixir
def server do
  {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary, reuseaddr: true
                                                active: false])
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
```

^ active: false (default is true even for servers)
^ read zero bytes, blocking call, timeout 5000 millis
^ default timeout infinity

---


## Passive mode client

```elixir
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
```

---

## Passive mode client

```[.highlight: 4] elixir
def client do
  {:ok, socket} = :gen_tcp.connect('localhost', 4001,
    [:binary, 
    active: false])
  client_handler(socket)
end
```

---

## Passive mode client

```[.highlight: 2,3,7,10] elixir
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
```

---

## Passive mode

* `recv(socket, length)`
* `recv(socket, length, timeout)`
* When `length == 0`, "read all available"
* When `length > 0`, "read exactly `length` bytes"
* `timeout` defaults to `:infinity`

---

## Major gotcha

* How do you know how many bytes to read? (passive mode)
* No guarantee that "HELLO?" will arrive in a single message (active mode)
* Depends on various arcane parameters (OS/BEAM)
* Works most of the time with tiny payloads like this
* Will break on real-world usage
* Another level of abstraction is needed

---

## Protocols

* Abstractions over TCP that give shape to the data packets
* Some are common (HTTP), some are custom (your own!)
* Some are even provided by `:gen_tcp`
* Basically state machines

---

## Protocol specifications

e.g. Daytime protocol (RFC 867)

> **TCP Based Daytime Service**
>
> One daytime service is defined as a connection based application on
> TCP.  A server listens for TCP connections on TCP port 13.  Once a
> connection is established the current date and time is sent out the
> connection as a ascii character string (and any data received is
> thrown away).  The service closes the connection after sending the
> quote.

---

## Protocol specifications

e.g. HTTP/1.1 protocol (RFC 2616)

> <176 pages>

e.g. Memcached protocol

> <1200 lines of text>

---

## Protocol specifications

* What comes next?
* What form does it come in?
* Who is responsible for the next transmission?
* etc.

---

## Built-in protocols

* Provided by :gen_tcp
* Limited in scope, non-extensible
* Might be useful

---

## Prefix header length

```elixir
[packet: 2]
```

* Transparently add/strip header
* 1, 2 or 4 byte header length
* Support up to 2GB messages
* Very useful when you control both ends

---

## Line-based messages

```elixir
[packet: :line,
line_delimiter: ?\n,
packet_size: 255]
```

* Split incoming messages by newline
* Outgoing messages are your responsibility
* A few gotchas, must evaluate

^ unfortunately can't set CRLF as delimiter
^ might not be as bullet proof as needed

---

## Mutable sockets

* Can change mode on-the-fly (binary, active)
* Active mode can be one shot or N-shot or permanent
* Can change protocols on the fly
* Read a line, extract content length, read raw bytes

---

```elixir
def memcached_client_get do
  {:ok, socket} = :gen_tcp.connect('localhost', 11211,
    [:binary,  active: false,
      packet: :line])
  :gen_tcp.send(socket, "get elixirconf\r\n")
  {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
  IO.puts "Raw response:"
  IO.inspect response
  <<"VALUE elixirconf ", resp::binary>> = response
  [_, length] = resp |> String.trim() |> String.split() 
    |> Enum.map(&String.to_integer/1)
  :inet.setopts(socket, [packet: 0])
  {:ok, data} = :gen_tcp.recv(socket, length, 5000)
  IO.puts "Actual data:"
  IO.inspect data
end
```

---

```[.highlight: 4,6,12,13]elixir
def memcached_client_get do
  {:ok, socket} = :gen_tcp.connect('localhost', 11211,
    [:binary,  active: false,
      packet: :line])
  :gen_tcp.send(socket, "get elixirconf\r\n")
  {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
  IO.puts "Raw response:"
  IO.inspect response
  <<"VALUE elixirconf ", resp::binary>> = response
  [_, length] = resp |> String.trim() |> String.split() 
    |> Enum.map(&String.to_integer/1)
  :inet.setopts(socket, [packet: 0])
  {:ok, data} = :gen_tcp.recv(socket, length, 5000)
  IO.puts "Actual data:"
  IO.inspect data
end
```

---

## Demo

protocols.exs
`/usr/local/opt/memcached/bin/memcached`

---

## Pain point: Untangle the protocol logic from the socket logic

* Abstract the "transport" out
* Could provide a dummy transport for testing
* Could transparently adapt to TLS/SSL, tunnels etc.
* Good space for a library
* (I'm **not** working on one!)

---

# Resources

* TCP/IP Illustrated, Volume 1 [Fall & Stevens]
* http://erlang.org/doc/man/gen_tcp.html
* http://erlang.org/doc/man/inet.html
* https://ninenines.eu/docs/en/ranch/1.4/guide/
* https://github.com/orestis/elixir_tcp

---

# Thank you!

## Questions?

### https://github.com/orestis/elixir_tcp

<br>

### Orestis Markou

#### `@orestis`
#### `orestis.gr`
