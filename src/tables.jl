"""
    XLSXTable

Read xlsx data when being called
"""
mutable struct XLSXTable{FileName}
    data::Union{JSONWorkbook, Missing}
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
        kwargs[name] = get(row, "kwargs", missing) 
    end

    XLSXTable{FileName}(missing, missing, out, localize_key, kwargs)
end