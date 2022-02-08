

"""
    XLSXTable

wrapper around JSONWorkbook 
"""
mutable struct XLSXTable{FileName} <: AbstractMetaData
    data::Union{JSONWorkbook, String}
    localizedata::Dict{String, Any}
    out::Dict{String, String} # output filename
    schemas::Dict{String, Any} # JSONSchema per sheet
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


# function XLSXTable(fname, config::ConfigData = CACHE["config"])

# end


function isloaded(x::XLSXTable) 
    isa(x.data, JSONWorkbook)
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

function Base.getindex(tb::XLSXTable, i) 
    if !isloaded(tb)
        loaddata!(tb)
    end
    getindex(tb.data, i)
end


function lookfor_jsonschema(filename)
    schema = missing
    if endswith(filename, ".json")
        if haskey(GAMEENV, "JSONSCHEMA")
            schemafile = joinpath(GAMEENV["JSONSCHEMA"], filename)
            if isfile(schemafile)
                schema = SchemaData(schemafile)
            end
        end
    end
    return schema
end


loadtable(fname::AbstractString) = loadtable(Symbol(fname))
function loadtable(fname::Symbol)
    config = CACHE["config"]
    if !in(fname, xlsxfilenames(config))
        hay = string.(xlsxfilenames(config))
        needle = string(fname)
        for (i, h) in enumerate(hay)
            if lowercase(h) == lowercase(needle)
                fname = Symbol(h)
                break
            end
            if i == length(hay)
                throw_fuzzylookupname(hay, needle)
            end
        end
    end
    loaddata!(config.tables[fname])
end


# fallback function
Base.basename(xgd::XLSXTable) = basename(xlsxpath(xgd))
Base.dirname(xgd::XLSXTable) = dirname(xlsxpath(xgd))
filepath(tb::XLSXTable) = xlsxpath(tb)

_filename(xgd::XLSXTable{NAME}) where {NAME} = NAME

index(x::XLSXTable) = x.data.sheetindex
function XLSXasJSON.sheetnames(xgd::XLSXTable)
    collect(keys(xgd.out))
end
function XLSXasJSON.xlsxpath(tb::XLSXTable)::String
    if isa(tb.data, JSONWorkbook)
        p = xlsxpath(tb.data)
    else 
        p = tb.data 
    end 
    return p
end



