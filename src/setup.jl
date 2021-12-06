function init_project(path)
    config = joinpath(path, "config.json")
    if !isfile(config)
        throw(ArgumentError("cannot find $(normpath(config))"))
    end 

    GAMEENV["PROJECT"] = path
    GAMEENV["CONFIG"] = config 
    
    CACHE["config"] = loadconfig()

    # load juliaModule
    if haskey(GAMEENV, "JULIAMODULE")
        if !in(GAMEENV["JULIAMODULE"], LOAD_PATH)
            push!(LOAD_PATH, GAMEENV["JULIAMODULE"])

        end
    end

    @info "\"$(CACHE["config"]["name"])\" Project has loaded successfully!"
end

function loadconfig(file = joinpath(GAMEENV["PROJECT"], "config.json"); firstrun = true)
    configdata = open(file, "r") do io 
        JSON.parse(io; dicttype=OrderedDict{String,Any})
    end

    # create paths
    for (k, path) in configdata["environment"]
        fullpath = joinpath(GAMEENV["PROJECT"], path) |> normpath
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
            @warn "$file does not exist"
        else  
            if firstrun 
                register_table(XLSXTable(file, sheetdata))
            end
        end
    end

    return configdata 
end

function register_table(t::XLSXTable{Fname}) where Fname
    CACHE["tables"][Fname] = t
end

