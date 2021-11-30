function init_project(path)
    config = joinpath(path, "config.json")
    if !isfile(config)
        throw(ArgumentError("cannot find $(normpath(config))"))
    end 

    GAMEENV["PROJECT"] = path
    GAMEENV["CONFIG"] = config 
    
    CACHE["config"] = loadconfig()

    @info "\"$(CACHE["config"]["name"])\" Project has loaded successfully!"
end

function loadconfig(file = joinpath(GAMEENV["PROJECT"], "config.json"); firstrun = true)
    configdata = JSON.parsefile(file; dicttype = OrderedDict)

    # create paths
    for (k, path) in configdata["environment"]
        dir = joinpath(GAMEENV["PROJECT"], path) |> normpath
        if !isdir(dir)
            @info "$dir is created"
            mkpath(dir)
        end
        GAMEENV[uppercase(k)] = dir 
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
