init_project() = init_project(pwd())

"""
    init_project(path::String)

Initialize a new project from the root directory. Checkout [`ConfigData`](@ref)

# Arguments
- `path`: The root directory of the project. it must contain a `config.json` file. By default, it is the current working directory.

"""
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

    # log succesful project load with the project name  
    println("Project $(CACHE["config"].data["name"]) loaded successfully")
    return CACHE["config"]
end