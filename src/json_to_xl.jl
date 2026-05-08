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
            bt = catch_backtrace()
            push!(failures, string(f) => e)
            printstyled("$f import failed:\n"; color=:red)
            showerror(stdout, e, bt)
            println()
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
        # Bulk import covers every configured sheet, but only .json outputs
        # round-trip; .csv/.tsv sheets are silently skipped here. Explicit
        # `json_to_xl_worksheet(tb, s)` calls still error on non-json.
        if lowercase(splitext(tb.out[s])[2]) != ".json"
            continue
        end
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
    rows = JSON.parsefile(filepath; dicttype=OrderedDict{String, Any})
    json_to_xl_localize!(rows, tb, sheetname)

    # Peek at the existing Excel header row so we can preserve `::type{eltype}`
    # annotations and the indexed-vs-collapsed array layout when round-tripping.
    existing_headers = _read_existing_headers(tb, sheetname)
    matrix = json_to_xl_matrix(rows, tb.kwargs[sheetname]; existing_headers=existing_headers)
    return sheetname => matrix
end

function _read_existing_headers(tb::XLSXTable, sheetname)
    path = xlsxpath(tb)
    isfile(path) || return String[]
    return XLSX.openxlsx(path) do xf
        sheetname in XLSX.sheetnames(xf) || return String[]
        kwargs = tb.kwargs[sheetname]
        start_line = _kwget(kwargs, :start_line, 1)
        row_oriented = _kwget(kwargs, :row_oriented, true)
        sheet = xf[sheetname]
        if row_oriented
            row = sheet[start_line, :]
            return [_to_str(row[j]) for j in 1:length(row)]
        else
            col = sheet[:, 1]
            n = length(col)
            return start_line > n ? String[] : [_to_str(col[i]) for i in start_line:n]
        end
    end
end

_to_str(::Missing) = ""
_to_str(::Nothing) = ""
_to_str(s::AbstractString) = String(s)
_to_str(x) = string(x)

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
        JSON.parsefile(loc_path; dicttype=OrderedDict{String, Any})
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
    json_to_xl_headers(rows; delim=';', existing_headers=String[]) -> Vector{String}

Walk every row and return the union of leaf paths in first-seen order. Paths
are JSONPointer-style (`"/Sun/Rise"`). Scalar arrays collapse to a single
leaf path when joining with `delim` round-trips losslessly; if any string
element already contains `delim`, the array is expanded into indexed paths
(`/X/1`, `/X/2`, …). When `existing_headers` is given, prefixes already
laid out as indexed columns there (`X/1`, `X/2`, …) are forced to expand
even if the JSON values would otherwise collapse — this keeps the original
Excel column structure intact across a round-trip.
"""
function json_to_xl_headers(rows; delim=';', existing_headers=String[])
    expanded = _expanded_prefixes(existing_headers)
    seen = OrderedDict{String, Bool}()
    for row in rows
        _collect_paths!("", row, seen, delim, expanded)
    end
    paths = collect(keys(seen))
    # An empty array/dict in one row collapses its prefix to a leaf path; if
    # another row expands the same prefix into children, drop the parent so we
    # don't emit both `/X` and `/X/1/...` columns.
    return filter(p -> !any(q -> q != p && startswith(q, p * "/"), paths), paths)
end

# Strip JSONPointer-style leading `/`, `::type{eltype}` annotations, and the
# leading `$` localization-source marker. Used purely for matching generated
# paths to existing Excel column headers by their base name.
function _norm_header(s::AbstractString)
    s2 = replace(s, r"^/+" => "")
    s2 = replace(s2, r"::.*$" => "")
    s2 = replace(s2, r"^\$" => "")
    return strip(s2)
end
_norm_header(::Any) = ""

# Existing Excel headers shaped like `X/1`, `X/2`, … signal that the array at
# `X` was originally laid out as indexed columns (one per element). When we
# rebuild the matrix, scalar arrays under such a prefix must expand back into
# indexed leaf paths instead of collapsing to a single delimited cell.
function _expanded_prefixes(existing_headers)
    s = Set{String}()
    for h in existing_headers
        n = _norm_header(h)
        m = match(r"^(.*)/(\d+)(?:/.*)?$", n)
        m === nothing && continue
        push!(s, String(m.captures[1]))
    end
    return s
end

function _collect_paths!(prefix, node::AbstractDict, seen, delim, expanded)
    if isempty(node) && !isempty(prefix)
        seen[prefix] = true
        return
    end
    for (k, v) in node
        path = prefix * "/" * String(k)
        _collect_paths!(path, v, seen, delim, expanded)
    end
end
function _collect_paths!(prefix, node::AbstractArray, seen, delim, expanded)
    if isempty(node)
        seen[prefix] = true
        return
    end
    if all(x -> !isa(x, AbstractDict) && !isa(x, AbstractArray), node)
        # Scalar array: collapse to one delimited cell when joining round-trips
        # losslessly. Force expansion when (a) the existing Excel laid this
        # prefix out as indexed columns or (b) any element string already
        # contains `delim` (joining would conflate the delim with content).
        forced = _norm_header(prefix) in expanded
        if forced || any(x -> isa(x, AbstractString) && occursin(delim, x), node)
            for (i, el) in enumerate(node)
                _collect_paths!(prefix * "/" * string(i), el, seen, delim, expanded)
            end
        else
            seen[prefix] = true
        end
    else
        # 1-based array indices to match JSONPointer.jl's non-standard indexing
        # (it explicitly rejects "/0/..." paths). See JSONPointer/src/pointer.jl.
        for (i, el) in enumerate(node)
            _collect_paths!(prefix * "/" * string(i), el, seen, delim, expanded)
        end
    end
end
function _collect_paths!(prefix, node, seen, _delim, _expanded)
    seen[prefix] = true
end

"""
    json_to_xl_row(row::AbstractDict) -> Vector{Pair{String, Any}}

