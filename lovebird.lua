--
-- lovebird
--
-- Copyright (c) 2014, rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local socket = require "socket"

local lovebird = { _version = "0.1.0" }

lovebird.inited = false
lovebird.host = "*"
lovebird.buffer = ""
lovebird.lines = {}
lovebird.pages = {}

lovebird.wrapprint = true
lovebird.timestamp = true
lovebird.allowhtml = true
lovebird.port = 8000
lovebird.whitelist = { "127.0.0.1", "192.168.*.*" }
lovebird.maxlines = 200
lovebird.updateinterval = .5

lovebird.pages["index"] = [[
<?lua
-- Handle console input
if req.parsedbody.input then
  local str = req.parsedbody.input
  xpcall(function() assert(loadstring(str))() end, lovebird.onerror)
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
    .timestamp {
      color: #909090;
      padding-right: 4px;
    }
    .repeatcount {
      color: #F0F0F0;
      background: #505050;
      font-size: 11px;
      font-weight: bold;
      text-align: center;
      padding-left: 4px;
      padding-right: 4px;
      padding-top: 1px;
      padding-bottom: 1px;
      border-radius: 6px;
      display: inline-block;
    }
    .greybordered {
      margin: 12px;
      background: #F0F0F0;
      border: 1px solid #E0E0E0;
      border-radius: 3px;
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
    #main a {
      color: #000000;
      text-decoration: none;
      background: #E0E0E0;
      border: 1px solid #D0D0D0;
      border-radius: 3px;
      padding-left: 2px;
      padding-right: 2px;
      display: inline-block;
    }
    #main a:hover {
      background: #D0D0D0;
      border: 1px solid #C0C0C0;
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
    }
    #envheader {
      padding: 5px;
      background: #E0E0E0;
    }
    #envvars {
      position: absolute;
      left: 0px; right: 0px; top: 25px; bottom: 0px;
      margin: 10px;
      overflow-y: scroll;
      font-size: 12px;
    }
  </style>
  </head>
  <body>
    <div id="header">
      <div id="title">
        <a href="https://github.com/rxi/lovebird">lovebird</a>
        <span id="version"><?lua echo(lovebird._version) ?></span>
      </div>
      <div id="status"></div>
    </div>
    <div id="main">
      <div id="console" class="greybordered">
        <div id="output"> <?lua echo(lovebird.buffer) ?> </div>
        <div id="input">
          <form method="post" onsubmit="onInputSubmit(); return false">
            <input id="inputbox" name="input" type="text"></input>
          </form>
        </div>
      </div>
      <div id="env" class="greybordered">
        <div id="envheader"></div>
        <div id="envvars"></div>
      </div>
    </div>
    <script>
      document.getElementById("inputbox").focus();

      var truncate = function(str, len) {
        if (str.length <= len) return str;
        return str.substring(0, len - 3) + "...";
      }

      var geturl = function(url, onComplete, onFail) {
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

      var updateDivContent = function(id, content) {
        var div = document.getElementById(id); 
        if (div.innerHTML != content) {
          div.innerHTML = content;
          return true;
        }
        return false;
      }

      var onInputSubmit = function() {
        var b = document.getElementById("inputbox");
        var req = new XMLHttpRequest();
        req.open("POST", "/", true);
        req.send("input=" + encodeURIComponent(b.value));
        b.value = "";
        refreshOutput();
      }

      /* Output buffer and status */
      var refreshOutput = function() {
        geturl("/buffer", function(text) {
          updateDivContent("status", "connected &#9679;");
          if (updateDivContent("output", text)) {
            var div = document.getElementById("output"); 
            div.scrollTop = div.scrollHeight;
          }
        },
        function(text) {
          updateDivContent("status", "disconnected &#9675;");
        });
      }
      setInterval(refreshOutput, <?lua echo(lovebird.updateinterval) ?> * 1000);

      /* Environment variable view */
      var envPath = "";
      var refreshEnv = function() {
        geturl("/env.json?p=" + envPath, function(text) { 
          var json = eval("(" + text + ")");

          /* Header */
          var html = "<a href='#' onclick=\"setEnvPath('')\">env</a>";
          var acc = "";
          var p = json.path != "" ? json.path.split(".") : [];
          for (var i = 0; i < p.length; i++) {
            acc += "." + p[i];
            html += " <a href='#' onclick=\"setEnvPath('" + acc + "')\">" +
                    truncate(p[i], 10) + "</a>";
          }
          updateDivContent("envheader", html);

          /* Handle invalid table path */
          if (!json.valid) {
            updateDivContent("envvars", "Bad path");
            return;
          }

          /* Variables */
          var html = "<table>";
          for (var i = 0; json.vars[i]; i++) {
            var x = json.vars[i];
            var fullpath = (json.path + "." + x.key).replace(/^\./, "");
            var k = truncate(x.key, 15);
            if (x.type == "table") {
              k = "<a href='#' onclick=\"setEnvPath('" + fullpath + "')\">" +
                  k + "</a>";
            }
            var v = "<a href='#' onclick=\"insertVar('" +
                    fullpath.replace(/\.(-?[0-9])+/g, "[$1]") +
                    "');\">" + x.value + "</a>"
            html += "<tr><td>" + k + "</td><td>" + v + "</td></tr>";
          }
          html += "</table>";
          updateDivContent("envvars", html);
        });
      }
      var setEnvPath = function(p) { 
        envPath = p;
        refreshEnv();
      }
      var insertVar = function(p) {
        var b = document.getElementById("inputbox");
        b.value += p;
        b.focus();
      }
      setInterval(refreshEnv, <?lua echo(lovebird.updateinterval) ?> * 1000);
    </script>
  </body>
</html>
]]


