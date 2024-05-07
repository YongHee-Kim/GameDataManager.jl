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

julia> Pkg.add("https://github.com/YongHee-Kim/GameDataManager.jl")
```

## Getting Started

### 1. Project Configuration
The config.json file is used to specify the Excel files and sheets that you want to export to JSON or CSV format. The JSON data structure for the config.json file is as follows:
```json 
{

    "name": "MyGame",
    "environment": {
        "xlsx": "./xlsx",
        "out": "./json",
        "localize": "./localization",
     },
    "xlsxtables": {
        "filename.xlsx": {
            "workSheets": [
               {
                    "name": "ColumnOrient",
                    "out": "TestData_Column.json",

                }
            ]
        },
        ......
    }     
    ]
}
```
Details description for properties in a `config.json` can be found [here](https://github.com/YongHee-Kim/GameDataManager.jl/blob/main/data/config.json). Following is some important properties
1. `environment`: Defines file paths to read from and save files to. These paths are relative to the config.json file
    - `xlsx`: root path for Excel files
    - `out`: root path for converted files
    - `localize`: root path for the localization files

2. `xlsxtables`: Excel files and sheets to be exported to JSON or CSV format. Filename, sheetname and the output file name should be given here. See the example above for the  configurations

### 2. XLSX table structure 
The Excel table structure required by GameDataManager.jl is simple. The topmost row the table should contain the keys that will be used in the resulting JSON dictionaries. Each row below this will be turned into a JSON object.

Here's an example of a valid Excel table:
|name|age|
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
By default, the **GameDataManager.jl** generates a JSON array where each row in the provided worksheet is converted into a JSON object. The keys from the topmost row of the xlsx table will be used as keys in the JSON objects, and the corresponding values in each row will be the values in the JSON objects.


*2) Working with Nested Data*
Nested JSON data can  easily created with **GameDataManger.jl**data structures from your Excel worksheets. This is useful for represnting complex data structure.

**JSONPointer as Keys**
GameDataManager.jl supports [JSONPointer](https://datatracker.ietf.org/doc/html/rfc6901) syntax to generate nested json. 

Below is an example data table with JSONPointer header
| name  | age | hobbies/0 | hobbies/1 | address/street | address/city |
|-------|-----|-----------|-----------|----------------|--------------|
| Alice | 25  | Reading   | Cooking   | 123 Main St    | New York     |
| Bob   | 30  | Hiking    | Painting  | 456 Maple Ave  | Los Angeles  |

In this table, the column headers use JSONPointer syntax to specify the structure of the nested data. The /hobbies/0 and /hobbies/1 columns represent a nested array of hobbies. The /address/street and /address/city columns represent a nested object for the address. 

As a result, converted json will be: 
```json
[
    {
        "name": "Alice",
        "age": 25,
        "hobbies": ["Reading", "Cooking"],
        "address": {
            "street": "123 Main St",
            "city": "New York"
        }
    },
    {
        "name": "Bob",
        "age": 30,
        "hobbies": ["Hiking", "Painting"],
        "address": {
            "street": "456 Maple Ave",
            "city": "Los Angeles"
        }
    }
]
```


3) Specifying data type 
Sometimes it is convinient to define data type. 


### 2. Advanced Usage 
### Optional properties for a *config.json*
The config.json file used by GameDataManager.jl allows you to customize how your Excel data is processed. In this section, we will cover the other possible properties that you can include in your config.json file.


```json
{...
    "xlsxtables": {
        "TestData.xlsx": {
            "workSheets": [
                {
                    "name": "ColumnOrient",
                    "out": "TestData_Column.json",
                    "kwargs": {
                        "start_line": 3,
                        "row_oriented": false
                    }
                },
...}
```


start_line (optional): The row in the sheet where the data starts. This is useful if you have header rows in your sheet that you want to skip. The start_line property is 0-indexed, so a start_line of 1 would skip the first row in your sheet.
row_oriented (optional): A boolean that determines whether the data in your sheet is row-oriented or column-oriented. If row_oriented is true, GameDataManager.jl will treat each row in your sheet as a separate item in the JSON output. If row_oriented is false, it will treat each column as a separate item.
squeeze (optional): A boolean that determines whether single-column or single-row data should be squeezed into a scalar. If squeeze is true, GameDataManager.jl will convert single-column or single-row data into a scalar in the JSON output. If squeeze is false, it will keep single-column or single-row data as arrays.
You can specify as many sheets as you want for each Excel file. Just add another object to the workSheets array for each sheet you want to export.

|name|
|--|
|Alice|
|Bob|

In this example, each row in the Excel table has been converted into a separate scalar value in the JSON output.

squeeze set to false (default)
When the squeeze property is set to false, GameDataManager.jl will keep single-column data as arrays in the JSON output. Here's what the output would look like:
```
[
    {
        "name": "Alice"
    },
    {
        "name": "Bob"
    }
]
```

In this example, each row in the Excel table has been converted into a separate object in the JSON output. Even though there's only one column of data, each object includes the column name as a key.



delim
The delim property is a string that specifies the delimiter to use when splitting column names to create nested data structures. The default delimiter is /.