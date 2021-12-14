"""
    AbstractMetaData

Thin wrapper for data to store cache and modified time


"""
abstract type AbstractMetaData end 

filepath(x::AbstractMetaData) = x.filepath

function isloaded(x::AbstractMetaData) 
    !ismissing(x.data)
end
function ismodified(x::AbstractMetaData)
    if isloaded(x)
        return x.mtime != mtime(filepath(x))
    else 
        return true 
    end
end


mutable struct ConfigData <: AbstractMetaData
    filepath::AbstractString
    data::Union{Missing, AbstractDict}
    mtime::Float64 
end

mutable struct SchemaData <: AbstractMetaData
    filepath::AbstractString
    schema::Union{Missing, JSONSchema.Schema}
    mtime::Float64 
end
function SchemaData(file)
    SchemaData(file, missing, 0.)
end
function loaddata!(x::SchemaData)
    x.schema = JSONSchema.Schema(JSON.parsefile(x.filepath; use_mmap=false))
    x.mtime = mtime(x.filepath)
    return x
end


"""
    XLSXTable

wrapper around JSONWorkbook 
"""
mutable struct XLSXTable{FileName} <: AbstractMetaData
    data::Union{JSONWorkbook, String}
    localizedata::Dict{String, Any}
    out::Dict{String, String} # output filename
    schema::Dict{String, Any} # JSONSchema per sheet
    localize_key::Dict{String, Any}
    kwargs::Dict{String, Any}
    mtime::Float64
end
function XLSXTable(file, config)
    FileName = splitext(basename(file))[1] |> Symbol

    out = Dict{String, String}()
    schema = Dict{String, Any}()
    localize_key = Dict{String, Any}()
    localizedata = Dict{String, Any}()
    kwargs = Dict{String, Any}()

    for row in config["workSheets"]
        sheetname = row["name"]
        out[sheetname] = row["out"]
        kwargs[sheetname] = begin 
            haskey(row, "kwargs") ? namedtuple(row["kwargs"]) : namedtuple(Dict{String,Any}())
        end

        # localizer 
        localize_key[sheetname] = begin 
            loc = get(row, "localize", missing) 
            # default: uses row number for localize key 
            if !ismissing(loc)
                loc = get(loc, "keycolumn", "")
            end
            loc 
        end
        localizedata[sheetname] = missing
        # JSONSchema 
        schema[sheetname] = lookfor_jsonschema(row["out"])
    end
    XLSXTable{FileName}(file, localizedata, out, schema, localize_key, kwargs, 0.)
end

function loaddata!(tb::XLSXTable)
    if ismodified(tb)
        kwarg_per_sheet = tb.kwargs
        tb.data = JSONWorkbook(xlsxpath(tb), keys(kwarg_per_sheet), kwarg_per_sheet)
        tb.mtime = mtime(xlsxpath(tb))
        localize!(tb)
    end
    return tb
end