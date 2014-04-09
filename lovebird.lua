socket = require "socket"

local lovebird = { _version = "0.0.1" }

lovebird.inited = false
lovebird.overrideprint = true
lovebird.host = "*"
lovebird.port = 8000
lovebird.whitelist = { "127.0.0.1", "localhost" }
lovebird.maxbuffer = 20000
lovebird.refreshrate = .5
lovebird.buffer = ""


local loadstring = loadstring or load

local map = function(t, fn)
  local res = {}
  for k, v in pairs(t) do res[k] = fn(v) end
  return res
end

local find = function(t, value)
  for k, v in pairs(t) do
    if v == value then return k end
  end
end

local trace = function(...)
  print("[lovebird] " .. table.concat(map({...}, tostring), " "))
end

local unescape = function(str)
  local f = function(x) return string.char(tonumber("0x"..x)) end
  return (str:gsub("%+", " "):gsub("%%(..)", f))
end


local pagetemplate = [[
<html>
  <head>
  <title>lovebird</title>
  <style>
    #input { width: 600px }
    #output { width: 600px; height: 400px; overflow-y: scroll }
  </style>
  </head>
  <body>
    <div id="output">
      <?lua echo(lovebird.buffer) ?>
    </div>
    <form method="post">
      <input id="input" name="input" type="text" autofocus></input>
    </form>
    <script>
      /* Scroll output to bottom */
      var scrolloutput = function() {
        var div = document.getElementById("output"); 
        div.scrollTop = div.scrollHeight;
      }
      scrolloutput()
      /* Refresh buffer output at intervals */
      var refresh = function() {
        var req = new XMLHttpRequest();
        req.onreadystatechange = function() {
          if (req.readyState != 4) return;
          var div = document.getElementById("output"); 
          if (div.innerHTML != req.responseText) {
            div.innerHTML = req.responseText;
            scrolloutput();
          }
        }
        req.open("GET", "/buffer", true);
        req.send();
      }
      setInterval(refresh, <?lua echo(lovebird.refreshrate) ?> * 1000);
    </script>
  </body>
</html>
]]


function lovebird.init()
  lovebird.server = assert(socket.bind(lovebird.host, lovebird.port))
  lovebird.addr, lovebird.port = lovebird.server:getsockname()
  lovebird.server:settimeout(0)
  if lovebird.overrideprint then
    local oldprint = print
    print = function(...)
      oldprint(...)
      lovebird.print(...)
    end
  end
  lovebird.inited = true
end


function lovebird.template(str, env)
  env = env or {}
  local keys, vals = {}, {}
  for k, v in pairs(env) do 
    table.insert(keys, k)
    table.insert(vals, v)
  end
  local f = function(x) return string.format(" echo(%q)", x) end
  str = ("?>"..str.."<?lua"):gsub("%?>(.-)<%?lua", f)
  str = "local echo, " .. table.concat(keys, ",") .. " = ..." .. str
  local output = {}
  local echo = function(str) table.insert(output, str) end
  assert(loadstring(str))(echo, unpack(vals))
  return table.concat(map(output, tostring))
end


function lovebird.print(...)
  local str = table.concat(map({...}, tostring), " ") .. "<br>"
  lovebird.buffer = lovebird.buffer .. str
  if #lovebird.buffer > lovebird.maxbuffer then
    lovebird.buffer = lovebird.buffer:sub(-lovebird.maxbuffer)
  end
end


function lovebird.onError(err)
  trace("ERROR:", err)
end


function lovebird.onRequest(req, client)
  -- Handle request for just the buffer
  if req.url:match("buffer") then
    return "HTTP/1.1 200 OK\r\n\r\n" .. lovebird.buffer
  end
  -- Handle input
  if req.body then
    local str = unescape(req.body:match(".-=(.*)"))
    xpcall(function() loadstring(str)() end, lovebird.onError)
  end
  -- Generate page
  local t = {}
  table.insert(t, "HTTP/1.1 200 OK\r\n\r\n") 
  table.insert(t, lovebird.template(pagetemplate, { lovebird = lovebird }))
  return table.concat(t)
end


function lovebird.onConnect(client)
  -- Create request table
  local requestptn = "(%S*)%s*(%S*)%s*(%S*)"
  local req = {}
  req = {}
  req.socket = client
  req.addr, req.port = client:getsockname()
  req.request = client:receive()
  req.method, req.url, req.proto = req.request:match(requestptn)
  req.header = {}
  while 1 do
    local line = client:receive()
    if not line or #line == 0 then break end
    local k, v = line:match("(.-):%s*(.*)$")
    req.header[k] = v
  end
  if req.header["Content-Length"] then
    req.body = client:receive(req.header["Content-Length"])
  end
  -- Handle request; get data to send
  local data, index = lovebird.onRequest(req), 0
  -- Send data
  while index < #data do
    index = index + client:send(data, index)
  end
  -- Clear up
  client:close()
end


function lovebird.update(dt)
  if not lovebird.inited then lovebird.init() end 
  local client = lovebird.server:accept()
  if client then
    client:settimeout(2)
    local addr = client:getsockname()
    if find(lovebird.whitelist, addr) then 
      xpcall(function() lovebird.onConnect(client) end, lovebird.onError)
    else
      trace("got non-whitelisted connection attempt: ", addr)
      client:close()
    end
  end
end


return lovebird
