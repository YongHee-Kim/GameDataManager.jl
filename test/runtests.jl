using GameDataManager
using Test 

import GameDataManager.GAMEENV

project_path = joinpath(@__DIR__, "project")

@testset "Project Setting" begin 
    @test !isdir("$(project_path)/json")
    init_project(project_path)

    @test isdir("$(project_path)/json")
    rm("$(project_path)/json")
end

@testset "Read XLSXTable" begin 
    jwb = GameDataManager.loadtable("Items")
    jwb2 = GameDataManager.loadtable("items")
    # jwb3 = GameDataManager.loadtable("items.xlsx")
    @test jwb == jwb2
    @test basename(jwb) == "Items.xlsx"
    @test normpath(dirname(jwb)) == normpath(joinpath(project_path, "xlsx"))
    @test GameDataManager.sheetnames(jwb) == ["Equipment", "Consumable"]
end

@testset "Export to JSON" begin 

end 

@testset "Export to CSV, TSV" begin

end