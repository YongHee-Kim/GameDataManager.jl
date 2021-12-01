"""
    XLSXTable

wrapper around JSONWorkbook
"""
mutable struct XLSXTable{FileName}
    data::Union{JSONWorkbook, String}
    localizedata::Dict{String, Any}
    mtime
    out::Dict{String, String} # output filename
    localize_key::Dict{String, Any}
    kwargs::Dict{String, Any}
end
function XLSXTable(file, config)
    FileName = splitext(basename(file))[1] |> Symbol

    out = Dict{String, String}()
    localize_key = Dict{String, Any}()
    localizedata = Dict{String, Any}()
    kwargs = Dict{String, Any}()

    for row in config["workSheets"]
        name = row["name"]
        out[name] = row["out"]
        localize_key[name] = begin 
            loc = get(row, "localize", missing) 
            # default: uses row number for localize key 
            if !ismissing(loc)
                loc = get(loc, "keycolumn", "")
            end
            loc 
        end
        kwargs[name] = if haskey(row, "kwargs")
                namedtuple(row["kwargs"])
            else 
                namedtuple(Dict{String,Any}())
            end
        localizedata[name] = missing
    end
    XLSXTable{FileName}(file, localizedata, missing, out, localize_key, kwargs)
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
    if !isa(tb.data, JSONWorkbook)
        kwarg_per_sheet = tb.kwargs
        jwb = JSONWorkbook(tb.data, keys(kwarg_per_sheet), kwarg_per_sheet)
        tb.data = jwb
        localize!(tb)
    end
    return tb
end


# fallback function
Base.getindex(bt::XLSXTable, i) = getindex(bt.data, i)

Base.basename(xgd::XLSXTable) = basename(xlsxpath(xgd))
Base.dirname(xgd::XLSXTable) = dirname(xlsxpath(xgd))
_filename(xgd::XLSXTable{NAME}) where {NAME} = NAME

index(x::XLSXTable) = x.data.sheetindex
XLSXasJSON.sheetnames(xgd::XLSXTable) = sheetnames(xgd.data)
XLSXasJSON.xlsxpath(xgd::XLSXTable) = xlsxpath(xgd.data)

function Base.show(io::IO, bt::XLSXTable)
    print(io, "XLSXTable")
    if isa(bt.data, JSONWorkbook)
        print(io, " - ", bt.data)
    else 
        f = replace(bt.data, GAMEENV["XLSX"] => "...") 
        print(io, "(\"", f, "\")")
    end
end


