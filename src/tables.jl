"""
    XLSXTable

wrapper around JSONWorkbook
"""
mutable struct XLSXTable{FileName}
    data::Union{JSONWorkbook, String}
    mtime
    out::Dict{String, String}
    localize_key::Dict{String, Any}
    kwargs::Dict{String, Any}
end
function XLSXTable(file, config)
    FileName = splitext(basename(file))[1] |> Symbol

    out = Dict{String, String}()
    localize_key = Dict{String, Any}()
    kwargs = Dict{String, Any}()

    for row in config["workSheets"]
        name = row["name"]
        out[name] = row["out"]
        # default: uses row number for localize key 
        localize_key[name] = begin 
            loc = get(row, "localize", true) 
            if isa(loc, Bool) 
                loc ? "" : missing 
            else 
                loc["keycolumn"]
            end
        end
        kwargs[name] = if haskey(row, "kwargs")
                namedtuple(row["kwargs"])
            else 
                missing 
            end
    end
    XLSXTable{FileName}(file, missing, out, localize_key, kwargs)
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
    table = CACHE["tables"][fname]
    if !isa(table.data, JSONWorkbook)
        kwarg_per_sheet = table.kwargs
        jwb = JSONWorkbook(table.data, keys(kwarg_per_sheet), kwarg_per_sheet)
        table.data = jwb
    end
    return table
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


