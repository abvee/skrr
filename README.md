# Setup
## Download Raylib
You will first need Raylib.

Download it according to your operating system. For Linux:
```
wget https://github.com/raysan5/raylib/releases/download/5.5/raylib-5.5_linux_amd64.tar.gz
```
Extract it to the root of the project folder:
```
tar xf raylib-5.5_linux_amd64.tar.gz
```
## Installing
Run:
```
zig build
```
to build the binaries

## TODO
UDP and out of order arriving is a pain quite frankly. I was thinking of making
a TCP server for all the packets that require confirmation and not a firehose.
So, a TCP socket for sending joining information, disconnection information etc,
so I can know for sure that a user has joined to a particular client.

UDP is fine for player tracking, though even with sending a packet every 0.1
seconds, it's still laggy.

So, it's time to look at some lerping and linear interpolation.

I should also split the server into multiple files btw, and probably move that
reciever function into the network file so I can stop exposing the network ops.
This would mean passing everything into the reciever function, which I don't
like, but it's easily movable.
