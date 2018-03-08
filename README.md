# Lua value browser
Lua module for interactively printing and browsing Lua values from the standalone interpreter.

Should be compatible with Lua 5.1, 5.2 and 5.3 as well as with LuaJIT.

Installs itself as a parameterless function ```browse``` in the ```debug``` module.

Keeps a history of visited values and therefore keeps references to values that otherwise would have been garbage collected.

Usage:

```
...
> require "debug.browser"
> debug.browse()
Lua value browser 0.2
Copyright (C) 2010-2018, schorg@gmail.com
Type 'q' to quit, 'help' for help
: help
   Browse Lua runtime values, like a web page.

   Available Commands:
   (h)elp  (f)orward (b)ack (r)eload .<link> (t)ab [@]<expr> (q)uit
   
   <enter>     executes one of the above commands
   [@]<expr>   show data entity for Lua <expr>, @ quotes commands
   help (h)    show this message
   forward (f) history forward
   back (b)    history back
   reload (r)  reload current
   .<link>     select .<link>
   .<prefix>   complete to next matching link with prefix .<prefix>
   tab (t)     selects the next link
   quit (q)    quit browser

: _G 
(_G): table
  = {
      _G: table = ._G,
      _VERSION: string = Lua 5.1,
      assert: function = .assert,
      bit: table = .bit,
      collectgarbage: function = .collectgarbage,
      coroutine: table = .coroutine,
      debug: table = .debug,
      dofile: function = .dofile,
      error: function = .error,
      gcinfo: function = .gcinfo,
      getfenv: function = .getfenv,
      getmetatable: function = .getmetatable,
      io: table = .io,
      ipairs: function = .ipairs,
      jit: table = .jit,
      load: function = .load,
      ... and so on
    }
: quit
> debug.browse()
: reload
...
```
    