function Base.show(io::IO, con::ConfigData)
    print(io, "ConfigData: ")
    println(io, con.filepath)

    for (fname, sheetdata) in con["xlsxtables"]
        print(io, "  ┕", fname)
        print(io, " - [")
        if haskey(sheetdata, "workSheets")
            for el in sheetdata["workSheets"]
                print(io, "\"", el["name"], "\"")
                if el != last(sheetdata["workSheets"])
                    print(io, ", ")
                end
            end
        end
        println(io, "]")
    end
end

function Base.show(io::IO, bt::XLSXTable)
    println(io, "XLSXTable")
    sheets = sheetnames(bt)
    outfiles = collect(values(bt.out))
    schemas = .!(ismissing.(values(bt.schemas)))

    pretty_table(io, hcat(1:length(sheets), sheets, outfiles, schemas);
        column_labels = ["Idx", "Sheet", "Out", "Schema"], alignment = :l,
        backend = :markdown)

end
