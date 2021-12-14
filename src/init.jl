const GAMEENV = Dict{String,String}()
const CACHE = Dict{String,Any}(
"config" => missing,
"tables" => Dict{Symbol,Any}())

function __init__()
    if isfile(joinpath(pwd(), "config.json"))
        init_project(pwd())
    end
end