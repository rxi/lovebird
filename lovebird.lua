--
-- lovebird
--
-- Copyright (c) 2014, rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local socket = require "socket"

local lovebird = { _version = "0.0.1" }

lovebird.inited = false
lovebird.host = "*"
lovebird.buffer = ""
lovebird.lines = {}
lovebird.pages = {}

lovebird.wrapprint = true
lovebird.timestamp = true
lovebird.allowhtml = true
lovebird.port = 8000
lovebird.whitelist = { "127.0.0.1", "localhost" }
lovebird.maxlines = 200
lovebird.refreshrate = .5

lovebird.pages["index"] = [[
<?lua
-- Handle console input
if req.parsedbody.input then
  local str = req.parsedbody.input
  xpcall(function() assert(loadstring(str))() end, lovebird.onError)
end
?>

<!doctype html>
<html>
  <head>
  <meta http-equiv="x-ua-compatible" content="IE=Edge"/>
  <title>lovebird</title>
  <style>
    body { 
      margin: 0px;
      font-size: 14px;
      font-family: helvetica, verdana, sans;
      background: #FFFFFF;
    }
    form {
      margin-bottom: 0px;
    }
    a {
      color: #000000;
    }
    a:hover {
      text-decoration: none;
    }
    .timestamp {
      color: #909090;
    }
    .greybordered {
      margin: 12px;
      background: #F0F0F0;
      border: 1px solid #E0E0E0;
    }
    #header {
      background: #101010;
      height: 25px;
      color: #F0F0F0;
      padding: 9px
    }
    #title {
      float: left;
      font-size: 20px;
    }
    #title a {
      color: #F0F0F0;
      text-decoration: none;
    }
    #title a:hover {
      color: #FFFFFF;
    }
    #version {
      font-size: 10px;
    }
    #status {
      float: right;
      font-size: 14px;
      padding-top: 4px;
    }
    #console {
      position: absolute;
      top: 40px; bottom: 0px; left: 0px; right: 312px;
    }
    #input {
      position: absolute;
      margin: 10px;
      bottom: 0px; left: 0px; right: 0px;
    }
    #inputbox {
      width: 100%;
    }
    #output {
      overflow-y: scroll;
      position: absolute;
      margin: 10px;
      top: 0px; bottom: 36px; left: 0px; right: 0px;
    }
    #env {
      position: absolute;
      top: 40px; bottom: 0px; right: 0px;
      width: 300px;
      overflow-y: scroll;
    }
    #envheader {
      padding: 5px;
      background: #E0E0E0;
    }
  </style>
  </head>
  <body>
    <div id="header">
      <div id="title">
        <a href="https://github.com/rxi/lovebird">lovebird</a>
        <span id="version"><?lua echo(lovebird._version) ?></span>
      </div>
      <div id="status">connected &#9679;</div>
    </div>
    <div id="console" class="greybordered">
      <div id="output"> <?lua echo(lovebird.buffer) ?> </div>
      <div id="input">
        <form method="post">
          <input id="inputbox" name="input" type="text"></input>
        </form>
      </div>
    </div>
    <div id="env" class="greybordered">
      
    </div>
    <script>
      document.getElementById("inputbox").focus();

      var updateDivContent = function(id, content) {
        var div = document.getElementById(id); 
        if (div.innerHTML != content) {
          div.innerHTML = content;
          return true;
        }
        return false;
      }

      var getPage = function(url, onComplete, onFail) {
        var req = new XMLHttpRequest();
        req.onreadystatechange = function() {
          if (req.readyState != 4) return;
          if (req.status == 200) {
            if (onComplete) onComplete(req.responseText);
          } else {
            if (onFail) onFail(req.responseText);
          }
        }
        url += (url.indexOf("?") > -1 ? "&_=" : "?_=") + Math.random();
        req.open("GET", url, true);
        req.send();
      }

      /* Scroll output to bottom */
      var scrolloutput = function() {
        var div = document.getElementById("output"); 
        div.scrollTop = div.scrollHeight;
      }
      scrolloutput()

      /* Refresh output buffer and status */
      var refreshOutput = function() {
        getPage("/buffer", function(text) {
          updateDivContent("status", "connected &#9679;");
          if (updateDivContent("output", text)) {
            scrolloutput();
          }
        },
        function(text) {
          updateDivContent("status", "disconnected &#9675;");
        });
      }
      setInterval(refreshOutput, <?lua echo(lovebird.refreshrate) ?> * 1000);

      /* Refresh env view */
      var envPath = "";
      var refreshEnv = function() {
        getPage("/tree?p=" + envPath, function(text) { 
          updateDivContent("env", text);
        });
      }
      var onTreeLink = function(p) { envPath = p; refreshEnv(); }
      setInterval(refreshEnv, <?lua echo(lovebird.refreshrate) ?> * 1000);
    </script>
  </body>
</html>
]]