lovebird.pages["buffer"] = [[ <?lua echo(lovebird.buffer) ?> ]]


lovebird.pages["env.json"] = [[
<?lua 
  local t = _G
  local p = req.parsedurl.query.p or ""
  p = p:gsub("%.+", "%."):match("^[%.]*(.*)[%.]*$")
  if p ~= "" then
    for x in p:gmatch("[^%.]+") do
      t = t[x] or t[tonumber(x)]
      -- Return early if path does not exist
      if type(t) ~= "table" then
        echo('{ "valid": false, "path": ' .. string.format("%q", p) .. ' }')
        return
      end
    end
  end
?>
{
  "valid": true,
  "path": "<?lua echo(p) ?>",
  "vars": [
    <?lua 
      local keys = {}
      for k in pairs(t) do table.insert(keys, k) end
      table.sort(keys)
      for _, k in pairs(keys) do 
        local v = t[k]
    ?>
      { 
        "key": "<?lua echo(k) ?>",
        "value": <?lua echo( 
                          string.format("%q",
                            lovebird.truncate(
                              lovebird.htmlescape(
                                tostring(v)), 26))) ?>,
        "type": "<?lua echo(type(v)) ?>",
      },
    <?lua end ?>
  ]
}
]]



local loadstring = loadstring or load

local map = function(t, fn)
  local res = {}
  for k, v in pairs(t) do res[k] = fn(v) end
  return res
end

local trace = function(...)
  local str = "[lovebird] " .. table.concat(map({...}, tostring), " ")
  print(str)
  if not lovebird.wrapprint then lovebird.print(str) end
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
  if #str <= len then
    return str
  end
  return str:sub(1, len - 3) .. "..."
end


function lovebird.checkwhitelist(addr)
  if lovebird.whitelist == nil then return true end
  for _, a in pairs(lovebird.whitelist) do
    local ptn = "^" .. a:gsub("%.", "%%."):gsub("%*", "%%d*") .. "$"
    if addr:match(ptn) then return true end
  end
  return false
end


function lovebird.clear()
  lovebird.lines = {}
  lovebird.buffer = ""
end


function lovebird.print(...)
  local str = table.concat(map({...}, tostring), " ")
  local last = lovebird.lines[#lovebird.lines]
  if last and str == last.str then
    -- Update last line if this line is a duplicate of it
    last.time = os.time()
    last.count = last.count + 1
  else
    -- Create new line
    local line = { str = str, time = os.time(), count = 1 }
    table.insert(lovebird.lines, line)
    if #lovebird.lines > lovebird.maxlines then
      table.remove(lovebird.lines, 1)
    end
  end
  -- Build string buffer from lines
  local function doline(line)
    local str = line.str
    if not lovebird.allowhtml then
      str = lovebird.htmlescape(line.str)
    end
    if line.count > 1 then
      str = '<span class="repeatcount">' .. line.count .. '</span> ' .. str
    end
    if lovebird.timestamp then
      str = os.date('<span class="timestamp">%H:%M:%S</span> ', line.time) .. 
            str
    end
    return str
  end
  lovebird.buffer = table.concat(map(lovebird.lines, doline), "<br>")
end


function lovebird.onerror(err)
  trace("ERROR:", err)
end


function lovebird.onrequest(req, client)
  local page = req.parsedurl.path
  page = page ~= "" and page or "index"
  -- Handle "page not found"
  if not lovebird.pages[page] then 
    return "HTTP/1.1 404\r\nContent-Type: text/html\r\n\r\nBad page"
  end
  -- Handle page
  local str
  xpcall(function()
    str = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n" ..
          lovebird.template(lovebird.pages[page],
                            { lovebird = lovebird, req = req })
  end, lovebird.onerror)
  return str
end


function lovebird.onconnect(client)
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
  local data, index = lovebird.onrequest(req), 0
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
    if lovebird.checkwhitelist(addr) then 
      xpcall(function() lovebird.onconnect(client) end, function() end)
    else
      trace("got non-whitelisted connection attempt: ", addr)
      client:close()
    end
  end
end


return lovebird
