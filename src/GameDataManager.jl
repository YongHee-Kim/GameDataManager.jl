module GameDataManager

using JSON, JSONPointer, JSONSchema
using XLSXasJSON
using OrderedCollections
using SQLite, Tables

export init_project


include("init.jl")
include("setup.jl")



end # module
