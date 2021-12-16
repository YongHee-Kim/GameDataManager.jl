function lookfor_jsonschema(filename)
    schema = missing
    if endswith(filename, ".json")
        schemafile = joinpath(GAMEENV["JSONSCHEMA"], filename)
        if isfile(schemafile)
            schema = SchemaData(schemafile)
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
    loaddata!(CACHE["tables"][fname])
end


# fallback function
Base.basename(xgd::XLSXTable) = basename(xlsxpath(xgd))
Base.dirname(xgd::XLSXTable) = dirname(xlsxpath(xgd))
filepath(tb::XLSXTable) = xlsxpath(tb)

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
    println(io, "XLSXTable")
    sheets = sheetnames(bt)
    outfiles = collect(values(bt.out))
    schemas = .!(ismissing.(values(bt.schemas)))
    if isa(bt.data, JSONWorkbook)
        # print(io, " - ", bt.data)
        pretty_table(io, hcat(1:length(sheets), sheets, outfiles, schemas); header = ["Idx", "Sheet", "Out", "Schema"], alignment=:l, 
        tf = tf_markdown, header_crayon = crayon"bold green")
    else 
        f = replace(bt.data, GAMEENV["XLSX"] => "...") 
        print(io, "(\"", f, "\")")
    end
end


