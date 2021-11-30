function xl(exportall::Bool = false)
    reload_meta!()
    updateschema_tablekey()

    files = exportall ? collect_auto_xlsx() : collect_modified_xlsx()
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
                printstyled("$f json -> xlsx 변환 실패\n"; color = :red)
            end
        end
        print_section("json 추출이 완료되었습니다 ☺", "DONE"; color = :cyan)
    end
end
function xl(file::AbstractString)
    reload_meta!()

    print_section(
        "xlsx -> json 추출을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color = :cyan,
    )
    export_xlsxtable(file)
    print_section("json 추출이 완료되었습니다 ☺", "DONE"; color = :cyan)

    nothing
end

function json_to_xl()
    print_section(
        "json -> xlsx 재변환을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color = :cyan,
    )

    for f in collect_auto_xlsx()
        try
            reconstruct_xlsxtable(f)
        catch e
            printstyled("$f json -> xlsx 변환 실패\n"; color = :red)
        end
    end
    print_section("xlsx 변환이 완료되었습니다 ☺", "DONE"; color = :cyan)
end
function json_to_xl(f::AbstractString)
    print_section(
        "json -> xlsx 재변환을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color = :cyan,
    )

    reconstruct_xlsxtable(f)

    print_section("xlsx 변환이 완료되었습니다 ☺", "DONE"; color = :cyan)
end
