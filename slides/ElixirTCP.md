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
* message data are "amorphous" - no shape

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

## Major gotcha

* No guarantee that "HELLO?" will arrive in one message
* Depends on various arcane OS and ERTS parameters 
* Should work most of the time with tiny payloads like this

---

## Protocols

* Abstractions over TCP that gives shape to the data packets.
* Some are common (HTTP), some are custom (your own!)
* Some are even provided by :gen_tcp 

---

## Packet protocol

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

## Hello world (request)

```elixir
{:ok, socket} = :gen_tcp.connect('www.google.com', 80,
                                    [:binary, active: false], 5000)
:ok = :gen_tcp.send(socket, "GET / HTTP/1.0 \r\n\r\n")
{:ok, response} = :gen_tcp.recv(socket, 0, 5000)
IO.puts response
```


---

## Hello world (response)

```
HTTP/1.0 302 Found
Location: http://www.google.lu/?gws_rd=cr&dcr=0&ei=EgOtWr7UIcOP0gWa-bCYAg
Cache-Control: private
Content-Type: text/html; charset=UTF-8
Date: Sat, 17 Mar 2018 11:59:14 GMT

... snip ...

<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>302 Moved</TITLE></HEAD><BODY>
<H1>302 Moved</H1>
The document has moved
<A HREF="http://www.google.lu/?gws_rd=cr&amp;dcr=0&amp;ei=EgOtWr7UIcOP0gWa-bCYAg">here</A>.
</BODY></HTML>
```

---

## Connect

```elixir
{:ok, socket} = :gen_tcp.connect('www.google.com', 80,
                                    [:binary, active: false], 5000)
```

* Blocks -- *always use timeout!*
* Hostname is a **charlist**
* List argument is options (huge!)
* `:binary` means response should be a binary (vs charlist)
* `active: false` means use passive/blocking mode

---

## Send

```elixir
:ok = :gen_tcp.send(socket, "GET / HTTP/1.0 \r\n\r\n")
```

* Send binary data (`iodata`)
* No send timeout -- global socket `send_timeout` option [^3]

[^3]: timeouts will be discussed later

---

## Receive

```elixir
{:ok, response} = :gen_tcp.recv(socket, 0, 5000)
```

* Blocks -- *always use timeout!*
* Must specify how much data to read??
* How should **I** know?
* What does "read zero data" even *mean?*

---

## ???

```elixir
{:ok, socket} = :gen_tcp.connect('www.gutenberg.org', 80,
                                  [:binary, active: false])
:ok = :gen_tcp.send(socket,
                    ["GET /files/84/84-0.txt HTTP/1.1\r\n",
                    "Host: www.gutenberg.org\r\n",
                    "Accept: */*\r\n\r\n"])
{:ok, response} = :gen_tcp.recv(socket, 0, 5000)
IO.puts response
IO.puts "Received #{byte_size(response)} bytes"
```

---

## ???

```[.highlight: 11]
HTTP/1.1 200 OK
Server: Apache
... snip ...

Frankenstein;
or, the Modern Prometheus

by

Mary Wollston
==== Received 1440 bytes ====
```

---

## Stream abstraction breakdown

* The OS maintains its own receiving and sending buffers
* As packets come in from the network, they are written there
* The BSD socket API reads and writes from/to these buffers
* As our code reads from the buffer, room is made for new data
* Small responses may fit entirely in the buffer -- **confusion!**
* Need a way to know when sender is done sending

![](annie-spratt-593479-unsplash.jpg)

---

## Enter protocols

* Pre-agreed ways of controlling communications.
* e.g. for HTTP requests, end with two `CRLF`: 
    `"GET / HTTP/1.0 \r\n\r\n"`
* e.g. for HTTP responses, close the connection:

```[.highlight: 7]
$ telnet google.com 80
GET / HTTP/1.0

HTTP/1.0 302 Found
... snip ...
</BODY></HTML>
Connection closed by foreign host.
```

---