Flatten one row into `(header, leaf_value)` pairs in column order.
"""
function json_to_xl_row(row::AbstractDict; delim=';', existing_headers=String[])
    headers = json_to_xl_headers([row]; delim=delim, existing_headers=existing_headers)
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
            # Tokens are 1-based to match JSONPointer.jl indexing.
            idx = tryparse(Int, p)
            if idx === nothing || idx < 1 || idx > length(cur)
                return missing
            end
            cur = cur[idx]
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
function json_to_xl_matrix(rows, kwargs; existing_headers=String[])
    start_line = _kwget(kwargs, :start_line, 1)
    row_oriented = _kwget(kwargs, :row_oriented, true)
    delim = _kwget(kwargs, :delim, ';')
    paths = json_to_xl_headers(rows; delim=delim, existing_headers=existing_headers)
    # `paths` are the JSONPointer-style lookup keys used to fetch cell values.
    # `display` are the strings written into the header row — when an existing
    # Excel header normalizes to the same name, we reuse its decorated form so
    # `::type{eltype}` annotations and the leading `$` localization marker
    # round-trip back into the column header.
    display = _decorate_paths(paths, existing_headers)

    if row_oriented
        ncols = max(length(paths), 1)
        nrows = (start_line - 1) + 1 + length(rows)
        m = Matrix{Any}(missing, nrows, ncols)
        for (j, h) in enumerate(display)
            m[start_line, j] = h
        end
        for (i, row) in enumerate(rows)
            for (j, p) in enumerate(paths)
                m[start_line + i, j] = json_to_xl_cell(_get_at_path(row, p), delim)
            end
        end
        return m
    else
        nrecords = length(rows)
        nrows = max((start_line - 1) + length(paths), 1)
        ncols = max(1 + nrecords, 1)
        m = Matrix{Any}(missing, nrows, ncols)
        for (i, p) in enumerate(paths)
            r = start_line + i - 1
            m[r, 1] = display[i]
            for (k, row) in enumerate(rows)
                m[r, 1 + k] = json_to_xl_cell(_get_at_path(row, p), delim)
            end
        end
        return m
    end
end

function _decorate_paths(paths, existing_headers)
    isempty(existing_headers) && return collect(String, paths)
    norm_to_existing = Dict{String, String}()
    for h in existing_headers
        isa(h, AbstractString) && !isempty(h) || continue
        n = _norm_header(h)
        isempty(n) && continue
        get!(norm_to_existing, n, String(h))
    end
    return [get(norm_to_existing, _norm_header(p), p) for p in paths]
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
