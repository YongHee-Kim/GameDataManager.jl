"""
    xl(; strict=false)
    xl(fname; strict=false)

Export xlsx files configured in `config.json` to JSON/CSV/TSV.

With no argument, exports every file in the config. With `fname`, exports only that file.

# Keyword Arguments
- `strict`: when `true`, the first failure is rethrown. When `false` (default), failures
  are collected and a summary is printed at the end so a single broken sheet does not
  abort the batch.
"""
function xl(; strict::Bool = false)
    update!(CACHE["config"])

    files = xlsxfilenames(CACHE["config"])
    if isempty(files)
        print_section("nothing to export."; color=:yellow)
        return nothing
    end
    print_section(
        "exporting xlsx files... ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color = :cyan,
    )
    failures = Pair{String,Exception}[]
    for f in files
        try
            export_xlsxtable(f)
        catch e
            strict && rethrow()
            bt = catch_backtrace()
            push!(failures, string(f) => e)
            printstyled("$f export failed:\n"; color = :red)
            showerror(stdout, e, bt)
            println()
        end
    end
    n_ok = length(files) - length(failures)
    if isempty(failures)
        print_section("$(length(files)) xlsx files are exported ☺", "DONE"; color = :cyan)
    else
        print_section(
            "$n_ok ok, $(length(failures)) failed:\n" *
            join(("  - $f" for (f, _) in failures), '\n'),
            "DONE WITH ERRORS"; color = :yellow,
        )
    end
    return nothing
end
function xl(fname; strict::Bool = false)
    update!(CACHE["config"])

    print_section(
        "exporting xlsx file... ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color = :cyan,
    )
    try
        export_xlsxtable(fname)
    catch e
        strict && rethrow()
        bt = catch_backtrace()
        printstyled("$fname export failed:\n"; color = :red)
        showerror(stdout, e, bt)
        println()
        return nothing
    end
    print_section("export complete ☺", "DONE"; color = :cyan)

    return nothing
end


"""
    export_xlsxtable(file::AbstractString)

export a given excel worsheets to a output file specified in 'config.json'
"""
function export_xlsxtable(fname)
    println("『", fname, "』")
    tb = loadtable(fname)

    for s in sheetnames(tb)
        out = tb.out[s]
        jws = tb.data[s]
        _apply_postprocess!(jws, get(tb.postprocess, s, Dict{String,Any}()))
        export_worksheet(out, jws)
        localizedata = tb.localizedata[s]
        if !ismissing(localizedata)
            write_localize(out, localizedata)
        end
    end
    nothing
end

"""
    export_worksheet(fname::String, jws::JSONWorksheet)

Writes the JSONWorksheet `jws` to a file with the name `fname`.
If the file does not exist or they are modified, writes JSONWorksheet to the file, otherwise does nothing
"""
function export_worksheet(fname, jws::JSONWorksheet)
    dir = GAMEENV["OUT"]
    filepath = joinpath(dir, fname)
    ext = splitext(fname)[2]

    io = IOBuffer()
    write_to_buffer(io, jws, ext)

    newdata = String(take!(io))
    # Write to file if it's modified
    if !isfile(filepath) || !issamedata(read(filepath, String), newdata)
        write(filepath, newdata)
        print(" SAVE => ")
        printstyled(normpath(filepath), "\n"; color = :blue)
    else
        print("  ⁿ/ₐ => ")
        print(normpath(filepath), "\n")
    end
end

function export_worksheet(tb::XLSXTable, sheetname)
    ws = tb[sheetname]
    fname = tb.out[sheetname]
    println("『", basename(tb), "』")

    _apply_postprocess!(ws, get(tb.postprocess, sheetname, Dict{String,Any}()))
    export_worksheet(fname, ws)
    localizedata = tb.localizedata[sheetname]
    if !ismissing(localizedata)
        write_localize(fname, localizedata)
    end
end

function write_to_buffer(io, jws, ext)
    if ext == ".json"
        XLSXasJSON.write(io, jws)
    elseif ext == ".csv"
        write(io, delimit(jws, ','))
    elseif ext == ".tsv"
        write(io, delimit(jws, '\t'))
    else 
        throw(ArgumentError("\"$ext\" file type is not supported, use \".json\" or \".csv\""))
    end
end


function delimit(jws::JSONWorksheet, delim)
    # you cannot use column name from xlsx for the type notation
    # colnames = map(el -> '/' * join(el.tokens, '/'), keys(jws))
    s = join(keys(jws[1]), delim) * '\n'
    for i in 1:length(jws)
        s *= join(map(el -> delimit(el, delim), values(jws[i])), delim)
        if i < length(jws)
            s *= '\n'
        end
    end
    return s
end

delimit(x, delim) = string(x)
delimit(x::Missing, delim) = ""
delimit(x::Nothing, delim) = ""
delimit(x::AbstractString, delim) = x
function delimit(x::AbstractArray, delim) 
    "[" * join(x, ';') * "]"
end
function delimit(x::AbstractDict, delim) 
    s = "{"
    for (i, (k, v)) in enumerate(x) 
        s *= "\"$k\":" * delimit(v, delim)
        if i < length(x)
            s*=";"
        end
    end
    s *= "}"
    return s 
end

function write_localize(fname, localizedata)
    config = CACHE["config"]["localization"]
    modified = true

    # TODO: proper warnning, when localization setting isn't there
    baselanguage = get(config, "baseLanguage", "kr")

    # only .json is allowed for localization data
    io, ext = splitext(fname)
    io = joinpath(GAMEENV["LOCALIZE"], "$(io)_$(baselanguage).json")
    newdata = JSON.json(localizedata, 2)

    if isfile(io)
        modified = !issamedata(read(io, String), newdata)
    end
    if modified
        write(io, newdata)
        print("  ⨽Localize => ")
        printstyled(normpath(io), "\n"; color = :blue)
    else
        print("  ⨽Localize => ")
        print(normpath(io), "\n")
    end
end


_pointer_str(k::AbstractString) = startswith(k, "/") ? k : "/" * k
_isnullish(v) = v === missing || v === nothing

function apply_empty_values!(jws::JSONWorksheet, mapping::AbstractDict)
    for (rawkey, replacement) in mapping
        ptr = JSONPointer.Pointer(_pointer_str(String(rawkey)))
        for row in jws.data
            haskey(row, ptr) || continue
            v = row[ptr]
            if _isnullish(v)
                row[ptr] = replacement
            end
        end
    end
    return jws
end

function _apply_postprocess!(jws::JSONWorksheet, opts)
    isempty(opts) && return jws
    if haskey(opts, "empty_value")
        apply_empty_values!(jws, opts["empty_value"])
    end
    if get(opts, "omit_null_object", false) === true
        XLSXasJSON.omit_null_objects!(jws)
    end
    return jws
end