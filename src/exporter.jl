function xl(exportall::Bool = false)
    files = keys(CACHE["tables"])
    if isempty(files)
        print_section("추출할 파일이 없습니다."; color=:yellow)
    else
        print_section(
            "xlsx -> json 추출을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
            color = :cyan,
        )
        for f in files
            try
                export_xlsxtable(f)
            catch e
                printstyled("$f 데이터 추출 실패\n"; color = :red)
            end
        end
        print_section("데이터 추출이 완료되었습니다 ☺", "DONE"; color = :cyan)
    end
end
function xl(file)
    reload_meta!()

    print_section(
        "xlsx -> json 추출을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color = :cyan,
    )
    export_xlsxtable(file)
    print_section("json 추출이 완료되었습니다 ☺", "DONE"; color = :cyan)

    nothing
end


"""
    export_gamedata(file::AbstractString)
    export_gamedata(exportall::Bool = false)

* file="filename.xlsx": 지정된 파일만 json으로 추출합니다
* exportall = true    : 모든 파일을 json으로 추출합니다
* exportall = false   : 변경된 .xlsx파일만 json으로 추출합니다

mars 메인 저장소의 '.../_META.json'에 명시된 파일만 추출가능합니다
"""
function export_xlsxtable(fname)
    println("『", fname, "』")
    tb = loadtable(fname)

    for s in sheetnames(tb)
        fname = tb.out[s]
        write_worksheet(fname, tb.data[s])
        localize = tb.localizedata[s]
        if !ismissing(localize)
            write_localize(fname, localize)
        end
    end
    nothing
end
function write_worksheet(fname, jws::JSONWorksheet)
    dir = GAMEENV["OUT"]

    io = joinpath(dir, fname)
    newdata = JSON.json(jws, 2)
    # 편집된 시트만 저장
    modified = true
    if isfile(io)
        modified = !issamedata(read(io, String), newdata)
    end
    if modified
        write(io, newdata)
        print(" SAVE => ")
        printstyled(normpath(io), "\n"; color = :blue)
    else
        print("  ⁿ/ₐ => ")
        print(normpath(io), "\n")
    end
end
function write_localize(fname, localizedata)
    dir = GAMEENV["LOCALIZE"]
    io = joinpath(dir, fname)
    modified = true

    newdata = JSON.json(localizedata, 2)
    if isfile(io)
        modified = !issamedata(read(io, String), newdata)
    end
    if modified
        write(io, newdata)
        print("⨽  SAVE => ")
        printstyled(normpath(io), "\n"; color = :blue)
    else
        print("  ⨽  => ")
        print(normpath(io), "\n")
    end
end