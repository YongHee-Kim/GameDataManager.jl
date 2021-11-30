
isnull(x) = ismissing(x) | isnothing(x)
function skipnothing(itr)
    [x for x in itr if !isnothing(x)]
end
function skipnull(itr)
    skipnothing(skipmissing(itr))
end
function print_write_result(path, msg="다음과 같습니다")
    print_section("$(msg)\n   SAVED => $(normpath(path))", "연산결과"; color=:green)

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