## Shared understanding

* What should I expect?
* How big is the payload?
* What happens next?


---

## How big is the payload?

```[.highlight: 7]
HTTP/1.1 200 OK
Server: Apache
Last-Modified: Sat, 13 January 2018 15:04:24 GMT
<snip>
ETag: "6e25a016"
Content-Type: text/plain; charset=UTF-8
Content-Length: 450783
Date: Tue, 03 Apr 2018 09:06:40 GMT

```

---

```[.highlight: 7] elixir 
{:ok, socket} = :gen_tcp.connect('www.gutenberg.org', 80,
                                  [:binary, active: false])
:ok = :gen_tcp.send(socket,
                    ["GET /files/84/84-0.txt HTTP/1.1\r\n",
                    "Host: www.gutenberg.org\r\n",
                    "Accept: */*\r\n\r\n"])
response = _recv(socket, [])
IO.puts "Received #{byte_size(response)} bytes"
```

---

```elixir
def _recv(socket, acc) do
  r = :gen_tcp.recv(socket, 0, 5000)
  case r do
    {:ok, data} -> _recv(socket, [data|acc])
    other -> # {:error, :timeout}
      Enum.reverse(acc) |> IO.iodata_to_binary()
  end
end
```

```
==== Received 451357 bytes ====
```
(`Content-Length` excludes headers!)

---

## Common Protocols

* HTTP
* SSH
* FTP
* SMTP
* POP3
* TLS/SSL
* <your own>

---

## Built-in protocols

* `:inet.setopts/2`
* `[packet: N]`, N in (1, 2, 4), send/receive
* `line` (receive only)

---


## Recap

* IP is an unreliable, packet-based transport
* TCP is a reliable, stream-based layer over IP
* Protocols give meaning to the stream

---

## Back to the code

---

## Passive, or, "non-active mode"

* Blocking API
* Direct flow control (what happens next)
* Very similar to other languages
* Must spawn a dedicate process

---

## Active mode

* Receive data and events as messages

```elixir
def hello do
  {:ok, socket} = :gen_tcp.connect('www.google.com', 80,
                                   [:binary, active: true])
  :ok = :gen_tcp.send(socket, "GET / HTTP/1.0 \r\n\r\n")
  recv()
end
```

---

```elixir
def recv do
  receive do
    {:tcp, socket, msg} ->
        IO.puts msg
        recv()
    {:tcp_closed, socket} -> 
        IO.puts "=== Closed ==="
    {:tcp_error, socket, reason} -> 
        IO.puts "=== Error #{inspect reason} ==="
  end
end
```

## Active mode

* Inverse the control flow
* Can be used in a GenServer (`handle_info`)
* Makes the protocol logic a bit harder to follow
* Can overflow your server -- no back-pressure

## Hybrid mode

* Instead of `[active: true]`, `[active: N]` or `[active: :once]`
* Receive N data messages, then go back to passive mode
* Return to active mode by calling `:inet.setopts(socket, options)`

<!--

How to know how much data to read?
What happens

-->

<!-- 

Sections
* Quick Overview / Bibliography
* Concepts
    * IP Primer
    * TCP/IP layer
    * BSD Socket API abstraction
    * Erlang Ports?
* gen_tcp clients
    * connect passive quickstart (create a socket, pass in options, call functions on socket)
    * Example: connect to a simple math server, send arithmetic, get back answer.
    * Example: connect to google.com, send simplest HEAD request, receive result
    * connect active — concept of controlling process
    * Same examples with active mode
    * Pitfalls
        * Timeouts on send
        * Timeouts on receive
        * Backpressure
        * Half-closed sockets
        * Implementing a client protocol in active vs passive mode
* `gen_tcp` servers
    * listen at port
    * accept a socket
    * read/write to a socket (same as before)
    * Pitfalls
        * managing the listener, acceptor, handler
        * you probably want to use ranch
* ranch for servers
    * listener
    * transport
    * protocol
* ranch for clients???

-->
