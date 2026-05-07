using XLSX

"""
    json_to_xl(; strict=false)
    json_to_xl(fname; strict=false)

Inverse of [`xl`](@ref). Reads the per-sheet JSON in `GAMEENV["OUT"]`, restores
localized text from `GAMEENV["LOCALIZE"]`, and rewrites the source `.xlsx`
workbook(s) listed in `config.json`.

Round-trip guarantee: JSON-equivalence (`xl()` ⇨ `json_to_xl` ⇨ `xl()` produces
identical JSON), not byte-identical XLSX. Formulas, formatting, comments,
merged-cell metadata, frozen panes, and hidden sheets are not reconstructed.
"""
function json_to_xl(; strict::Bool=false)
    update!(CACHE["config"])

    files = xlsxfilenames(CACHE["config"])
    if isempty(files)
        print_section("nothing to import."; color=:yellow)
        return nothing
    end
    print_section(
        "importing JSON back to xlsx... ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color=:cyan,
    )
    failures = Pair{String, Exception}[]
    for f in files
        try
            json_to_xl_table(f)
        catch e
            strict && rethrow()
            push!(failures, string(f) => e)
            printstyled("$f import failed: ", sprint(showerror, e), "\n"; color=:red)
        end
    end
    n_ok = length(files) - length(failures)
    if isempty(failures)
        print_section("$(length(files)) xlsx files are imported ☺", "DONE"; color=:cyan)
    else
        print_section(
            "$n_ok ok, $(length(failures)) failed:\n" *
            join(("  - $f" for (f, _) in failures), '\n'),
            "DONE WITH ERRORS"; color=:yellow,
        )
    end
    return nothing
end

function json_to_xl(fname; strict::Bool=false)
    update!(CACHE["config"])
    print_section(
        "importing JSON back to xlsx... ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color=:cyan,
    )
    try
        json_to_xl_table(fname)
    catch e
        strict && rethrow()
        printstyled("$fname import failed: ", sprint(showerror, e), "\n"; color=:red)
        return nothing
    end
    print_section("import complete ☺", "DONE"; color=:cyan)
    return nothing
end

"""
    json_to_xl_table(fname)

Per-workbook orchestrator. Loads `XLSXTable` for `fname`, builds a matrix per
configured sheet from its corresponding JSON, then writes the assembled
workbook back to `xlsxpath(tb)`.
"""
function json_to_xl_table(fname)
    println("『", fname, "』 (← JSON)")
    tb = _resolve_table(fname)

    sheets = Pair{String, Matrix{Any}}[]
    for s in sheetnames(tb)
        push!(sheets, json_to_xl_worksheet(tb, s))
    end

    path = xlsxpath(tb)
    json_to_xl_write(path, sheets)
    return nothing
end

# Fuzzy-match a workbook name to an `XLSXTable` from CACHE["config"]. Unlike
# `loadtable`, we do not call `loaddata!`: the inverse path needs only the
# metadata fields (`out`, `kwargs`, `localize_key`, file path) that the
# `XLSXTable` constructor populates eagerly.
function _resolve_table(fname)
    config = CACHE["config"]
    sym = Symbol(fname)
    if !haskey(config.tables, sym)
        hay = string.(xlsxfilenames(config))
        needle = string(fname)
        for h in hay
            if lowercase(h) == lowercase(needle)
                sym = Symbol(h)
                break
            end
        end
        if !haskey(config.tables, sym)
            throw_fuzzylookupname(string.(xlsxfilenames(config)), string(fname))
        end
    end
    return config.tables[sym]
end

"""
    json_to_xl_worksheet(tb::XLSXTable, sheetname) -> sheetname => Matrix{Any}

Parse the JSON file for one sheet, restore localization, and return a matrix
ready for `XLSX.openxlsx` cell-by-cell writing.
"""
function json_to_xl_worksheet(tb::XLSXTable, sheetname)
    out_fname = tb.out[sheetname]
    ext = splitext(out_fname)[2]
    if ext != ".json"
        throw(ArgumentError(
            "json_to_xl only supports .json source outputs, got \"$ext\" for sheet \"$sheetname\""))
    end
    filepath = joinpath(GAMEENV["OUT"], out_fname)
    if !isfile(filepath)
        throw(ArgumentError("$filepath not found — run xl() first to produce JSON before importing"))
    end
    rows = JSON.parsefile(filepath; dicttype=OrderedDict{String, Any}, use_mmap=false)
    json_to_xl_localize!(rows, tb, sheetname)

    matrix = json_to_xl_matrix(rows, tb.kwargs[sheetname])
    return sheetname => matrix
end

