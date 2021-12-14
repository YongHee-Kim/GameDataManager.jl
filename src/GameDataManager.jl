module GameDataManager

using Printf
using DelimitedFiles
using JSON, JSONPointer, JSONSchema
using XLSXasJSON
using OrderedCollections
using SQLite, Tables

export init_project, xl


include("tables.jl")
include("init.jl")
include("setup.jl")
include("exporter.jl")
include("localizer.jl")
include("schema.jl")
include("utils.jl")


end # module
