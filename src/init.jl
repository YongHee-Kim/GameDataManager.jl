const GAMEENV = Dict{String,Any}()
const CACHE = Dict{String,Any}(
        "config" => missing,
        "validation" => true,
        "tables" => Dict{String,Any}(),
        "tablesschema" => Dict())

function setupenv()
    println("foo")
end
    
