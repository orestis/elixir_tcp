slidenumbers: true
slidecount: true
# Going low level with TCP sockets and `:gen_tcp`

---

## Summary

TCP sockets are used everywhere, though most of the time the details are hidden in high-level APIs and protocols. However, the BEAM makes writing such low-level network code a breeze — this talk will give a brief overview of how Erlang’s built-in `:gen_tcp` can be used to build low-level client and server applications.

The audience should be already familiar with Elixir code and some core BEAM concepts such as processes and messages.

---

## Why bother?

* Foundation of the Internet
* At the base of most [^1] of all network-related code
* Will make you wonder how everything even *works*
* Will make you appreciate the engineers that designed it

[^1]: UDP is the other major one

---

## [fit] Internet Protocol (IP in TCP/IP)

---

## Internet Protocol (IP in TCP/IP)

* Like passing notes in school
* Put data in a packet, pass it on
* Optionally, put the packet in an envelope
* Hope for the best

---

## Internet Protocol (IP in TCP/IP) (cont'd)

* How do you know that your packet arrived at the destination? [^2]
* What happens if your data won't fit the packet?
* If you have multiple packets, how do you guarantee order?
* etc.

[^2]: Look up the Two Generals problem


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
* Breaks the illusion slightly, adapting to real-life concerns
* Read buffer, write buffer, flushing, blocking etc.

---

## `:gen_tcp`

* Exposes a BSD Socket API in the BEAM, via a port
* Blocking mode (passive)
* Non-blocking mode (active)
* Highly configurable and intricate
* Closely tied with `:inet.setopts/2`

---

## Hello world, server

* Accept connections on port 4001
* Send the string "Hello!"
* Close the connection
* Repeat

---

## Demo 

example1.exs

```
~ $ telnet 127.0.0.1 4001
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
Hello!
Connection closed by foreign host.
```

```
~ $ nc 127.0.0.1 4001
Hello!
~ $
```

---

## Server Code

```elixir
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
```
---


## Server Code

```elixir
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
```
---

## Server code

* Listen socket vs actual socket
* `:binary` vs charlist for data
* `reuseaddr` useful for demo purposes
* `shutdown` is more gentle than `close`
* One process listens, multiple processes accept
* Use Ranch for this: https://github.com/ninenines/ranch

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

* Host is always a charlist 
* `active` mode turns data into messages (default)
* Can also set `[active: once]` or `[active: N]` to receive one or N messages
* NOTE: message data are "amorphous" - no shape

---

## Two way - demo

example2.exs

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

---

## Two-way - client

```elixir
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
```

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
  {:ok, listen_socket} = :gen_tcp.listen(4001, [:binary,
                                                active: false,
                                                reuseaddr: true])
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
      d = IO.gets "Enter your name: "
      :ok = :gen_tcp.send(socket, String.trim(d))
      client_handler(socket)
    {:ok, data} ->
      IO.write data
      client_handler(socket)
    {:error, :closed} ->
      IO.puts "== CLOSED =="
  end
end
```

## Passive mode

* `recv(socket, length)`
* `recv(socket, length, timeout)`
* When `length == 0`, "read all available"
* When `length > 0`, "read exactly `length` bytes"
* `timeout` defaults to `Infinity`

---

## Major gotcha

* How do you know how many bytes to read? (passive mode)
* No guarantee that "HELLO?" will arrive in a single message (active mode)
* Depends on various arcane OS and ERTS parameters 
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

## Protocol implementation

* Read some data
* Does it match what I expect?
* Not yet - read some more
* No - error
* Yes - go to next state

---
## Untangle the protocol logic from the TCP logic

* Abstract the "transport" out
* Can provide a dummy transport for testing
* Can transparently adapt to TLS/SSL, tunnels etc.

---

## Honorable mention - Packet protocol

* Provided by :gen_tcp
* Transparently adds a length header to each send/receive operation
* Supports messages up to 2GB
* Very useful when you control both ends

---

## Packet protocol

```[.highlight: 3,11] elixir
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
```

---


# BREAK

---

