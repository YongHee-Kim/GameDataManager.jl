using Documenter, GameDataManager

makedocs(
    sitename = "GameDataManager.jl",
    modules = [ GameDataManager ],
    checkdocs=:warnonly, # should be :all, need to fix the error 
    authors = "YongHee Kim",
    pages = [ "Home" => "index.md",
              "Tutorial" => "tutorial.md",
              "API Reference" => "api.md"
            ]
)

# deploydocs(
#     repo = "github.com/felipenoris/XLSX.jl.git",
#     target = "build",
# )
