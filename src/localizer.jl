# Convert Special Charaters in Keys to "." and "__" for braces
const SPECIAL_CHAR_CONVERT = Dict('[' => "__", ']' => "__",
                                    '{' => "__", '}' => "__",
                                    '(' => "__", ')' => "__",
                                    ';' => ".", 
                                    ':' => ".", 
                                    '`' => ".",
                                    '"' => ".", 
                                    ''' => ".",
                                    ',' => ".",
                                    '<' => ".", 
                                    '>' => ".",
                                    '/' => ".",
                                    '\\'  => ".",
                                    '?' => ".",
                                    '!' => ".",
                                    '@' => ".",
                                    '#' => ".",
                                    '$' => ".",
                                    '%' => ".",
                                    '^' => ".",
                                    '&' => ".",
                                    '*' => ".",
                                    '-' => ".",
                                    '+' => ".",
                                    '=' => ".",
                                    '|' => ".",
                                    '~' => ".")

# 
"""
    localizer!(x::XLSXTable)

find keys starts with '\$' and localize it with given filename and keycolumn
"""
localize!(x) = x
function localize!(tb::XLSXTable)
    for s in sheetnames(tb)
        filename = tb.out[s]
        keycolumn = tb.localize_key[s]
        if isa(keycolumn, AbstractString)
            tb.localizedata[s] = localize!(tb[s], filename, keycolumn)
        end
    end
    return tb
end

function localize!(jws::JSONWorksheet, filename, keycolumn::AbstractString)
    filename = splitext(filename)[1] 
    if !isempty(keycolumn)
        keycolumn = JSONPointer.Pointer(keycolumn)
    end

    # Put localization keys and values in the 'localize_targets'
    localize_targets = Tuple[]
    for (i, row) in enumerate(jws)
        localize_table!(row, ["\$gamedata.$(filename)", i], localize_targets)
    end
    localizedata = OrderedDict{String, Any}()
    for (token, text) in localize_targets
        if isa(keycolumn, JSONPointer.Pointer)
            keyvalues = jws[token[2]][keycolumn]
            @assert !isnull(keyvalues) "$filename[$(strip_pointer(keycolumn)), $(token[2])] is missing. Key column must be filled to localize"
            finalkey = gamedata_lokalkey(token, keyvalues)
        else
            # uses rownumber
            finalkey = gamedata_lokalkey(token)
        end
        if haskey(localizedata, finalkey)
            throw(AssertionError("`$finalkey` is duplicated. Please check if keycolumn in config.json is unique\n$(keycolumn) "))
        end
        localizedata[finalkey] = text

        
        row_idx = token[2]
        p1 = "/" * join(token[3:end], "/") # Original JSONPointer
        p2 = replace(p1, "\$" => "") # Replace $ to get pure JSONPointer
        jws.data[row_idx][JSONPointer.Pointer(p2)] = finalkey
    end
    return localizedata
end

# Localize columns are marked with '$' in the column name
islocalize_column(s) = false
islocalize_column(s::AbstractString) = startswith(s, "\$")
function islocalize_column(p::JSONPointer.Pointer)::Bool
    @inbounds for k in p.tokens
        if islocalize_column(k)
            return true 
        end
    end
    return false
end

"""
    gamedata_lokalisekey(tokens)
    gamedata_lokalisekey(tokens, keyvalues)

generate localization key from JSONPointer token
"""
function gamedata_lokalkey(tokens)
    # $gamedata.(FileName)#/(JSONPointer)/rowindex"
    idx = @sprintf("%04i", tokens[2]) #0000 ~ 9999
    string(tokens[1], 
            ".", replace(join(tokens[3:end], "."), "\$" => ""),
            ".", idx)
end
function gamedata_lokalkey(tokens, keyvalues)
    # $gamedata.(FileName)#/(JSONPointer)/keycolum_values"
    idx = ""
    for el in keyvalues 
        if !isnull(el) && !isempty(el)
            if isa(el, AbstractArray)
                idx *= "__" * join(el, ".") * "__"
            else 
                idx *= string(el)
            end
        end
    end
    gamedata_lokalkey(tokens, idx)
end
function gamedata_lokalkey(tokens, combinedkey::AbstractString)
    # $gamedata.(FileName)#/keycolum_values/(JSONPointer)"
    # some localization services won't allow special characters except "." and "_" 
    REG_NOTWORD = r"[^A-Za-z0-9ㄱ-ㅎㅏ-ㅣ가-힣]"
    if occursin(REG_NOTWORD, combinedkey)
        idx = ""
        for w in combinedkey 
            if haskey(SPECIAL_CHAR_CONVERT, w)
                idx *= SPECIAL_CHAR_CONVERT[w]
            else 
                idx *= w
            end
        end
    else 
        idx = combinedkey
    end
    string(tokens[1], 
        ".", replace(join(tokens[3:end], "."), "\$" => ""),
        ".", idx)
end

localize_table!(x, token, holder) = nothing
function localize_table!(arr::AbstractArray, token, holder)
    for (i, row) in enumerate(arr) 
        localize_table!(row, vcat(token, i), holder)
    end
    return holder
end
function localize_table!(dict::AbstractDict, token, holder)
    data = Array{Any, 1}(undef, length(dict))
    for (i, kv) in enumerate(dict) 
       localize_table!(kv[2], vcat(token, kv[1]), holder)
    end
    return holder
end
function localize_table!(sentence::Union{AbstractString, Number}, token, holder)
    if any(islocalize_column.(token[3:end]))
        push!(holder, (token, string(sentence)))
    end
    return holder
end
