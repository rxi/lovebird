# lovebird
A browser-based debug console for the [LÖVE](http://love2d.org) framework.

![screenshot from 2014-06-28 14 52 34](https://cloud.githubusercontent.com/assets/3920290/3420901/c15975ce-fecb-11e3-9517-970c919815b4.png)


## Usage
Drop the [lovebird.lua](lovebird.lua?raw=1) file into an existing project and
place the following line at the top of your `love.update()` function:
```lua
require("lovebird").update()
```
The console can then be accessed by opening the following URL in a web browser:
```
http://127.0.0.1:8000
```
If you want to access lovebird from another computer then `127.0.0.1` should be
replaced with the IP address of the computer which LÖVE is running on; the IP
address of the other computer should be added to the
[lovebird.whitelist](#lovebirdwhitelist) table.


## Additional Functionality
To make use of additional functionality, the module can be assigned to a
variable when it is required:
```lua
lovebird = require "lovebird"
```
Any configuration variables should be set before `lovebird.update()` is called.

### lovebird.port
The port which lovebird listens for connections on. By default this is `8000`

### lovebird.whitelist
A table of hosts which lovebird will accept connections from. Any connection
made from a host which is not on the whitelist is logged and closed
immediately. If `lovebird.whitelist` is set to nil then all connections are
accepted. The default is `{ "127.0.0.1" }`. To allow *all* computers on the
local network access to lovebird, `"192.168.*.*"` can be added to this table.

### lovebird.wrapprint
Whether lovebird should wrap the `print()` function or not. If this is true
then all the calls to print will also be output to lovebird's console. This is
`true` by default.

### lovebird.echoinput
Whether lovebird should display inputted commands in the console's output
buffer; `true` by default.

### lovebird.maxlines
The maximum number of lines lovebird should store in its console's output
buffer. By default this is `200`.

### lovebird.updateinterval
The interval in seconds that the page's information is updated; this is `0.5`
by default.

### lovebird.allowhtml
Whether prints should allow HTML. If this is true then any HTML which is
printed will be rendered as HTML; if it false then all HTML is rendered as
text. This is `false` by default.

### lovebird.print(...)
Prints its arguments to lovebird's console. If `lovebird.wrapprint` is set to
true this function is automatically called when print() is called.

### lovebird.clear()
Clears the contents of the console, returning it to an empty state.
