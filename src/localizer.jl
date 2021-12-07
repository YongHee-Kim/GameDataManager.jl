# Convert Special Charaters in Keys
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
                                    '~' => "."
                                    )


"""
    localizer!

일단 간단하게 키 배정
"""
localize!(x) = x
function localize!(tb::XLSXTable)
    # TODO: keycolum이 array일 때 혼합키로 localizekey 생성할 것
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
    # _Meta에 정의된 keycolumn을 Pointer로 전환 
    if !isempty(keycolumn)
        keycolumn = JSONPointer.Pointer(keycolumn)
    end

    target_tokens = Tuple[]
    for (i, row) in enumerate(jws)
        localize_table!(row, ["\$gamedata.$(filename)", i], target_tokens)
    end
    
    localizedata = OrderedDict{String, Any}()
    for (token, text) in target_tokens
        if isa(keycolumn, JSONPointer.Pointer)
            keyvalues = jws[token[2]][keycolumn]
            finalkey = gamedata_lokalkey(token, keyvalues)
        else
            # uses rownumber
            finalkey = gamedata_lokalkey(token)
        end
        if haskey(localizedata, finalkey)
            throw(AssertionError("`$finalkey`가 중복되었습니다. config.json에서 정의한 keycolumn의 값이 중복되지 않는지 확인해 주세요\n$(keycolumn) "))
        end
        localizedata[finalkey] = text

        
        row_idx = token[2]
        p1 = "/" * join(token[3:end], "/") # 원본
        p2 = replace(p1, "\$" => "") # 발급된를 $이 제거된 컬럼에 저장
        jws.data[row_idx][JSONPointer.Pointer(p2)] = finalkey
    end
    return localizedata
end

# Dict의 Key가 '$'으로 시작하면 있으면 로컬라이즈 대상이다
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

json gamedata의 Lokalise 플랫폼용 Key를 구성한다
"""
function gamedata_lokalkey(tokens)
    # $gamedata.(파일명)#/(JSONPointer)/rowindex"
    idx = @sprintf("%04i", tokens[2]) #0000 형태
    string(tokens[1], 
            ".", replace(join(tokens[3:end], "."), "\$" => ""),
            ".", idx)
end
function gamedata_lokalkey(tokens, keyvalues)
    # $gamedata.(파일명)#/(JSONPointer)/keycolum_values"
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
    # $gamedata.(파일명)#/keycolum_values/(JSONPointer)"
    # lokalise에서 XML로 빌드하면 .과 _를 제외한 특수문자를 잘라먹기 때문에 어쩔 수 없이 전부 _로 전환 
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
