function xl(exportall::Bool = false)
    update!(CACHE["config"])

    files = xlsxfilenames(CACHE["config"])
    if isempty(files)
        print_section("nothing to export."; color=:yellow)
    else
        print_section(
            "exporting xlsx files... ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
            color = :cyan,
        )
        for f in files
            try
                export_xlsxtable(f)
            catch e
                printstyled("$f export failed\n"; color = :red)
            end
        end
        print_section("$(length(files)) xlsx files are exported ☺", "DONE"; color = :cyan)
    end
end
function xl(fname)
    update!(CACHE["config"])

    print_section(
        "exporting xlsx file... ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color = :cyan,
    )
    export_xlsxtable(fname)
    print_section("export complete ☺", "DONE"; color = :cyan)

    nothing
end


"""
    export_xlsxtable(file::AbstractString)

export a given excel worsheets to a output file specified in 'config.json'
"""
function export_xlsxtable(fname)
    println("『", fname, "』")
    tb = loadtable(fname)

    for s in sheetnames(tb)
        fname = tb.out[s]
        export_worksheet(fname, tb.data[s])
        localizedata = tb.localizedata[s]
        if !ismissing(localizedata)
            write_localize(fname, localizedata)
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