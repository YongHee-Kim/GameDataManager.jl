function init_project(path)
    config = joinpath(path, "config.json")
    if !isfile(config)
        throw(ArgumentError("cannot find $(normpath(config))"))
    end 

    GAMEENV["PROJECT"] = path
    GAMEENV["CONFIG"] = config 
    
    CACHE["config"] = loadconfig()
end

function loadconfig(file = joinpath(GAMEENV["PROJECT"], "config.json"))
    println(file)

    JSON.parsefile(file; dicttype = OrderedDict)
end