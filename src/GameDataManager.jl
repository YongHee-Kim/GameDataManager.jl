module GameDataManager

using Printf
using REPL
using JSON, JSONPointer, JSONSchema
using XLSXasJSON
using OrderedCollections

export init_project, xl


include("metadata.jl")
include("tables.jl")
include("init.jl")
include("setup.jl")
include("exporter.jl")
include("localizer.jl")
include("schema.jl")
include("utils.jl")


end # module
