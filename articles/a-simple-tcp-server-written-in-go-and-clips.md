title: A Simple TCP Server Written in Go and CLIPS
description: This article describes a TCP chat server implemented with CLIPS
date: 2022-12-30
css: syntax.css
---
### Introduction

When you're first introduced to [CLIPS](https://www.clipsrules.net/), it may
not be clear how to feed data into and use output from your rules engine.
This presents a major stumbling block when fitting CLIPS into your everyday
software architecture. Fear not, dear reader. Today, I'll show you how to
implement an **I/O Router** in CLIPS.

The Routers we create in this article will read from and write to [TCP
socket
connections](https://www.ibm.com/docs/en/zvse/6.2?topic=SSB27H_6.2.0/fa2ti_what_is_socket_connection.htm)
opened by remote users. Our server will provide a multi-user environment for
these users known as a "chatroom." Users will be able to connect, send
messages into, and disconnect from the chatroom. Additionally, they'll see
when other users connect, disconnect, and send messages. Above all: this
article will demonstrate a thin "wrapper" that exposes a CLIPS application
to the network. With this, you could develop any kind of web application in
CLIPS that you'd like.

Without further ado, let's get started!

### Listening on a Port

First, we'll use Go's `[net](https://pkg.go.dev/net)` package to
listen on a port of our computer:

```go
package main

import (
  "bufio"
  "fmt"
  "log"
  "net"
)

func main() {
  listener, err := net.Listen("tcp", "localhost:5678")
  if err != nil {
    log.Fatal(err)
  }
  defer listener.Close()
  fmt.Println("Now accepting tcp connections at localhost:5678...")

  for {
    conn, err := listener.Accept()
    if err != nil {
      log.Fatal(err)
    }
    go handleRequest(&conn)
  }
}

func handleRequest(conn *net.Conn) {
  (*conn).Write([]byte("Welcome to the chatroom!\n"))
  reader := bufio.NewReader(*conn)
  for {
    message, err := reader.ReadString('\n')
    if err != nil {
      (*conn).Close()
      return
    }
    fmt.Printf("Message from user: %s", message)
  }
}
```

The first thing our `main` function does is "listen" on the ip/domain and
port number that we specify. In our case, we're listening on the domain
`localhost` and port number `5678`. TCP clients will use this combo to
connect to our server. After doing some basic error checking, we
`[defer](https://go.dev/tour/flowcontrol/12)
[listener.Close()](https://pkg.go.dev/net#TCPConn.Close)` to ensure we
clean up when we exit.

After reporting that our server is ready to accept connections, we wait.
`[listener.Accept()](https://pkg.go.dev/net#TCPListener.Accept)`
will run when a client tries to connect. If there are no errors, we pass a
connection pointer to a go routine that will then read messages sent by the
client.

We send a message over the socket to the newly connected client welcoming
them to the chatroom. Then we create a "reader" for the connection. This
will allow us to read messages sent by the client. We then look for the `\n`
(new line) character to signal the "end" of a message. Finally, we write a
received message to standard output (STDOUT).

You'll also want to create a `go.mod` file that looks like this:

```
module clips-tcp

go 1.17
```

Now we'll run it:

```
$ go run .
Now accepting tcp connections at localhost:5678...
```

Alright, now we'll use
`[nc](https://en.wikipedia.org/wiki/Netcat)` to open a TCP
connection to our server. We'll also send a message "hi there" to the server
by typing in the terminal and hitting "enter":

```
$ nc localhost 5678
Welcome to the chatroom!
hi there
```

Now look at the output of your server:

```bash focus={3}
$ go run .
Now accepting tcp connections at localhost:5678...
Message from user: hi there
```

Nice, looks like we're able to send and receive messages between TCP clients
and the server.

### Bringing in CLIPS

Now we'll bring CLIPS in to the mix. We'll [download
it](https://sourceforge.net/projects/clipsrules/files/CLIPS/6.40/) into our
TCP server's directory, untar it, and then remove the `main.c` file provided
by the tar archive:

```
$ wget https://sourceforge.net/projects/clipsrules/files/CLIPS/6.40/clips_core_source_640.tar.gz
# ... truncated output ...
HTTP request sent, awaiting response... 302 Found
Location: https://versaweb.dl.sourceforge.net/project/clipsrules/CLIPS/6.40/clips_core_source_640.tar.gz [following]
--2022-12-11 16:32:46--  https://versaweb.dl.sourceforge.net/project/clipsrules/CLIPS/6.40/clips_core_source_640.tar.gz
Resolving versaweb.dl.sourceforge.net (versaweb.dl.sourceforge.net)... 162.251.232.173
Connecting to versaweb.dl.sourceforge.net (versaweb.dl.sourceforge.net)|162.251.232.173|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 1082012 (1.0M) [application/x-gzip]
Saving to: ‘clips_core_source_640.tar.gz’

clips_core_source_640.ta 100%[===============================>]   1.03M  2.97MB/s    in 0.3s    

2022-12-11 16:32:51 (2.97 MB/s) - ‘clips_core_source_640.tar.gz’ saved [1082012/1082012]
$ tar --strip-components=2 -xvf clips_core_source_640.tar.gz
# ... truncated output ...
$ rm ./main.c
```

Now we'll update our `main.go` file:

```go focus={8,11-16,19-23,24:1-2}
package main

import (
  "bufio"
  "fmt"
  "log"
  "net"
  "unsafe"
)

/*
#cgo CFLAGS: -std=c99 -O3 -fno-strict-aliasing -Wno-unused-result
#cgo LDFLAGS: -lm
#include "clips.h"
*/
import "C"

func main() {
  env := C.CreateEnvironment()
  defer C.DestroyEnvironment(env)
  batch := C.CString("./server.bat")
  defer C.free(unsafe.Pointer(batch))
  C.BatchStar(env, batch)
  listener, err := net.Listen("tcp", "localhost:5678")
  if err != nil {
    log.Fatal(err)
  }
```

We use [Cgo](https://pkg.go.dev/cmd/cgo) to call CLIPS functions (which are
written in C) from our Go application. The CLIPS functions are available by
prefixing calls to them with `C.` in our Go code. The comment block above
the `import "C"` line specifies the `CFLAGS` and `LDFLAGS` that the compiler
should use when compiling CLIPS. We use `#include "clips.h"` to include the
CLIPS library in our Go application. This will let us directly call CLIPS
functions written in C from our Go application.

In our `main` function, we create a CLIPS environment with
`C.CreateEnvironment`. We once again use `defer` to ensure cleaning up upon
application exit. Then, we use `C.BatchStar` to load in a "batch file"
containing our CLIPS code named `server.bat`. Note that we must convert Go
strings into C strings (technically `*C.char`s or "pointers to chars" in C)
when passing them as arguments to CLIPS functions. `C.CString` allocates
memory "on the heap" in order to create a C string from a Go String.
Therefor, we must free up the memory at the end of our program with
`C.free`.

One thing of note: starting our server with `go run .` will take longer than
before. That's because we re-compile CLIPS each time we make changes to
`main.go`. If we do not change the code in `main.go` between restarts,
`go run .` will start our server much faster.

Now we'll create our `server.bat` file that CLIPS will run with
`C.BatchStar` above:

```clips

(println "Hello, CLIPS!")
```

Fire up your server with `go run .` and check the output:

```
$ go run .
Hello, CLIPS!
Now accepting tcp connections at localhost:5678...
```

Perfect. Now we can run CLIPS code from our Go code. Let's tie these two
features together.

### Connections and Disconnections

We'll update our code a bit to identify each connection with a unique id.
This will get around [issues that can occur when passing Go pointers to C
code](https://pkg.go.dev/cmd/cgo#hdr-Passing_pointers). Then we'll tell
CLIPS when these ids connect and disconnect. First, let's add an import for
a package that can generate uuids to the top of `main.go`:

```c focus={6,7:1-2}
package main

import (
  "bufio"
  "fmt"
  "github.com/google/uuid"
  "log"
  "net"
  "strings"
  "unsafe"
)
```

Now we'll make a [channel](https://go.dev/tour/concurrency/2) that receives
these uuids. This is how you pass data between
[goroutines](https://go.dev/tour/concurrency/1) in Go. Both our TCP message
listener `handleRequest` and rules engine "run loops" execute in goroutines.
Let's create that "run loop" for our rules engine in our `main` function:

```go focus={8,17-25,27:1-2}
/*
#cgo CFLAGS: -std=c99 -O3 -fno-strict-aliasing -Wno-unused-result
#cgo LDFLAGS: -lm
#include "clips.h"
*/
import "C"

var connections = make(chan string)

func main() {
  env := C.CreateEnvironment()
  defer C.DestroyEnvironment(env)
  batch := C.CString("./server.bat")
  defer C.free(unsafe.Pointer(batch))
  C.BatchStar(env, batch)

  go func(env *C.Environment) {
    for {
      id := <-connections
      fact_c := C.CString(fmt.Sprintf("(connection %s)", id))
      C.AssertString(env, fact_c)
      C.free(unsafe.Pointer(fact_c))
      C.Run(env, -1)
    }
  }(env)

  listener, err := net.Listen("tcp", "localhost:5678")
  if err != nil {
    log.Fatal(err)
  }
```

By putting `go` in front of a function call, we tell the function to execute
[concurrently](https://www.youtube.com/watch?v=f6kdp27TYZs). This
concurrency means it runs at the same time as the code following it. Our
function runs a `for` loop that loops infinitely. When a uuid is sent over
the `connections` channel, we capture it in the `id` variable. We then
assert a fact into our rules engine that represents the connection. Finally,
we run our rules engine.

Let's create this uuid in the `handleRequest` function and put it into the
channel:

```go focus={3-4,5:1-2,12-13,14:1-2}
func handleRequest(conn *net.Conn) {
  (*conn).Write([]byte("Welcome to the chatroom!\n"))
  id := uuid.NewString()
  connections <- id
  reader := bufio.NewReader(*conn)
  for {
    message, err := reader.ReadString('\n')
    if err != nil {
      (*conn).Close()
      return
    }
    //fmt.Printf("Message from user: %s", message)
    fmt.Printf("Message from user %s: %s", id, message)
  }
}
```

We'll replace our `server.bat` file with the following:

```clips
(defrule connection
  (connection ?id)
  =>
  (println "User " ?id " connected"))
```

Before we restart our server, we'll need to use `go get` to retrieve the
uuid package from the internet:

```
$ go get github.com/google/uuid
go: added github.com/google/uuid v1.3.0
```

If you do not do the above, you may see the following error:

```
$ go run .
main.go:6:3: no required module provides package github.com/google/uuid; to add it:
        go get github.com/google/uuid
```

Now we'll run our server, connect to it from a client, and send a little
"hi" message:

```
$ nc localhost 5678
Welcome to the chatroom!
hi
```

Check the output from the server:

```
$ go run .
Now accepting tcp connections at localhost:5678...
User bc79b2b6-4bdc-4692-9d61-d2e2013cec49 connected
Message from user bc79b2b6-4bdc-4692-9d61-d2e2013cec49: hi
```

Cool. Now each user that connects has an id. Let's add a bit more code to
implement disconnections. In our `main.go` file, we'll create another
channel for disconnections:

```go focus={9}
/*
#cgo CFLAGS: -std=c99 -O3 -fno-strict-aliasing -Wno-unused-result
#cgo LDFLAGS: -lm
#include "clips.h"
*/
import "C"

var connections = make(chan string)
var disconnections = make(chan string)

func main() {
  env := C.CreateEnvironment()
  defer C.DestroyEnvironment(env)
  batch := C.CString("./server.bat")
```

Now update the "run loop" go routine in our `main` function like so:

```go focus={3-7,8:1-9,8:29,9:1-6,12-16}
go func(env *C.Environment) {
  for {
    //id := <-connections
    //fact_c := C.CString(fmt.Sprintf("(connection %s)", id))
    //C.AssertString(env, fact_c)
    //C.free(unsafe.Pointer(fact_c))
    select {
    case id := <-connections:
      fact_c := C.CString(fmt.Sprintf("(connection %s)", id))
      C.AssertString(env, fact_c)
      C.free(unsafe.Pointer(fact_c))
    case id := <-disconnections:
      fact_c := C.CString(fmt.Sprintf("(disconnection %s)", id))
      C.AssertString(env, fact_c)
      C.free(unsafe.Pointer(fact_c))
    }
    C.Run(env, -1)
  }
}(env)
```

The `select` waits for the values received from one of the channels in its
`case` statements. Once one of the channels recieves a message, that block
of code runs. We'll use this functionality to receive messages on either our
`connections` or `disconnections` channel.

Now we'll send the id into that channel when the client disconnects. Update
your `handleRequest` like so:

```c focus={10,11:1-6}
func handleRequest(conn *net.Conn) {
  (*conn).Write([]byte("Welcome to the chatroom!\n"))
  id := uuid.NewString()
  connections <- id
  reader := bufio.NewReader(*conn)
  for {
    message, err := reader.ReadString('\n')
    if err != nil {
      (*conn).Close()
      disconnections <- id
      return
    }
    fmt.Printf("Message from user %s: %s", id, message)
  }
}
```

Let's update our CLIPS code to respond usefully to these disconnection
facts:

```clips focus={6-11}
(defrule connection
  (connection ?id)
  =>
  (println "User " ?id " connected"))

(defrule disconnection
  ?f <- (connection ?id)
  (disconnection ?id)
  =>
  (retract ?f)
  (println "User " ?id " disconnected"))
```

Start your server, then connect to it. Disconnect once, then re-connect so
that you can see the disconnect message:

```
$ nc localhost 5678
Welcome to the chatroom!
greetings
^C
$ nc localhost 5678
Welcome to the chatroom!
hiya
```

The `^C` in the above means we hit the `ctrl` and `c` keys on our keyboard
at the same time. This exits `nc`. Take a look at the output from the
server:

```
$ go run .
Now accepting tcp connections at localhost:5678...
User dc76184a-c911-4836-9629-8cda7e676ccb connected
Message from user dc76184a-c911-4836-9629-8cda7e676ccb: greetings
User dc76184a-c911-4836-9629-8cda7e676ccb disconnected
User 461e1953-cc4b-413d-822d-75400f432bb1 connected
Message from user 461e1953-cc4b-413d-822d-75400f432bb1: hiya
```

Everything's looking great so far. Now all we need to do is feed messages
from users into CLIPS. This is where Routers come in, so buckle up.

### CLIPS I/O Routers Written in Go

In order to put data into and get it out of our rules engine, we use I/O
Routers. The default router in CLIPS is named `t`. It writes to STDOUT, and
it reads from STDIN. When we use `println`, `readline` or other input/output
functions, it uses the `t` router by default. What we'll do for our TCP
server is add a Router each time a socket connection occurs. The name of the
Router will be the uuid we created for the connection. This will allow us to
do things like `(printout ?uuid "Hello, socket!")` in the antecedent of
Rules. We'll delete these Routers when their respective sockets disconnect.

We'll need to call a function provided by CLIPS called `AddRouter`. The
[Advanced Programmers
Guide](https://www.clipsrules.net/documentation/v640/apg640.pdf) describes
this function in detail. From a high-level, it allows us to specify
functions for writing to and reading from a given Router.

Let's start with two functions: one will name our Router, the other will
write to it:

```c focus={5-6}
/*
#cgo CFLAGS: -std=c99 -O3 -fno-strict-aliasing -Wno-unused-result
#cgo LDFLAGS: -lm
#include "clips.h"
bool QueryCallback(Environment *,char *,void *);
void WriteCallback(Environment *,char *,char *,void *);
*/
import "C"
```

We have to declare our functions like this so that we can reference them as
C functions (prefixed with `C.`) in the call to `AddRouter`.

Unfortunately, it is not a good idea to pass Go pointers to C functions.
Pointers in Go are periodically garbage collected. What we pass to C may not
be the same thing later during the lifetime of our application. This is one
reason why we identify TCP connections with uuids.

We'll create a `map` called `idsToConnections` that uses uuids as its keys.
The uuids will point to a `struct`:

```go focus={4-7,9}
*/
import "C"

type Connection struct {
  id   string
  conn *net.Conn
}

var idsToConnections = make(map[string] *Connection)

var connections = make(chan string)
```

We'll also update our `connections` channel so that it receives pointers to
our new structs instead of strings:

```go
//var connections = make(chan string)
var connections = make(chan *Connection)
```

Now we'll create our `QueryCallback` function. This function should return
`true` if the Router we try to read from/write to exists. We'll check
`idsToConnections` for the presence of a key matching the connection's uuid.
If it's there, we'll return `true`:

```go focus={4-8}
var connections = make(chan *Connection)
var disconnections = make(chan string)

//export QueryCallback
func QueryCallback(e *C.Environment, logicalName *C.char, _ unsafe.Pointer) C.bool {
  _, ok := idsToConnections[C.GoString(logicalName)]
  return C.bool(ok)
}
```

And now our `WriteCallback` function:

```go focus={1-6}
//export WriteCallback
func WriteCallback(e *C.Environment, logicalName *C.char, str *C.char, context unsafe.Pointer) {
  if _, err := (*idsToConnections[C.GoString(logicalName)].conn).Write([]byte(C.GoString(str))); err != nil {
    log.Printf("WARNING: attempting to send message to socket %s errored: %s", C.GoString(logicalName), err)
  }
}

func main() {
```

Note the `(*idsToConnections[C.GoString(logcialName)].conn)` part. We must
do this because `conn` is a pointer to a `net.conn` struct. Thus we must use
an asterisk (`*`) to reference the value pointed to by the pointer. We
`[Write](https://pkg.go.dev/net#TCPConn.Write)` a
[slice](https://go.dev/tour/moretypes/7) of `byte`s to this connection. We
create this slice from the string `str` we attempt to write to this Router.
Note that we must first convert the C string (or `*C.char`) into a Go string
before converting to a slice of bytes.

We'll call `AddRouter` when the client connects. This will create a Router
with the connection's uuid as its name. Our main `for` loop must be in
charge of mutating `idsToConnections`. We do not want to allow our various
`handleRequest` go routines to modify it since this may introduce a [race
condition](https://go.dev/doc/go1.6#runtime):

```go focus={4-16,17:1-8,20-23,24:1-8}
go func(env *C.Environment) {
    for {
      select {
      //case id := <-connections:
      case connection := <-connections:
        idsToConnections[connection.id] = connection
        //id_c := C.CString(id)
        id_c := C.CString(connection.id)
        C.AddRouter(
          env, id_c, 20,
          (*C.RouterQueryFunction)(unsafe.Pointer(C.QueryCallback)),
          (*C.RouterWriteFunction)(unsafe.Pointer(C.WriteCallback)),
          nil, nil, nil, nil)
        C.free(unsafe.Pointer(id_c))
        //fact_c := C.CString(fmt.Sprintf("(connection %s)", id))
        fact_c := C.CString(fmt.Sprintf("(connection %s)", connection.id))
        C.AssertString(env, fact_c)
        C.free(unsafe.Pointer(fact_c))
      case id := <-disconnections:
        delete(idsToConnections, id)
        id_c := C.CString(id)
        C.DeleteRouter(env, id_c)
        C.free(unsafe.Pointer(id_c))
        fact_c := C.CString(fmt.Sprintf("(disconnection %s)", id))
        C.AssertString(env, fact_c)
        C.free(unsafe.Pointer(fact_c))
      }
      C.Run(env, -1)
    }
  }(env)
```

Let's focus on the call to `C.AddRouter`. The `env` is obviously our CLIPS
environment, and the `id_c` is the name of the Router. The `20` is the
"priority" of this Router. Since we can have many Routers in CLIPS, there
are ways to make our rules engine read from/write to some before others.
According to the CLIPS [Advanced Programmers
Guide](https://www.clipsrules.net/documentation/v640/apg640.pdf), priority
`20` is used by:

> Any router that wants to grab standard logical names and is not willing
> to share them with other routers.

The first and second arguments passed to `AddRouter` are the Query callback
and Writer callback functions respectively. The Query callback lets our
rules engine know that a Router exists with a given name. Our Writer will be
used when our rules engine attempts to write to the Router. The next two
`nil` values are where we'll specify our Read and Unread functions. We can
also specify an Exit function, but it is not required if nothing must be
done when we close the application.

The last argument is where we may pass "context" for this router. This is a
void pointer, meaning we could pass any kind of pointer as this parameter.
Unfortunately our TCP connections are pointed to by Go pointers, so we
cannot directly pass the TCP connection as the Router context.

Now, enough of that sad bit of news. Let's continue with our implementation.
We'll update our `handleResponse` function to create our `Connection` struct
and put it into the `connections` channel:

```c focus={2,3:1-2,4-5,6:1-2}
func handleRequest(conn *net.Conn) {
  //(*conn).Write([]byte("Welcome to the chatroom!\n"))
  id := uuid.NewString()
  //connections <- id
  connections <- &Connection{id, conn}
  reader := bufio.NewReader(*conn)
  for {
    message, err := reader.ReadString('\n')
    if err != nil {
      (*conn).Close()
      disconnections <- id
      return
    }
    fmt.Printf("Message from user %s: %s", id, message)
  }
}
```

We'll move our "Welcome" message into the rules engine now:

```clips focus={5:1-59}
(defrule connection
  (connection ?id)
  =>
  (println "User " ?id " connected")
  (printout ?id "Welcome to the chatroom from CLIPS!" crlf))
```

Let's restart our server and connect to it:

```
$ nc localhost 5678
Welcome to the chatroom from CLIPS!
```

Very nice. Now we can write to our TCP client from within CLIPS!

### Do You Read Me?

In order to read from socket connections, we'll need to add two functions to
our Router: a Read and an Unread function. Read makes sense, but "Unread?"
This is what we must do to simulate removing a character from standard
input. We must do this if we add a Read function to our Router.

First, we'll add our Read and Unread callback function signatures to the top
comment of our `main.go` file:

```c focus={7-8}
/*
#cgo CFLAGS: -std=c99 -O3 -fno-strict-aliasing -Wno-unused-result
#cgo LDFLAGS: -lm
#include "clips.h"
bool QueryCallback(Environment *,char *,void *);
void WriteCallback(Environment *,char *,char *,void *);
int ReadCallback(Environment *,char *,void *);
int UnreadCallback(Environment *,char *,int,void *);
*/
```

We'll add two new things to our `Connection` struct: a slice of bytes and a
channel for slices of bytes. We'll pass slices of bytes received over the
socket connection into the channel. When we begin to read from the Router,
we'll pull a message out of the channel and set it to the buffer. This will
allow us to read individual characters from the slice in the Read callback
as well as "shift" bytes back onto the beginning of the slice for the Unread
callback.

```go focus={4-5}
type Connection struct {
  id            string
  conn          *net.Conn
  buffer        []byte
  bufferChannel chan []byte
}
```

Alright, here we go: the Read function:

```go
//export ReadCallback
func ReadCallback(e *C.Environment, logicalName *C.char, context unsafe.Pointer) C.int {
  id := C.GoString(logicalName)
  connection := idsToConnections[id]
  if len(connection.buffer) == 0 {
    connection.buffer = append(connection.buffer, <-connection.bufferChannel...)
  }
  ch := connection.buffer[0]
  connection.buffer = connection.buffer[1:]
  return C.int(ch)
}
```

And now: the Unread:

```go
//export UnreadCallback
func UnreadCallback(e *C.Environment, logicalName *C.char, ch C.int, context unsafe.Pointer) C.int {
  id := C.GoString(logicalName)
  idsToConnections[id].buffer = append([]byte{byte(ch)}, idsToConnections[id].buffer...)
  return C.int(ch)
}
```

We'll create a channel that we'll use to notify the rules engine that a
message from a connection has been buffered:

```go focus={3}
var connections = make(chan *Connection)
var disconnections = make(chan string)
var messageBuffered = make(chan string)
```

We'll update our go function that we use to run the rules engine to receive
those `messageBuffered` notifications. We'll also add our Read and Unread to
our `AddRouter` call:

```go focus={11-14,15:1-8,27-30,31:1-6}
go func(env *C.Environment) {
    for {
      select {
      case connection := <-connections:
        idsToConnections[connection.id] = connection
        id_c := C.CString(connection.id)
        C.AddRouter(
          env, id_c, 20,
          (*C.RouterQueryFunction)(unsafe.Pointer(C.QueryCallback)),
          (*C.RouterWriteFunction)(unsafe.Pointer(C.WriteCallback)),
          (*C.RouterReadFunction)(unsafe.Pointer(C.ReadCallback)),
          (*C.RouterUnreadFunction)(unsafe.Pointer(C.UnreadCallback)),
          //nil, nil, nil, nil)
          nil, nil)
        C.free(unsafe.Pointer(id_c))
        fact_c := C.CString(fmt.Sprintf("(connection %s)", connection.id))
        C.AssertString(env, fact_c)
        C.free(unsafe.Pointer(fact_c))
      case id := <-disconnections:
        delete(idsToConnections, id)
        id_c := C.CString(id)
        C.DeleteRouter(env, id_c)
        C.free(unsafe.Pointer(id_c))
        fact_c := C.CString(fmt.Sprintf("(disconnection %s)", id))
        C.AssertString(env, fact_c)
        C.free(unsafe.Pointer(fact_c))
      case id := <-messageBuffered:
        fact_c := C.CString(fmt.Sprintf("(message-buffered %s)", id))
        C.AssertString(env, fact_c)
        C.free(unsafe.Pointer(fact_c))
      }
      C.Run(env, -1)
    }
  }(env)
```

We need to update our `handleRequest` function to account for our new
`buffer` and `bufferChannel` struct properties. We also need to send this
connection's id into the new `messageBuffered` channel when we receive a
message over the socket:

```go focus={3-5,6:1-2,14-17,18:1-2}
func handleRequest(conn *net.Conn) {
  id := uuid.NewString()
  bufferChannel := make(chan []byte)
  //connections <- &Connection{id, conn}
  connections <- &Connection{id, conn, []byte{}, bufferChannel}
  reader := bufio.NewReader(*conn)
  for {
    message, err := reader.ReadString('\n')
    if err != nil {
      (*conn).Close()
      disconnections <- id
      return
    }
    //fmt.Printf("Message from user %s: %s", id, message)
    message = strings.TrimSpace(message)
    messageBuffered <- id
    bufferChannel <- append([]byte(message), byte('\n'))
  }
}
```

You may note that we use `strings.TrimSpace` to remove whitespace from the
beginning and end of the message sent over the connection. We'll need to add
`strings` to our `import` statement at the top of this file:

```c focus={7,8:1-2}
import (
  "bufio"
  "fmt"
  "github.com/google/uuid"
  "log"
  "net"
  "strings"
  "unsafe"
)
```

You may have also noted we commented out the `fmt.Printf` that would tell us
the message sent over the connection. Now that we've added `ReadCallback`
and `UnreadCallback` to our Router, we can do this in CLIPS:

```clips focus={14-19}
(defrule connection
  (connection ?id)
  =>
  (println "User " ?id " connected")
  (printout ?id "Welcome to the chatroom from CLIPS!" crlf))

(defrule disconnection
  ?f <- (connection ?id)
  (disconnection ?id)
  =>
  (retract ?f)
  (println "User " ?id " disconnected"))

(defrule message-buffered
  (connection ?id)
  ?f <- (message-buffered ?id)
  =>
  (retract ?f)
  (println "Message from user " ?id ": " (readline ?id)))
```

Alright, restart your server, connect to it using `nc`, send a message, and
then disconnect:

```
$ nc localhost 5678              
Welcome to the chatroom from CLIPS!
hello, world!
^C
```

Take a look at the output from your server:

```
$ go run .
Now accepting tcp connections at localhost:5678...
User 87266f2e-ae31-4da3-9492-104d7db9cbb7 connected
Message from user 87266f2e-ae31-4da3-9492-104d7db9cbb7: hello, world!
User 87266f2e-ae31-4da3-9492-104d7db9cbb7 disconnected
```

Very nice. Now we can read from and write to the socket connection from
within CLIPS!

### Is There Anybody Out There?

At this point, we can start purely writing CLIPS code to extend our server.
No matter what kind of application we want to make, we can write the
business logic as rules in our rules engine. Let's update the
`message-buffered` rule so that it will broadcast a message received from
one connection to all other connections currently in the server:

```clips focus={19-24}
(defrule connection
  (connection ?id)
  =>
  (println "User " ?id " connected")
  (printout ?id "Welcome to the chatroom from CLIPS!" crlf))

(defrule disconnection
  ?f <- (connection ?id)
  (disconnection ?id)
  =>
  (retract ?f)
  (println "User " ?id " disconnected"))

(defrule message-buffered
  (connection ?id)
  ?f <- (message-buffered ?id)
  =>
  (retract ?f)
  ;(println "Message from user " ?id ": " (readline ?id)))
  (bind ?message (readline ?id))
  (println "Message from user " ?id ": " ?message)
  (printout ?id "You: " ?message crlf)
  (do-for-all-facts ((?f connection)) (neq ?id (nth$ 1 ?f:implied))
    (printout (nth$ 1 ?f:implied) ?id ": " ?message crlf)))
```

By now, you know what to do: restart your server, then connect to it with
`nc`. To experience the full effect of a realtime chatroom, open another
terminal to connect to the server. This will simulate a conversation between
two people. One client will look like this:

```
$ nc localhost 5678
Welcome to the chatroom from CLIPS!
hi all
You: hi all
how's it going in here
You: how's it going in here
5e74b296-dc21-4551-8a73-c4ed04615522: it's going well :)
```

The other should look something like this:

```
$ nc localhost 5678
Welcome to the chatroom from CLIPS!
4ee2a03e-c477-4c58-b715-258df333af95: hi all
4ee2a03e-c477-4c58-b715-258df333af95: how's it going in here
it's going well :)
You: it's going well :)
```

Your server output should look something like this:

```
$ go run .
Now accepting tcp connections at localhost:5678...
User 5e74b296-dc21-4551-8a73-c4ed04615522 connected
User 4ee2a03e-c477-4c58-b715-258df333af95 connected
Message from user 4ee2a03e-c477-4c58-b715-258df333af95: hi all
Message from user 4ee2a03e-c477-4c58-b715-258df333af95: how's it going in here
Message from user 5e74b296-dc21-4551-8a73-c4ed04615522: it's going well :)
```

Very nice. Things are looking like a proper chatroom. Let's add some
notifications for when users connect to and disconnect from the server:

```clips focus={6,7:1-65,15,16:1-68}
(defrule connection
  (connection ?id)
  =>
  (println "User " ?id " connected")
  (printout ?id "Welcome to the chatroom from CLIPS!" crlf)
  (do-for-all-facts ((?f connection)) (neq ?id (nth$ 1 ?f:implied))
    (printout (nth$ 1 ?f:implied) "User " ?id " connected" crlf)))

(defrule disconnection
  ?f <- (connection ?id)
  (disconnection ?id)
  =>
  (retract ?f)
  (println "User " ?id " disconnected")
  (do-for-all-facts ((?f connection)) TRUE
    (printout (nth$ 1 ?f:implied) "User " ?id " disconnected" crlf)))

(defrule message-buffered
  (connection ?id)
  ?f <- (message-buffered ?id)
  =>
  (retract ?f)
  (bind ?message (readline ?id))
  (println "Message from user " ?id ": " ?message)
  (printout ?id "You: " ?message crlf)
  (do-for-all-facts ((?f connection)) (neq ?id (nth$ 1 ?f:implied))
    (printout (nth$ 1 ?f:implied) ?id ": " ?message crlf)))
```

Restart your server and connect to it using `nc`. We'll then simulate a new
user connecting and subsequently disconnecting:

```
$ nc localhost 5678
Welcome to the chatroom from CLIPS!
User 4aa56a3a-329c-4c2c-8121-d821461ffe33 connected
4aa56a3a-329c-4c2c-8121-d821461ffe33: hi all
4aa56a3a-329c-4c2c-8121-d821461ffe33: ... hello?
4aa56a3a-329c-4c2c-8121-d821461ffe33: ok, bye...
User 4aa56a3a-329c-4c2c-8121-d821461ffe33 disconnected
```

Now, from User `4aa56a3a-329c-4c2c-8121-d821461ffe33`'s perspective:

```
$ nc localhost 5678
Welcome to the chatroom from CLIPS!
hi all
You: hi all
... hello?
You: ... hello?
ok, bye...
You: ok, bye...
^C
```

The output of our server should look something like:

```
$ go run .
Now accepting tcp connections at localhost:5678...
User ffad2a24-6ecd-4b54-aa2d-89977912e77a connected
User 4aa56a3a-329c-4c2c-8121-d821461ffe33 connected
Message from user 4aa56a3a-329c-4c2c-8121-d821461ffe33: hi all
Message from user 4aa56a3a-329c-4c2c-8121-d821461ffe33: ... hello?
Message from user 4aa56a3a-329c-4c2c-8121-d821461ffe33: ok, bye...
User 4aa56a3a-329c-4c2c-8121-d821461ffe33 disconnected
```

Let's add in one more feature for good measure. Often times in chatrooms,
users are able to send a message that starts with `/me`. This makes their
text appear different in the chatroom. It is often used to differentiate an
action from "spoken" word. We'll check the first "word" (characters before a
space) of a message. If it's `/me`, we'll echo their message differently in
the chatroom. Update your CLIPS code like so:

```clips focus={22,23:1-2,25-28,30-39,41-51}
(defrule connection
  (connection ?id)
  =>
  (println "User " ?id " connected")
  (printout ?id "Welcome to the chatroom from CLIPS!" crlf)
  (do-for-all-facts ((?f connection)) (neq ?id (nth$ 1 ?f:implied))
      (printout (nth$ 1 ?f:implied) "User " ?id " connected" crlf)))

(defrule disconnection
  ?f <- (connection ?id)
  (disconnection ?id)
  =>
  (retract ?f)
  (println "User " ?id " disconnected")
  (do-for-all-facts ((?f connection)) TRUE
      (printout (nth$ 1 ?f:implied) "User " ?id " disconnected" crlf)))

(defrule message-buffered
  (connection ?id)
  ?f <- (message-buffered ?id)
  =>
  ;(retract ?f)
  (bind ?message (readline ?id))
  (println "Message from user " ?id ": " ?message)
  ;(printout ?id "You: " ?message crlf)
  ;(do-for-all-facts ((?f connection)) (neq ?id (nth$ 1 ?f:implied))
  ;  (printout (nth$ 1 ?f:implied) ?id ": " ?message crlf)))
  (assert (message ?id (string-to-field ?message) ?message)))

(defrule action
  (connection ?id)
  ?f <- (message-buffered ?id)
  ?ff <- (message ?id /me ?message)
  =>
  (retract ?f ?ff)
  (printout ?id "* You " (sub-string 5 (str-length ?message) ?message) crlf)
  (do-for-all-facts ((?f connection)) (neq ?id (nth$ 1 ?f:implied))
    (printout (nth$ 1 ?f:implied)
     "* " ?id " " (sub-string 5 (str-length ?message) ?message) crlf)))

(defrule say
  (connection ?id)
  ?f <- (message-buffered ?id)
  ?ff <- (message ?id ~/me ?message)
  =>
  (retract ?f ?ff)
  (printout ?id "You: " ?message crlf)
  (do-for-all-facts ((?f connection)) (neq ?id (nth$ 1 ?f:implied))
    (printout (nth$ 1 ?f:implied)
     ?id ": " ?message crlf)))
    
```

Time once again to test! Restart your server, and connect to it with 2
separate connections. Try sending a message that starts with `/me` as well
as some without:

```
$ nc localhost 5678
Welcome to the chatroom from CLIPS!
Hi everyone
You: Hi everyone
/me waves to the chatroom
* You waves to the chatroom
ok bye
You: ok bye
```

Your other connection should see something like this:

```
$ nc localhost 5678
Welcome to the chatroom from CLIPS!
User 93bf4c10-62d3-4b1d-947c-61bfb801bc2e connected
93bf4c10-62d3-4b1d-947c-61bfb801bc2e: Hi everyone
* 93bf4c10-62d3-4b1d-947c-61bfb801bc2e waves to the chatroom
93bf4c10-62d3-4b1d-947c-61bfb801bc2e: ok bye
```

Our server output should be nothing surprising:

```
$ go run .
Now accepting tcp connections at localhost:5678...
User 5081079b-a1dd-4022-838d-5d8f05f456fb connected
User 93bf4c10-62d3-4b1d-947c-61bfb801bc2e connected
Message from user 93bf4c10-62d3-4b1d-947c-61bfb801bc2e: Hi everyone
Message from user 93bf4c10-62d3-4b1d-947c-61bfb801bc2e: /me waves to the chatroom
Message from user 93bf4c10-62d3-4b1d-947c-61bfb801bc2e: ok bye
```

### Conclusion

Let's recount everything we've done in this article. We've created a
multiuser expert system known as a "chatroom." This expert system is
accessible over a network connection, so users can use different machines in
different locations. From a higher perspective: we leverage a CLIPS rules
engine from within a Go application. Even cooler: the framework we've
created in Golang can be used to run any rules engine written in CLIPS.

\- ryjo
