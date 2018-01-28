package = "lovebird"
version = "0.4-4"
source = {
    url = "git://github.com/rxi/lovebird",
    tag = "0.4.4"
}
description = {
    summary = "A browser-based debug console for LÖVE",
    detailed = [[
        A browser-based debug console for LÖVE
    ]],
    homepage = "https://github.com/rxi/lovebird"
}
dependencies = {
    "lua >= 5.0"
}
build = {
    type = "builtin",
    modules = {
        lovebird = "lovebird.lua"
    }
}
