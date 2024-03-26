"""
    ConfigData

A mutable struct that holds the configuration data of the project

# Fields
- `filepath`: The path to the `config.json` file
- `data`: The parsed JSON data, refer to the example file in the '/test' folder
- 'data' is a dictionary of the following keys:
    - `environment`: A dictionary of environment paths
    - 'localization': A localization input and output languages
    - `xlsxtables`: A dictionary of XLSXTable objects
- `tables`: A dictionary of XLSXTable objects
- `mtime`: The last modified time of the `config.json` file, for checking if the file is modified

# Examples
"""
mutable struct ConfigData <: AbstractMetaData
    filepath::AbstractString
    data::Union{Missing, AbstractDict}
    tables::AbstractDict
    mtime::Float64 
end
function ConfigData(file)
    x = ConfigData(file, missing, Dict{Symbol, Any}(), 0.)
    if !isfile(file)
        throw(SystemError(file, 2))
    end
    loaddata!(x)
    return x
end
function ismodified(x::ConfigData)
    x.mtime != mtime(filepath(x))
end

"""
    loaddata!(x::ConfigData)

It does the following:
- Read 'environment' and add them to `GAMEENV`
- Load all xlsx tables under 'xlsxtables' and add them to `config.tables`

# TODO: 
- Consider hot loading xlsx tables when the file is requested. At least allow the user to set the hot loading file for maning large files easier.
"""
function loaddata!(x::ConfigData)
    x.data = JSON.parsefile(filepath(x); dicttype=OrderedDict{String,Any}, use_mmap=false)

    # create environment paths
    for (k, path) in x.data["environment"]
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
    for (fname, sheetdata) in x.data["xlsxtables"]
        file = joinpath(GAMEENV["XLSX"], fname)
        if !isfile(file)
            @warn "$file does not exist, please insert a valid path in `config.json`"
        else  
            jwb = XLSXTable(file, sheetdata)
            x.tables[_filename(jwb)] = jwb
        end
    end
    
    return x
end

function xlsxfilenames(x::ConfigData)
    keys(x.tables)
end