WebSocket for luvit2
===============

Websocket Library for Luvit.io 2.

Server works, client is still a WIP.

In the current version luvit-websocket only supports the websocket standard [RFC 6455](http://tools.ietf.org/html/rfc6455),
thus it will only be able to handle connections from Chrome 16, Firefox 11, IE 10 and above.

Also it does not yet support Message Fragmentation.

Besides that, using a simple WebSocket connection in a moden browser should work fine.

Installation:
============
Using [lit](https://github.com/luvit/lit) you can simply add it to the dependencies of your projects or install it by doing:
> lit install b42nk/websocket


Usage:
============
```lua
  local WebSocket = require('websocket')

  local WS = WebSocket.server.new():listen(1734)

  WS:on('connect', function(client)
      print("Client connected.")
      client:send("Welcome!")
  end)

  WS:on('data', function(client, message)
      print(message)
  end)

  WS:on('disconnect', function(client)
      print("Client disconnected.")
  end)

```