"""
    json_to_xl_localize!(rows, tb::XLSXTable, sheetname) -> rows

If the sheet is configured with a localize keycolumn, merge the matching
`{basename}_{baseLanguage}.json` localization file back into `rows`: for every
generated key column `X` paired with a `\$X` source-text column, copy the
localized text into `\$X` and drop `X` (which never existed in the source xlsx).
The localization file is the source of truth — translator edits there flow
back. If the file is missing, we fall back to whatever `\$X` already holds.
Inverse of `localize!` in `localizer.jl`.
"""
function json_to_xl_localize!(rows, tb::XLSXTable, sheetname)
    keycolumn = tb.localize_key[sheetname]
    if !isa(keycolumn, AbstractString) || isempty(keycolumn)
        return rows
    end
    base = get(CACHE["config"]["localization"], "baseLanguage", "kr")
    out_fname = tb.out[sheetname]
    loc_fname = splitext(out_fname)[1] * "_$(base).json"
    loc_path = joinpath(GAMEENV["LOCALIZE"], loc_fname)
    localizedata = if isfile(loc_path)
        JSON.parsefile(loc_path; dicttype=OrderedDict{String, Any}, use_mmap=false)
    else
        OrderedDict{String, Any}()
    end
    for row in rows
        _localize_node!(row, localizedata)
    end
    return rows
end

function _localize_node!(node::AbstractDict, localizedata)
    to_delete = String[]
    for k in collect(keys(node))
        if isa(k, AbstractString) && startswith(k, "\$")
            k2 = k[nextind(k, 1):end]
            if haskey(node, k2)
                loc_key = node[k2]
                if isa(loc_key, AbstractString) && haskey(localizedata, loc_key)
                    node[k] = localizedata[loc_key]
                end
                push!(to_delete, k2)
            end
        end
    end
    for k in to_delete
        delete!(node, k)
    end
    for v in values(node)
        if isa(v, AbstractDict) || isa(v, AbstractArray)
            _localize_node!(v, localizedata)
        end
    end
    return node
end
function _localize_node!(node::AbstractArray, localizedata)
    for el in node
        if isa(el, AbstractDict) || isa(el, AbstractArray)
            _localize_node!(el, localizedata)
        end
    end
    return node
end
_localize_node!(node, localizedata) = node

"""
    json_to_xl_headers(rows) -> Vector{String}

Walk every row and return the union of leaf paths in first-seen order. Paths
are JSONPointer-style (`"/Sun/Rise"`); arrays of scalars are kept as a single
leaf path (the array becomes one delimited cell).
"""
function json_to_xl_headers(rows)
    seen = OrderedDict{String, Bool}()
    for row in rows
        _collect_paths!("", row, seen)
    end
    return collect(keys(seen))
end

function _collect_paths!(prefix, node::AbstractDict, seen)
    if isempty(node) && !isempty(prefix)
        seen[prefix] = true
        return
    end
    for (k, v) in node
        path = prefix * "/" * String(k)
        _collect_paths!(path, v, seen)
    end
end
function _collect_paths!(prefix, node::AbstractArray, seen)
    if isempty(node) || all(x -> !isa(x, AbstractDict) && !isa(x, AbstractArray), node)
        seen[prefix] = true
    else
        for (i, el) in enumerate(node)
            _collect_paths!(prefix * "/" * string(i - 1), el, seen)
        end
    end
end
function _collect_paths!(prefix, node, seen)
    seen[prefix] = true
end

"""
    json_to_xl_row(row::AbstractDict) -> Vector{Pair{String, Any}}

Flatten one row into `(header, leaf_value)` pairs in column order.
"""
function json_to_xl_row(row::AbstractDict)
    headers = json_to_xl_headers([row])
    return [h => _get_at_path(row, h) for h in headers]
end

function _get_at_path(node, path::AbstractString)
    parts = split(path, '/'; keepempty=false)
    cur = node
    for p in parts
        if isa(cur, AbstractDict)
            if haskey(cur, p)
                cur = cur[p]
            else
                return missing
            end
        elseif isa(cur, AbstractArray)
            idx = tryparse(Int, p)
            if idx === nothing || idx < 0 || idx + 1 > length(cur)
                return missing
            end
            cur = cur[idx + 1]
        else
            return missing
        end
    end
    return cur
end

"""
    json_to_xl_matrix(rows, kwargs) -> Matrix{Any}

Flatten rows into a matrix laid out for `XLSX.openxlsx` cell-by-cell writing.
Honours `start_line` (blank rows above the header), `row_oriented`
(`false` ⇒ headers in column 1, records as additional columns), and `delim`
(default `;`) for delimited array cells.
"""
function json_to_xl_matrix(rows, kwargs)
    headers = json_to_xl_headers(rows)
    start_line = _kwget(kwargs, :start_line, 1)
    row_oriented = _kwget(kwargs, :row_oriented, true)
    delim = _kwget(kwargs, :delim, ';')

    if row_oriented
        ncols = max(length(headers), 1)
        nrows = (start_line - 1) + 1 + length(rows)
        m = Matrix{Any}(missing, nrows, ncols)
        for (j, h) in enumerate(headers)
            m[start_line, j] = h
        end
        for (i, row) in enumerate(rows)
            for (j, h) in enumerate(headers)
                m[start_line + i, j] = json_to_xl_cell(_get_at_path(row, h), delim)
            end
        end
        return m
    else
        nrecords = length(rows)
        nrows = max((start_line - 1) + length(headers), 1)
        ncols = max(1 + nrecords, 1)
        m = Matrix{Any}(missing, nrows, ncols)
        for (i, h) in enumerate(headers)
            r = start_line + i - 1
            m[r, 1] = h
            for (k, row) in enumerate(rows)
                m[r, 1 + k] = json_to_xl_cell(_get_at_path(row, h), delim)
            end
        end
        return m
    end
