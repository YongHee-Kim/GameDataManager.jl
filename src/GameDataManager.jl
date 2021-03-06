module GameDataManager


using Printf
using REPL.TerminalMenus
using JSON, JSONPointer, JSONSchema
using XLSXasJSON
using OrderedCollections
using PrettyTables

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
