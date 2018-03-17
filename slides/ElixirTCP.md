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
