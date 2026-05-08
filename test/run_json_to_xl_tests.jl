using GameDataManager
using JSON, JSONPointer
using OrderedCollections
using Test

import GameDataManager.GAMEENV

project_path = joinpath(@__DIR__, "project")
init_project(project_path)

import GameDataManager: json_to_xl, json_to_xl_table, json_to_xl_worksheet,
    json_to_xl_localize!, json_to_xl_matrix, json_to_xl_row, json_to_xl_headers,
    json_to_xl_cell, json_to_xl_write
import GameDataManager: CACHE
using XLSX

@testset "JSON → XLSX (json_to_xl)" begin

    @testset "json_to_xl_cell" begin
        @test json_to_xl_cell(42, ';') === 42
        @test json_to_xl_cell(3.14, ';') === 3.14
        @test json_to_xl_cell(true, ';') === true
        @test json_to_xl_cell("hello", ';') == "hello"
        @test ismissing(json_to_xl_cell(missing, ';'))
        @test ismissing(json_to_xl_cell(nothing, ';'))
        @test json_to_xl_cell([1, 2, 3], ';') == "1;2;3"
        @test json_to_xl_cell(["a", "b"], ',') == "a,b"
        @test json_to_xl_cell([1, 2, 3], '|') == "1|2|3"
        d = OrderedDict("Value1" => "Apple", "Value2" => "Grape")
        @test json_to_xl_cell(d, ';') == "{\"Value1\":Apple;\"Value2\":Grape}"
        @test json_to_xl_cell(:sym, ';') == "sym"
        @test json_to_xl_cell([1, missing, 3], ';') == "1;;3"
        @test json_to_xl_cell([1, nothing, 3], ';') == "1;;3"
        @test json_to_xl_cell([[1, 2], [3]], ';') == "1;2;3"
        d2 = OrderedDict("a" => [1, 2])
        @test json_to_xl_cell(d2, ';') == "{\"a\":1;2}"
    end

    @testset "json_to_xl_headers" begin
        @test json_to_xl_headers(Any[]) == String[]
        rows = [OrderedDict("A" => 1, "B" => 2)]
        @test json_to_xl_headers(rows) == ["/A", "/B"]
        rows = [OrderedDict("Sun" => OrderedDict("Rise" => 6, "Set" => 18), "TZ" => "GMT")]
        @test json_to_xl_headers(rows) == ["/Sun/Rise", "/Sun/Set", "/TZ"]
        rows = [OrderedDict("Nums" => [1, 2, 3])]
        @test json_to_xl_headers(rows) == ["/Nums"]
        rows = [
            OrderedDict("A" => 1, "B" => 2),
            OrderedDict("A" => 3, "C" => 4),
        ]
        @test json_to_xl_headers(rows) == ["/A", "/B", "/C"]
        rows = [OrderedDict("X" => OrderedDict{String,Any}())]
        @test json_to_xl_headers(rows) == ["/X"]
        # Empty array in one row must not duplicate a parent column when other
        # rows expand the same prefix into children.
        rows = [
            OrderedDict("R" => [OrderedDict("Id" => "A", "N" => 1),
                                OrderedDict("Id" => "B", "N" => 2)]),
            OrderedDict("R" => Any[]),
        ]
        @test json_to_xl_headers(rows) == ["/R/1/Id", "/R/1/N", "/R/2/Id", "/R/2/N"]
        # Scalar string array: collapse when joining round-trips, expand when
        # any element already contains the delim character.
        rows = [OrderedDict("S" => ["Power", "2"])]
        @test json_to_xl_headers(rows) == ["/S"]
        rows = [OrderedDict("S" => ["a;b", "c", "d"])]
        @test json_to_xl_headers(rows) == ["/S/1", "/S/2", "/S/3"]
        # Existing-header hint forces indexed-array expansion even when the
        # JSON values would otherwise collapse (Excel column was already laid
        # out as `Attributes/1`, `Attributes/2`).
        rows = [OrderedDict("Attributes" => ["Str", 50])]
        @test json_to_xl_headers(rows) == ["/Attributes"]
        existing = ["Key", "Attributes/1", "Attributes/2"]
        @test json_to_xl_headers(rows; existing_headers=existing) ==
            ["/Attributes/1", "/Attributes/2"]
    end

    @testset "json_to_xl_row" begin
        row = OrderedDict("A" => 1, "B" => OrderedDict("C" => 2))
        pairs = json_to_xl_row(row)
        @test first.(pairs) == ["/A", "/B/C"]
        @test last.(pairs) == [1, 2]
        rows = [OrderedDict("A" => 1, "B" => 2), OrderedDict("A" => 3)]
        m = json_to_xl_matrix(rows, NamedTuple())
        @test ismissing(m[3, 2])
    end

    @testset "json_to_xl_matrix" begin
        rows = [
            OrderedDict("A" => 1, "B" => "x"),
            OrderedDict("A" => 2, "B" => "y"),
        ]
        m = json_to_xl_matrix(rows, NamedTuple())
        @test size(m) == (3, 2)
        @test m[1, 1] == "/A"
        @test m[1, 2] == "/B"
        @test m[2, 1] == 1 && m[2, 2] == "x"
        @test m[3, 1] == 2 && m[3, 2] == "y"

        m2 = json_to_xl_matrix(rows, (start_line=3,))
        @test size(m2) == (5, 2)
        @test ismissing(m2[1, 1]) && ismissing(m2[2, 1])
        @test m2[3, 1] == "/A"
        @test m2[4, 1] == 1
        @test m2[5, 1] == 2

        m3 = json_to_xl_matrix(rows, (row_oriented=false,))
        @test size(m3) == (2, 3)
        @test m3[1, 1] == "/A"
        @test m3[2, 1] == "/B"
        @test m3[1, 2] == 1
        @test m3[1, 3] == 2
        @test m3[2, 2] == "x"
        @test m3[2, 3] == "y"

        m4 = json_to_xl_matrix([rows[1]], (start_line=3, row_oriented=false))
        @test size(m4) == (4, 2)
        @test ismissing(m4[1, 1]) && ismissing(m4[2, 1])
        @test m4[3, 1] == "/A"
        @test m4[3, 2] == 1
        @test m4[4, 1] == "/B"
        @test m4[4, 2] == "x"

        rows_arr = [OrderedDict("Nums" => [1, 2, 3])]
        m5 = json_to_xl_matrix(rows_arr, (delim='|',))
        @test m5[2, 1] == "1|2|3"

        m6 = json_to_xl_matrix(rows, Dict("start_line" => 2))
        @test size(m6) == (4, 2)
        @test m6[2, 1] == "/A"
    end

    @testset "json_to_xl_localize!" begin
        init_project(project_path)
        sym = :Items
        tb = CACHE["config"].tables[sym]
        sheetname = "Weapon"
        @test tb.localize_key[sheetname] == "/Key"

        loc_dir = GAMEENV["LOCALIZE"]
        mkpath(loc_dir)
        loc_file = joinpath(loc_dir, "Items_Weapon_eng.json")
        loc_data = OrderedDict(
            "\$gamedata.Items_Weapon.Description.WPN001" => "Translated text",
        )
        write(loc_file, JSON.json(loc_data, 2))

        rows = [
            OrderedDict(
                "Key" => "WPN001",
                "\$Description" => "stale source",
                "Description" => "\$gamedata.Items_Weapon.Description.WPN001",
            ),
            OrderedDict(
                "Key" => "WPN002",
                "\$Description" => "",
            ),
        ]
        json_to_xl_localize!(rows, tb, sheetname)
        @test rows[1]["\$Description"] == "Translated text"
        @test !haskey(rows[1], "Description")
        @test rows[1]["Key"] == "WPN001"
        @test rows[2]["\$Description"] == ""
        @test rows[2]["Key"] == "WPN002"

        sym2 = :TestData
        tb2 = CACHE["config"].tables[sym2]
        @test ismissing(tb2.localize_key["Array"])
        rows_no_loc = [OrderedDict("X" => 1)]
        before = deepcopy(rows_no_loc)
        json_to_xl_localize!(rows_no_loc, tb2, "Array")
        @test rows_no_loc == before

        rm(loc_file)
        rows3 = [OrderedDict(
            "Key" => "WPN999",
            "\$Description" => "fallback",
            "Description" => "\$gamedata.Items_Weapon.Description.WPN999",
        )]
        json_to_xl_localize!(rows3, tb, sheetname)
        @test rows3[1]["\$Description"] == "fallback"
        @test !haskey(rows3[1], "Description")

        rows4 = [OrderedDict(
            "Outer" => OrderedDict(
                "\$Inner" => "x",
                "Inner" => "no-such-key",
            ),
        )]
        json_to_xl_localize!(rows4, tb, sheetname)
        @test !haskey(rows4[1]["Outer"], "Inner")
        @test rows4[1]["Outer"]["\$Inner"] == "x"
    end

    @testset "json_to_xl_write" begin
        tmpdir = mktempdir()
        path = joinpath(tmpdir, "out.xlsx")

        m1 = Matrix{Any}(missing, 3, 2)
        m1[1, 1] = "/Key"; m1[1, 2] = "/Name"
        m1[2, 1] = 1;       m1[2, 2] = "Apple"
        m1[3, 1] = 2;       m1[3, 2] = "Banana"

        m2 = Matrix{Any}(missing, 2, 2)
        m2[1, 1] = "/X"; m2[1, 2] = "/Y"
        m2[2, 1] = 10;   m2[2, 2] = 20

        json_to_xl_write(path, ["Fruits" => m1, "Coords" => m2])
        @test isfile(path)

        XLSX.openxlsx(path) do xf
            @test XLSX.sheetnames(xf) == ["Fruits", "Coords"]
            s = xf["Fruits"]
            @test s[1, 1] == "/Key"
            @test s[1, 2] == "/Name"
            @test s[2, 1] == 1
            @test s[2, 2] == "Apple"
            @test s[3, 2] == "Banana"
            s2 = xf["Coords"]
            @test s2[1, 1] == "/X"
            @test s2[2, 2] == 20
        end
    end

    @testset "json_to_xl_write — in-place diff against existing xlsx" begin
        # Build a seed workbook in test/data with content that extends beyond
        # what we'll later overwrite, plus a second sheet we never list, so we
        # can verify preservation of out-of-bounds cells, untouched sheets,
        # and clearing-on-blank.
        data_dir = joinpath(@__DIR__, "data")
        mkpath(data_dir)
        seed_path = joinpath(data_dir, "diff_seed.xlsx")
        XLSX.openxlsx(seed_path, mode="w") do xf
            XLSX.rename!(xf[1], "Main")
            s = xf[1]
            s[1, 1] = "/Key"; s[1, 2] = "/Name";   s[1, 3] = "/Note"
            s[2, 1] = 1;      s[2, 2] = "Apple";   s[2, 3] = "fruit"
            s[3, 1] = 2;      s[3, 2] = "Banana";  s[3, 3] = "yellow"
            XLSX.addsheet!(xf, "Other")
            s2 = xf["Other"]
            s2[1, 1] = "untouched"
            s2[2, 1] = "stays"
        end

        # Work on a copy so the seed remains reusable across runs
        work = joinpath(mktempdir(), "out.xlsx")
        cp(seed_path, work)

        # Diff matrix:
        #   row 1  headers identical    → no rewrite (still equals)
        #   [2,1]  same value (1)       → no rewrite
        #   [2,2]  "Apple"  → "Apricot" → overwritten
        #   [2,3]  "fruit"  → missing   → cleared
        #   row 3  out of matrix bounds → preserved as-is
        m = Matrix{Any}(missing, 2, 3)
        m[1, 1] = "/Key"; m[1, 2] = "/Name"; m[1, 3] = "/Note"
        m[2, 1] = 1;       m[2, 2] = "Apricot"  # m[2, 3] stays missing

        json_to_xl_write(work, ["Main" => m])

        XLSX.openxlsx(work) do xf
            # Untouched sheet preserved
            @test "Other" in XLSX.sheetnames(xf)
            @test xf["Other"][1, 1] == "untouched"
            @test xf["Other"][2, 1] == "stays"

            s = xf["Main"]
            @test s[1, 1] == "/Key"
            @test s[1, 2] == "/Name"
            @test s[1, 3] == "/Note"
            @test s[2, 1] == 1
            @test s[2, 2] == "Apricot"
            @test ismissing(s[2, 3])
            # Row 3 is outside the new matrix — must survive verbatim
            @test s[3, 1] == 2
            @test s[3, 2] == "Banana"
            @test s[3, 3] == "yellow"
        end

        # Second write: append a brand-new sheet to the same file. Existing
        # sheets ("Main", "Other") must not be disturbed.
        m_new = Matrix{Any}(missing, 1, 1)
        m_new[1, 1] = "fresh"
        json_to_xl_write(work, ["NewSheet" => m_new])
        XLSX.openxlsx(work) do xf
            names = XLSX.sheetnames(xf)
            @test "NewSheet" in names
            @test "Other" in names
            @test "Main" in names
            @test xf["NewSheet"][1, 1] == "fresh"
            @test xf["Main"][2, 2] == "Apricot"
            @test xf["Other"][1, 1] == "untouched"
        end
    end

    @testset "json_to_xl_worksheet" begin
        init_project(project_path)
        out_dir = GAMEENV["OUT"]
        mkpath(out_dir)
        weapon = [
            OrderedDict(
                "Key" => 1,
                "\$Name" => "Sword",
                "Name" => "\$gamedata.Items_Weapon.Name.1",
            ),
            OrderedDict(
                "Key" => 2,
                "\$Name" => "Axe",
                "Name" => "\$gamedata.Items_Weapon.Name.2",
            ),
        ]
        write(joinpath(out_dir, "Items_Weapon.json"), JSON.json(weapon, 2))

        loc_dir = GAMEENV["LOCALIZE"]
        mkpath(loc_dir)
        loc_data = OrderedDict(
            "\$gamedata.Items_Weapon.Name.1" => "Sword",
            "\$gamedata.Items_Weapon.Name.2" => "Axe",
        )
        write(joinpath(loc_dir, "Items_Weapon_eng.json"), JSON.json(loc_data, 2))

        tb = CACHE["config"].tables[:Items]
        sn, m = json_to_xl_worksheet(tb, "Weapon")
        @test sn == "Weapon"
        @test size(m, 1) == 3
        # Header row reuses the existing Excel column names (`Key`, `Name`)
        # rather than the JSONPointer-style paths. `/$Name` matches `Name`
        # via the `$` localization-source marker normalization.
        @test m[1, 1] == "Key"
        @test m[1, 2] == "Name"
        @test m[2, 1] == 1 && m[2, 2] == "Sword"
        @test m[3, 1] == 2 && m[3, 2] == "Axe"
        @test size(m, 2) == 2

        @test_throws ArgumentError json_to_xl_worksheet(
            CACHE["config"].tables[:TestData], "Csv")

        rm(joinpath(out_dir, "Items_Weapon.json"))
        @test_throws ArgumentError json_to_xl_worksheet(tb, "Weapon")
    end

    @testset "json_to_xl_table + entry points" begin
        init_project(project_path)
        out_dir = GAMEENV["OUT"]
        loc_dir = GAMEENV["LOCALIZE"]
        mkpath(out_dir)
        mkpath(loc_dir)

        for sheet in ("Weapon", "Armour", "Accessory")
            data = [OrderedDict(
                "Key" => 1,
                "\$Name" => "$(sheet)Item",
            )]
            write(joinpath(out_dir, "Items_$(sheet).json"), JSON.json(data, 2))
            write(joinpath(loc_dir, "Items_$(sheet)_eng.json"),
                  JSON.json(OrderedDict{String,Any}(), 2))
        end

        items_path = joinpath(GAMEENV["XLSX"], "Items.xlsx")
        backup = read(items_path)
        try
            json_to_xl_table("Items")
            @test isfile(items_path)
            XLSX.openxlsx(items_path) do xf
                @test issubset(Set(["Weapon", "Armour", "Accessory"]), Set(XLSX.sheetnames(xf)))
                @test xf["Weapon"][1, 1] == "Key"
                @test xf["Weapon"][1, 2] == "Name"
                @test xf["Weapon"][2, 1] == 1
                @test xf["Weapon"][2, 2] == "WeaponItem"
            end

            json_to_xl("items"; strict=true)
            @test isfile(items_path)

            @test_throws ArgumentError json_to_xl("NoSuchFile"; strict=true)
            @test json_to_xl("NoSuchFile"; strict=false) === nothing

            @test json_to_xl(; strict=false) === nothing
        finally
            write(items_path, backup)
        end

        empty_cfg = mktempdir()
        cfg = OrderedDict(
            "name" => "Empty",
            "environment" => OrderedDict(
                "xlsx" => "./xlsx", "out" => "./json",
                "localize" => "./localization", "jsonschema" => "./jsonschema"),
            "localization" => OrderedDict("baseLanguage" => "eng"),
            "xlsxtables" => OrderedDict{String,Any}(),
        )
        write(joinpath(empty_cfg, "config.json"), JSON.json(cfg, 2))
        init_project(empty_cfg)
        @test json_to_xl(; strict=false) === nothing

        init_project(project_path)
    end
end
