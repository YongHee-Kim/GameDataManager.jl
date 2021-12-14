"""
    Schema

Thin wrapper around JSONSchema.Schema to store `filepath` and `mtime`  
"""
mutable struct Schema
    filepath::AbstractString
    schema::Union{Missing, JSONSchema.Schema}
    mtime::Float64 
end
function Schema(file)
    Schema(file, missing, 0.)
end

isloaded(x::Schema) = isa(x.schema, JSONSchema.Schema)
function ismodified(x::Schema)
    if isloaded(x)
        return x.mtime != mtime(x.filepath)
    else 
        return true 
    end
end
function loaddata!(x::Schema)
    x.schema = JSONSchema.Schema(JSON.parsefile(x.filepath; use_mmap=false))
    # x.mtime = mtime(x.filepath)
    return x
end

"""
    validate(bt::XLSXTable)
    validate(jws::JSONWorksheet)

validate 
"""
function validate(tb::XLSXTable)
    for sheet in sheetnames(tb)
        errors = validate(tb, sheet)
        if !isempty(errors)
            msgs = pretty_schemaerror(tb, sheet, errors)
            for (msg_error, msg_sol) in msgs
                print_section(msg_error[1], msg_error[2]; color=:yellow)
                printstyled(msg_sol, "\n"; color=:red)
            end
        end
    end
    nothing
end

function validate(tb::XLSXTable, sheet)
    schema = tb.schema[sheet]
    if !ismissing(schema)
        if ismodified(schema) 
            loaddata!(schema)
        end
        return validate(tb[sheet], schema)
    end 
    return []
end

function validate(jws::JSONWorksheet, schema::Schema)    
    err = OrderedDict()
    @inbounds for (i, row) in enumerate(jws)
        val = JSONSchema.validate(row, schema.schema)
        if !isnothing(val)
            marker = "$i"
            err[marker] = val
        end
    end
    return err
end

function pretty_schemaerror(tb::XLSXTable, sheet, err::AbstractDict)
    paths = map(el -> el.path, values(err))

    msgs = []
    for p in unique(paths)
        # error가 난 데이터 내용
        cause = []
        for el in err 
            if el[2].path == p 
        x = (el[1], el[2].x)
                push!(cause, x)
        end
        end
        # error 원인, 값
        errors = filter(el -> el.path == p, collect(values(err)))
        reason = unique(map(el -> el.reason, values(errors)))
        schemaval = unique(map(el -> el.val, values(errors)))

        error_info = [
        """
        $(tb) Validation failed from {key: $reason, summary: $(summary(schemaval[1]))}
        sheet:        $sheet
        column:       $p
        instance:     $cause
        """, 
        "$(tb) Validation failed from {key: $reason, summary: $(summary(schemaval[1]))}"]
        
        solution = get_schema_description(tb, sheet, p)
        if !ismissing(solution)
            sol_info = "해결방법\n  ↳ $(solution)"
        else 
            if length(reason) == 1 
                sol_info = "\"$(reason[1])\": $(schemaval[1])"
            else 
                sol_info = "$(reason): $(schemaval)"
            end 
            if length(sol_info) > 42
                sol_info = sol_info[1:40] * "......"
            end
        end
        push!(msgs, (error_info, sol_info))
    end
    return msgs
end

function get_schema_description(tb::XLSXTable, sheet, path)
    schema = tb.schema[sheet]
    desc = get_schema_description(schema, path)
end
function get_schema_description(schema::Schema, path)
    d = get_schemaelement(schema.schema, path)
    if isa(d, AbstractDict)
        get(d, "description", missing)
    else 
        missing 
    end
end
function get_schemaelement(schema, path)
    # patternProperties는 element를 찾지 않는다
    if !haskey(schema.data, "properties")
        return missing 
    end
    wind = schema.data["properties"]
    paths = filter(!isempty, replace.(split(path, "]"), "[" => ""))
    for (i, p) in enumerate(paths)
        if ismissing(wind) 
            break 
        end
        if i == 1 
            wind = get(wind, p, missing)
        elseif occursin(r"^\d+$", p)
            wind = get(wind, "items", missing)
            if isa(wind, AbstractArray)
                idx = parse(Int, p) 
                if idx > lastindex(wind)
                    throw(BoundsError(schema, paths))
                end
                wind = wind[parse(Int, p)]
            end
        else 
            if haskey(wind, "\$ref")
                if haskey(wind["\$ref"], "properties")
                    wind = get(wind["\$ref"]["properties"], p, missing)
                elseif haskey(wind["\$ref"], "patternProperties")
                    wind = get(wind["\$ref"]["patternProperties"], p, missing)
                else 
                    wind = missing 
                end
            else 
                wind = get(wind["properties"], p, missing)
            end
        end
    end
    return wind
end