lovebird.pages["buffer"] = [[ <?lua echo(lovebird.buffer) ?> ]]


lovebird.pages["tree"] = [[
  <?lua 
    local t = _G
    local p = req.parsedurl.query.p or ""
    if p ~= "" then
      for x in p:gmatch("[^%.]+") do
        t = t[x]
      end
    end
  ?>

  <div id="envheader">
    <a href="#" onclick="onTreeLink('')">root</a>
    <?lua local acc = "" ?>
    <?lua for x in p:gmatch("[^%.]+") do ?>
    <?lua acc = acc .. "." .. x ?>
      .
      <a href="#" onclick="onTreeLink('<?lua echo(acc)?>')">
        <?lua echo(x) ?>
      </a>
    <?lua end ?>
  </div>

  <table>
    <?lua 
      local keys = {}
      for k in pairs(t) do table.insert(keys, k) end
      table.sort(keys)
      for _, k in pairs(keys) do 
        local v = t[k]
    ?>
    <tr>
      <td> 
        <?lua if type(v) == "table" then ?>
          <a href="#" onclick="onTreeLink('<?lua echo(p.."."..k)?>')">
            <?lua echo(k) ?>
          </a>
        <?lua else ?>
          <?lua echo(k) ?>
        <?lua end ?>
      </td>
      <td>
        <?lua echo(lovebird.htmlescape(lovebird.truncate(tostring(v), 30))) ?>
      </td>
    </tr>
    <?lua end ?>
  </table>
]]



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



function lovebird.init()
  lovebird.server = assert(socket.bind(lovebird.host, lovebird.port))
  lovebird.addr, lovebird.port = lovebird.server:getsockname()
  lovebird.server:settimeout(0)
  if lovebird.wrapprint then
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


function lovebird.parseurl(url)
  local res = {}
  res.path, res.search = url:match("/([^%?]*)%??(.*)")
  res.query = {}
  for k, v in res.search:gmatch("([^&^?]-)=([^&^#]*)") do
    res.query[k] = unescape(v)
  end
  return res
end


function lovebird.htmlescape(str)
  return str:gsub("<", "&lt;")
end


function lovebird.truncate(str, len)
  if #str < len then
    return str
  end
  return str:sub(1, len - 3) .. "..."
end


function lovebird.print(...)
  local str = table.concat(map({...}, tostring), " ")
  if not lovebird.allowhtml then
    str = lovebird.htmlescape(str)
  end
  if lovebird.timestamp then
    str = os.date('<span class="timestamp">[%H:%M:%S]</span> ') .. str
  end
  table.insert(lovebird.lines, str)
  if #lovebird.lines > lovebird.maxlines then
    table.remove(lovebird.lines, 1)
  end
  lovebird.buffer = table.concat(lovebird.lines, "<br>")
end


function lovebird.onError(err)
  trace("ERROR:", err)
end


function lovebird.onRequest(req, client)
  local page = req.parsedurl.path
  page = page ~= "" and page or "index"
  -- Handle "page not found"
  if not lovebird.pages[page] then 
    return "HTTP/1.1 404\r\nContent-Type: text/html\r\n\r\nBad page"
  end
  -- Handle existent page
  return "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n" ..
         lovebird.template(lovebird.pages[page],
                           { lovebird = lovebird, req = req })
end


function lovebird.onConnect(client)
  -- Create request table
  local requestptn = "(%S*)%s*(%S*)%s*(%S*)"
  local req = {}
  req.socket = client
  req.addr, req.port = client:getsockname()
  req.request = client:receive()
  req.method, req.url, req.proto = req.request:match(requestptn)
  req.headers = {}
  while 1 do
    local line = client:receive()
    if not line or #line == 0 then break end
    local k, v = line:match("(.-):%s*(.*)$")
    req.headers[k] = v
  end
  if req.headers["Content-Length"] then
    req.body = client:receive(req.headers["Content-Length"])
  end
  -- Parse body
  req.parsedbody = {}
  if req.body then
    for k, v in req.body:gmatch("([^&]-)=([^&^#]*)") do
      req.parsedbody[k] = unescape(v)
    end
  end
  -- Parse request line's url
  req.parsedurl = lovebird.parseurl(req.url)
  -- Handle request; get data to send
  local data, index = lovebird.onRequest(req), 0
  -- Send data
  while index < #data do
    index = index + client:send(data, index)
  end
  -- Clear up
  client:close()
end


function lovebird.update()
  if not lovebird.inited then lovebird.init() end 
  local client = lovebird.server:accept()
  if client then
    client:settimeout(2)
    local addr = client:getsockname()
    if not lovebird.whitelist or find(lovebird.whitelist, addr) then 
      xpcall(function() lovebird.onConnect(client) end, lovebird.onError)
    else
      trace("got non-whitelisted connection attempt: ", addr)
      client:close()
    end
  end
end


return lovebird
