init_project() = init_project(pwd())
function init_project(path)
    config = joinpath(path, "config.json")
    if !isfile(config)
        throw(ArgumentError("cannot find $(normpath(config))"))
    end 

    GAMEENV["PROJECT"] = path
    GAMEENV["CONFIG"] = config 
    
    CACHE["config"] = ConfigData(joinpath(GAMEENV["PROJECT"], "config.json"))

    # Game specific JuliaModule implementation 
    if haskey(GAMEENV, "JULIAMODULE")
        if !in(GAMEENV["JULIAMODULE"], LOAD_PATH)
            push!(LOAD_PATH, GAMEENV["JULIAMODULE"])
        end
    end

    # @info "\"$(CACHE["config"]["name"])\" Project has loaded successfully!"
end