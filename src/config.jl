

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