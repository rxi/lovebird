# lovebird
A debug console for [LÖVE](http://love2d.org) which runs in the browser.


## Usage
Drop the [lovebird.lua](#) file into an existing project and place the
following line at the top of your `love.update()` function:
```lua
require("lovebird").update()
```
The console can then be accessed by opening the following URL in your web
browser:
```
http://localhost:8000
```
See the section below on *lovebird.whitelist* if you want to access lovebird
from a computer other than the one which LÖVE is running on.


## Additional Functionality
To make use of additional functionality, the lovebird module can be assigned to
a variable when it is required:
```lua
lovebird = require "lovebird"
```
Any configuration variables should be set before lovebird.update()` is called.

### lovebird.port
The port which lovebird listens for connections on. By default this is `8000`

### lovebird.whitelist
A table of hosts which lovebird will accept connections from. Any connection
made from a host which is not on the whitelist is logged and closed
immediately. If `lovebird.whitelist` is set to nil, all connections are
accepted. The default is `{ "127.0.0.1", "localhost" }`

### lovebird.wrapprint
Whether lovebird should wrap the `print()` function or not. If this is true
then all the calls to print will also be output to lovebird's console. This is
`true` by default.

### lovebird.maxlines
The maximum number of lines lovebird should store in its console's output
buffer. By default this is `200`.

### lovebird.refreshrate
The rate in seconds which the output buffer is refreshed on lovebird's page.
This is `0.5` by default.

### lovebird.print(...)
Prints its arguments to lovebird's console. If `lovebird.wrapprint` is set to
true this function is automatically called when print() is called.

