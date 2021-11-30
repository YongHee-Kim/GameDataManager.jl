using GameDataManager
using Test 


project_path = joinpath(@__DIR__, "project")

@testset "Project Setting" begin 
    @test !isdir("$(project_path)/json")
    init_project(project_path)

    @test isdir("$(project_path)/json")
    rm("$(project_path)/json")
end

@testset "Export to JSON" begin 

end 

@testset "Export to CSV, TSV" begin

end