end

# kwargs may be NamedTuple or AbstractDict (from namedtuple() conversion)
_kwget(kwargs::NamedTuple, key::Symbol, default) =
    haskey(kwargs, key) ? getfield(kwargs, key) : default
function _kwget(kwargs::AbstractDict, key::Symbol, default)
    if haskey(kwargs, string(key))
        return kwargs[string(key)]
    elseif haskey(kwargs, key)
        return kwargs[key]
    end
    return default
end

"""
    json_to_xl_cell(value, delim)

Inverse of `delimit` in `exporter.jl`. Scalars pass through (numbers/bools
keep their type so XLSX stores them as numeric/bool cells); arrays become
`delim`-joined strings; nested dicts become the same `{"k":v;...}` mini-syntax
the CSV/TSV exporter emits.
"""
json_to_xl_cell(x, delim) = string(x)
json_to_xl_cell(x::Missing, delim) = missing
json_to_xl_cell(x::Nothing, delim) = missing
json_to_xl_cell(x::AbstractString, delim) = String(x)
json_to_xl_cell(x::Bool, delim) = x
json_to_xl_cell(x::Real, delim) = x
function json_to_xl_cell(x::AbstractArray, delim)
    join(map(el -> _cell_string(el, delim), x), string(delim))
end
function json_to_xl_cell(x::AbstractDict, delim)
    parts = String[]
    for (k, v) in x
        push!(parts, "\"$k\":" * _cell_string(v, delim))
    end
    "{" * join(parts, string(delim)) * "}"
end

# Always returns a String — used inside arrays/dicts where the parent is a
# single delimited cell.
_cell_string(x, delim) = string(x)
_cell_string(x::Missing, delim) = ""
_cell_string(x::Nothing, delim) = ""
_cell_string(x::AbstractString, delim) = x
function _cell_string(x::AbstractArray, delim)
    join(map(el -> _cell_string(el, delim), x), string(delim))
end
function _cell_string(x::AbstractDict, delim)
    parts = String[]
    for (k, v) in x
        push!(parts, "\"$k\":" * _cell_string(v, delim))
    end
    "{" * join(parts, string(delim)) * "}"
end

"""
    json_to_xl_write(path, sheets)

Write `sheets` (a vector of `sheetname => Matrix{Any}`) to `path`. If `path`
already exists, the workbook is opened for in-place editing (`mode="rw"`):
each cell is read first and only overwritten when its value differs, so
formatting, formulas, comments, and cells outside the matrix bounds are
preserved. Sheets present in `sheets` but missing from the workbook are
appended; sheets in the workbook not listed in `sheets` are left untouched.
If `path` does not exist, a fresh workbook is created. `missing` / `nothing`
/ empty-string cells in `m` clear the corresponding cell in an existing
workbook (and are left blank when creating fresh).
"""
function json_to_xl_write(path, sheets)
    mkpath(dirname(path))
    if isfile(path)
        XLSX.openxlsx(path, mode="rw") do xf
            existing = XLSX.sheetnames(xf)
            for (sheetname, m) in sheets
                sheet = sheetname in existing ? xf[sheetname] : XLSX.addsheet!(xf, sheetname)
                _write_sheet_diff!(sheet, m)
            end
        end
    else
        XLSX.openxlsx(path, mode="w") do xf
            for (idx, (sheetname, m)) in enumerate(sheets)
                sheet = if idx == 1
                    XLSX.rename!(xf[1], sheetname)
                    xf[1]
                else
                    XLSX.addsheet!(xf, sheetname)
                end
                _write_sheet_diff!(sheet, m)
            end
        end
    end
    print(" SAVE => ")
    printstyled(normpath(path), "\n"; color=:blue)
    return path
end

function _write_sheet_diff!(sheet, m)
    nrows, ncols = size(m)
    for i in 1:nrows, j in 1:ncols
        v = m[i, j]
        is_blank = ismissing(v) || v === nothing || (isa(v, AbstractString) && isempty(v))
        current = sheet[i, j]
        if is_blank
            ismissing(current) || (sheet[i, j] = missing)
        elseif ismissing(current) || current != v
            sheet[i, j] = v
        end
    end
end
