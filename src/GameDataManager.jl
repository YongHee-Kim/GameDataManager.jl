module GameDataManager

using JSON
using JSONPointer
using JSONSchema
using OrderedCollections
using PrettyTables
using Printf
using Term
using XLSXasJSON

export init_project, xl, xlookup


include("abstractmeta.jl")
include("config.jl")
include("tables.jl")
include("init.jl")
include("setup.jl")
include("exporter.jl")
include("localizer.jl")
include("schema.jl")
include("show.jl")
include("utils.jl")


end # module
