"""
    XLSXTable

wrapper around JSONWorkbook
"""
mutable struct XLSXTable{FileName}
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

function lookfor_jsonschema(filename)
    schema = missing
    if endswith(filename, ".json")
        schemafile = joinpath(GAMEENV["JSONSCHEMA"], filename)
        if isfile(schemafile)
            schema = Schema(schemafile)
        end
    end
    return schema
end


loadtable(fname::AbstractString) = loadtable(Symbol(fname))
function loadtable(fname::Symbol)
    if !haskey(CACHE["tables"], fname)
        hay = string.(keys(CACHE["tables"]))
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
    tb = CACHE["tables"][fname]
    if ismodified(tb)
        loaddata!(tb)
    end
    return tb
end

function loaddata!(tb::XLSXTable)
    kwarg_per_sheet = tb.kwargs
    tb.data = JSONWorkbook(xlsxpath(tb), keys(kwarg_per_sheet), kwarg_per_sheet)
    tb.mtime = mtime(xlsxpath(tb))
    localize!(tb)
    return tb
end

isloaded(tb::XLSXTable) = isa(tb.data, JSONWorkbook)
function ismodified(tb::XLSXTable)
    if isloaded(tb)
        return tb.mtime != mtime(xlsxpath(tb))
    else 
        return true 
    end
end
# fallback function
function Base.getindex(tb::XLSXTable, i) 
    if !isloaded(tb)
        loaddata!(tb)
    end
    getindex(tb.data, i)
end

Base.basename(xgd::XLSXTable) = basename(xlsxpath(xgd))
Base.dirname(xgd::XLSXTable) = dirname(xlsxpath(xgd))
_filename(xgd::XLSXTable{NAME}) where {NAME} = NAME

index(x::XLSXTable) = x.data.sheetindex
XLSXasJSON.sheetnames(xgd::XLSXTable) = sheetnames(xgd.data)
function XLSXasJSON.xlsxpath(tb::XLSXTable)::String
    if isa(tb.data, JSONWorkbook)
        p = xlsxpath(tb.data)
    else 
        p = tb.data 
    end 
    return p
end

JSON.json(jws::JSONWorksheet, indent) = JSON.json(jws.data, indent)
JSON.json(jws::JSONWorksheet) = JSON.json(jws.data)


function Base.show(io::IO, bt::XLSXTable)
    print(io, "XLSXTable")
    if isa(bt.data, JSONWorkbook)
        print(io, " - ", bt.data)
    else 
        f = replace(bt.data, GAMEENV["XLSX"] => "...") 
        print(io, "(\"", f, "\")")
    end
end


