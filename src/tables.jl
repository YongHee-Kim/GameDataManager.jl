abstract type Table <: AbstractMetaData end

""" 
    Table()

general interface to accessing the gamedata.  
"""
function Table()
    tablelist = string.(xlsxfilenames(CACHE["config"]))

    menu = RadioMenu(tablelist, pagesize=8)
    choice = request("Choose a Table to load (press 'q' to cancel) ", menu)
  
    if choice == -1 || choice > length(tablelist)
        println("Menu canceled.")
        return 
    end 
    fname = tablelist[choice]
    return Table(fname)
end
function Table(fname)
    loadtable(fname)
end

"""
    XLSXTable

wrapper around JSONWorkbook 

# Note
consider providing option to convert `JSONWorksheet` to `IndexedTables.jl` because the Unreal Engine **DataTable** requires `key` column   
"""
mutable struct XLSXTable{FileName} <: Table
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


isloaded(x::XLSXTable) = isa(x.data, JSONWorkbook)

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

"""
    parsefile_outjson(tb::XLSXTable, sheetname)

parse output json file. if the file does not exist, save it.
"""
function parsefile_outjson(tb::XLSXTable, sheetname)
    dir = GAMEENV["OUT"]
    out = tb.out[sheetname]
    if !isfile(out)
        export_worksheet(tb, sheetname)
    end
    return JSON.parsefile(joinpath(dir, out); dicttype=OrderedDict{String,Any})
end

# fallback function
Base.basename(xgd::XLSXTable) = basename(xlsxpath(xgd))
Base.dirname(xgd::XLSXTable) = dirname(xlsxpath(xgd))

_filename(xgd::XLSXTable{NAME}) where {NAME} = NAME

function index(x::XLSXTable) 
    if isloaded(tb) 
        x.data.sheetindex
    else 
        throw(AssertionError("xlsx data is not loaded"))
    end
end
function XLSXasJSON.sheetnames(xgd::XLSXTable)
    collect(keys(xgd.out))
end
filepath(tb::XLSXTable) = xlsxpath(tb)
function XLSXasJSON.xlsxpath(tb::XLSXTable)::String
    if isloaded(tb)
        xlsxpath(tb.data)
    else 
        tb.data 
    end 
end


"""
    xlookup(value, jws::JSONWorksheet, lookup_col::JSONPointer, return_col::JSONPointer; 
                find_mode = findfirst, lt=<comparison>)

## Arguements
- lt: equality operator. you can use `==`, `<=`, `>=`
- find_mode: `findfirst`, `findlast`, `findall`

## Examples
- xlookup(5, Table("Items")["Equipment"], j"/Key", j"/Text/\$Name")
- xlookup("HP", Table("Items")["Consumable"], j"/Type", :; find_mode = findlast)
- xlookup(10, Table("Ability")["Data"], j"/Value", j"/\$Name"; lt = >=, find_mode = findall)
"""
function xlookup(value, jws::JSONWorksheet, lookup_col, return_col; kwargs...)
    xlookup(
        value,
        jws,
        JSONPointer.Pointer(lookup_col),
        JSONPointer.Pointer(return_col);
        kwargs...,
    )
end
function xlookup(
    value,
    jws::JSONWorksheet,
    lookup_col::JSONPointer.Pointer,
    return_col;
    find_mode::Function=findfirst,
    lt::Function=isequal,
)

    if !haskey(jws, lookup_col) 
        throw(ArgumentError("$(lookup_col) does not exist"))
    end
    if isa(return_col, JSONPointer.Pointer)
        if !haskey(jws, return_col) 
            throw(ArgumentError("$(return_col) does not exist"))
        end
    end

    idx = _xlookup_findindex(value, jws, lookup_col, find_mode, lt)

    if isnothing(idx)
        r = nothing
    elseif isempty(idx)
        r = Any[]
    else
        if isa(return_col, Array)
            col_indicies = map(return_col) do this
                i = findfirst(el -> el.tokens == this.tokens, keys(jws))
                if isa(i, Nothing)
                    throw(KeyError(this))
                end
                i
            end
            r = jws[idx, col_indicies]
        else 
            r = jws[idx, return_col]
        end
    end
    return r
end

function _xlookup_findindex(value, jws, lookup_col, find_mode, lt)
    find_mode(el -> lt(el[lookup_col], value), jws.data)
end

