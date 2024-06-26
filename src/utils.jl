
is_xlsxfile(f)::Bool = endswith(f, r".xlsx|.xlsm")
is_jsonfile(f)::Bool = endswith(f, ".json")

isnull(x) = ismissing(x) | isnothing(x)
function skipnothing(itr)
    [x for x in itr if !isnothing(x)]
end
function skipnull(itr)
    skipnothing(skipmissing(itr))
end
function issamedata(a, b)::Bool
    isequal(hash(a), hash(b))
end

function namedtuple(d::AbstractDict{String,T}) where T
    key = (Symbol.(collect(keys(d)))...,)
    val = (collect(values(d))...,)
    NamedTuple{key}(val)
end
function namedtuple(d::AbstractDict{Symbol,T}) where T 
    key = (collect(keys(d))...,)
    val = (collect(values(d))...,)
    NamedTuple{key}(val)
end

function print_write_result(path, msg="The result is...")
    print_section("$(msg)\n   SAVED => $(normpath(path))", "DONE"; color=:green)

    nothing
end

function print_section(message, title="NOTE"; color=:normal)
    msglines = split(chomp(string(message)), '\n')

    for (i, el) in enumerate(msglines)
        prefix = length(msglines) == 1 ? "[ $title: " :
                                i == 1 ? "┌ $title: " :
                                el == last(msglines) ? "└ " : "│ "

        printstyled(stderr, prefix; color=color)
        print(stderr, el)
        print(stderr,  '\n')
    end
    nothing
end

function throw_fuzzylookupname(keyset, idx; kwargs...)
    throw_fuzzylookupname(collect(keyset), idx; kwargs...)
end

function throw_fuzzylookupname(names::AbstractArray, idx::AbstractString; 
                                msg="'$idx' not found")
    l = Dict{AbstractString,Int}(zip(names, eachindex(names)))
    candidates = XLSXasJSON.fuzzymatch(l, idx)
    if isempty(candidates)
        throw(ArgumentError(msg))
    end
    candidatesstr = join(string.("\"", candidates, "\""), ", ", " and ")
    throw(ArgumentError(msg * "\nexisting most similar names are: $candidatesstr"))
end

function strip_pointer(p::JSONPointer.Pointer)
    "/" * join(p.tokens[1:end], "/")
end