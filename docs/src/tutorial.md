# Introduction 

**GameDataManager.jl** is a tool designed to streamline the game development process by efficiently managing game data. It is particularly useful for GaaS, which tend to have larger data tables that reqires frequent update and balance changes




With GameDataManager.jl, you can:

- Convert Excel files (.xlsx and .xlsm) to JSON, CSV, or TSV formats, that game engines can read
- Auto generation of localization data and assining key with simple configuration on excel column names
- Validate JSON data using JSONSchema, ensuring that your game data is correctly structured and error-free.
- Use a simple API to write Julia scripts for data wrangling and simulation, making it easier to setup workflow that generates necessary stastics for game design and balancing 


## Setup

First, make sure you have **GameDataManager.jl** package installed.

```julia
julia> using Pkg

julia> Pkg.add("GameDataManger")
```

## Getting Started

### Configuring config.json
The config.json file is used to specify the Excel files and sheets that you want to export to JSON or CSV format. The JSON data structure for the config.json file is as follows:
```json 
{
    ......
    "xlsxtables": {
        "filename.xlsx": {
            "workSheets": [
               {
                    "name": "ColumnOrient",
                    "out": "TestData_Column.json",

                }
        }
    }
        {
            "name": "filename.xlsx",
            "sheets": [
                "Sheet1",
                "Sheet2"
            ]
        }
    ]
}
```

In this structure, files is an array of objects, each representing an Excel file. Each file object has a name property, which is the name of the Excel file, and a sheets property, which is an array of sheet names that you want to export from that file.

### Excel Table Structure
The Excel table structure required by GameDataManager.jl is as follows:

The column name must follow the JSONPointer format.
All rows below the column names will be turned into JSON objects.
For example:

    |name	|age|
    |--|--|
    |Alice	|25|
    |Bob	|30|
This table will be turned into the following JSON:
```json
[
    {
        "name": "Alice",
        "age": 25
    },
    {
        "name": "Bob",
        "age": 30
    }
]
```

# Advanced Features
Nested Data
GameDataManger.jl supports nested data structures. To create a nested data structure, use the / character in your column names to represent different levels of nesting.

Localization
GameDataManger.jl can generate localization data using a combination of file name and a given key column or row number. To use this feature, specify the localization property in your config.json file as follows:

In this example, the first column will be used as the key, and the second column will be used as the value for the generated localization data.