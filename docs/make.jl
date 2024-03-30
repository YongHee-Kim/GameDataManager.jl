using Documenter, GameDataManager

# copy coverage report to build folder for Documentor.jl to take along to `gh-pages` branch 
function copy_coverage()
  source = joinpath(@__DIR__, "src/coverage")
  target = joinpath(@__DIR__, "build/coverage")
  @info "Copy $source to $target" 

  cp(source, target; force = true)
  nothing
end

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

deploydocs(
    repo   = "github.com/YongHee-Kim/GameDataManager.jl.git",
    target = "build",
    deps   = copy_coverage(),
    make   = nothing
)
