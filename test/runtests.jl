using GameDataManager
using JSON, JSONPointer
using OrderedCollections
using DelimitedFiles
using Test 

import GameDataManager.GAMEENV

project_path = joinpath(@__DIR__, "project")
@testset "init_project tests" begin

    @test isdir("$(project_path)/json")
    @test isdir("$(project_path)/localization")

    config_file = joinpath(project_path, "config.json")
    JSON.parsefile(config_file)
    config_json = JSON.parsefile(config_file; dicttype=OrderedDict{String,Any}, use_mmap=false)

    GDMconfig = init_project(project_path)
    @test GDMconfig.data == config_json
end


@testset "Read XLSXTable" begin 
    tb = GameDataManager.loadtable("Items")
    tb2 = GameDataManager.loadtable("items")
    # jwb3 = GameDataManager.loadtable("items.xlsx")
    @test tb == tb2
    @test basename(tb) == "Items.xlsx"
    @test normpath(dirname(tb)) == normpath(joinpath(project_path, "xlsx"))
    @test GameDataManager.sheetnames(tb) == ["Weapon", "Armour", "Accessory"]
end

@testset "Export to JSON" begin 
    xl()
    dir = GAMEENV["OUT"]
    @test isfile(joinpath(dir, "TestData_Column.json"))
    @test isfile(joinpath(dir, "TestData_Array.json"))
    @test isfile(joinpath(dir, "TestData_Object.json"))
    @test isfile(joinpath(dir, "TestData_Csv.csv"))
    @test isfile(joinpath(dir, "TestData_Tsv.tsv"))
    @test isfile(joinpath(dir, "Items_Weapon.json"))
    @test isfile(joinpath(dir, "Items_Armour.json"))
    @test isfile(joinpath(dir, "Items_Accessory.json"))

    # Data Structure 
    coldata = JSON.parsefile(joinpath(dir, "TestData_Column.json"); dicttype=OrderedDict)
    @test length(coldata) == 1
    @test coldata[1]["TimeZone"] == "GMT+0"
    @test collect(keys(coldata[1]["Sun"])) == ["Rise", "Set"]
    @test coldata[1]["SoundProfile"]["MasterVolume"] == 90
    @test isa(coldata[1]["ProfileSpecificGameProfile"]["Invert"], AbstractDict)

    arrdata = JSON.parsefile(joinpath(dir, "TestData_Array.json"); dicttype=OrderedDict)
    for row in arrdata 
        @test isa(row["Integers"], AbstractArray)
        @test isa(row["Numbers"], AbstractArray)
        @test isa(row["Sepciality"], AbstractArray)
        @test all(isa.(row["Integers"], Integer))
        @test all(isa.(row["Numbers"], Float64))
        @test all(isa.(row["Sepciality"], String))
    end

    objdata = JSON.parsefile(joinpath(dir, "TestData_Object.json"); dicttype=OrderedDict)
    for row in objdata 
        @test isa(row["Attributes"], AbstractDict)
        @test isa(row["Speciality"], AbstractDict)
    end
end 

@testset "Export to CSV, TSV" begin
    dir = GAMEENV["OUT"]
    csvdata = readdlm(joinpath(dir, "TestData_Csv.csv"), ',')
    @test csvdata[2, 3] == "[Str;50]"
    @test csvdata[2, 4] == "{\"Value1\":Apple;\"Value2\":Grape}"
    

    tsvdata = readdlm(joinpath(dir, "TestData_Tsv.tsv"), '\t')
    @test tsvdata[3, 3] == "[Dex;10]"
    @test tsvdata[3, 4] == "{\"Value1\":Gold;\"Value2\":Silver}"
    @test size(csvdata) == size(tsvdata) == (6,5)
    # Localization keys are different 
    @test csvdata[:, 1:4] == tsvdata[:, 1:4]
end


@testset "Localization" begin 
    # localize files 
    @test isfile(joinpath(GAMEENV["LOCALIZE"], "Items_Weapon_eng.json"))
    @test isfile(joinpath(GAMEENV["LOCALIZE"], "Items_Armour_eng.json"))
    @test isfile(joinpath(GAMEENV["LOCALIZE"], "Items_Accessory_eng.json"))

    localizedata = OrderedDict{String, String}()
    for f in readdir(GAMEENV["LOCALIZE"]; join = true)
        objdata = JSON.parsefile(f; dicttype=OrderedDict)
        merge!(localizedata, objdata)
    end

    # # check origin file
    #  for (fname, tb) in GameDataManager.CACHE["tables"] 
    #     for (sheet, localizedata) in tb.localizedata 
    #         if !ismissing(localizedata)

    #         end
    #     end
    #  end
end


# @testset "JSONSchema validation" begin 
#     tb = GameDataManager.loadtable("Items")
#     GameDataManager.validate(tb, "Equipment")
# end


