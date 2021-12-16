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

function loadconfig(file = joinpath(GAMEENV["PROJECT"], "config.json"))
    configdata = JSON.parsefile(file; dicttype=OrderedDict{String,Any}, use_mmap=false)
    # create paths
    for (k, path) in configdata["environment"]
        if isabspath(path)
            fullpath = normpath(path)
        else 
            fullpath = abspath(joinpath(GAMEENV["PROJECT"], path))
        end
        if !isdir(fullpath)
            @info "$fullpath is created"
            mkpath(fullpath)
        end
        GAMEENV[uppercase(k)] = fullpath 
    end
    # check if xlsx file exists 
    for (fname, sheetdata) in configdata["xlsxtables"]
        file = joinpath(GAMEENV["XLSX"], fname)
        if !isfile(file)
            @warn "$file does not exist, checkout `config.json`"
        else  
            register_table!(XLSXTable(file, sheetdata))
        end
    end

    return configdata 
end

function register_table!(tb::XLSXTable{fname}) where fname
    CACHE["tables"][fname] = tb
end

