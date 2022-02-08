# GameDataManager.jl[KR](README_KR.md/#Introduction)
Easy and convenient toolkit for game designers to help manage data tables

# Acknowledgement
GameDataManager wouldn't have been possible without the endorsement from [Devsisters](https://www.devsisters.com) to open source the inhouse tool of the [same name](https://github.com/devsisters/GameDataManager.jl). 

# Introduction 
Game industries have seen lots of innovation and technological advancement. But only the game design department was fell behind such innovations. Artists and software engineers won't be able to tools from 20 years ago. But not the game designers. We can use Excel 2003 with little or no trouble because the tools game designers use didn't change much over the decades. Game designers spend most of their working hours wrestling with data. They have to architect the relationship between data and calculate possible outcomes of the interaction between players and data. And [GAAS](https://en.wikipedia.org/wiki/Games_as_a_service) made managing data even more complicated. Spreadsheet is just not enough to handle the complex datas for GAAS 
This is where **GameDataManager** comes in. It is designed to improve the productivity of game designers by providing necessary and convenient methods for data wrangling capability. 

## Core Functions 
1. Data Converting 
    Converts `.xlsx`&`.xlsm` to `.json` or `.csv`&`.tsv` 
2. Localization 
    Generate localization data with a combination of file name and given keycolumn or rownumber. 
3. Data Validation 
    Validate `.json` data with [JSONSchema](https://json-schema.org/)
4. [WIP]Data wangling & simulation 
    Provides simple API to wirte a Julia script to run the necessary simulations in a reproducable and maintainable manner.  

# Installation 
```julia
julia> Pkg.add("https://github.com/YongHee-Kim/GameDataManager.jl")
```

# Tutorials 

## 1 Project Setup 
We need create 'config.json' with basic informations about the project.
```json
{
    "name": "MyGame",
    "environment": {
        "xlsx": "./xlsx",
        "out": "./json",
        "localize": "./localization",
        "jsonschema": "./jsonschema"
    },
    ...
}
```

`name`: Name of the project.  
`environment`: Path informations. You can either use absolute path or relative path from `.config.json`.
- `xlsx`: Root path for `.xlsx`&`.xlsm`.
- `out`: Root path for converted data.
- `localize`: (optional)Root path for localization data.   
- `jsonschema`: (optional)Root path for JSONSchema files.

## 2 Convert Settings
Convert setting for each workbook. You need to specify each worksheet for coversion.  
```json
...,
{
    "xlsxtables": {
        "Items.xlsx": {
            "workSheets": [
                {
                    "name": "Equipment",
                    "out": "Items_Equipment.json",
                    "localize": {
                        "keycolumn": "/Key"
                    }
                },
                {
                    "name": "Consumable",
                    "out": "Items_Consumable.json", 
                    "kwargs": {
                        "start_line": 2
                    }
                }
            ]
        }
    }
}
```
`xlsxtables`: Convert setting per `.xlsx` file. 
- `name`: Name of the worksheet
- `out`: Name of the converted file. You can use any of `.json`, `.csv` or `.tsv`  
- `localize`: Specify key column for localizer to use. See [WIP] for more information.
- `kwargs`: Extra setting for data conversion. See [WIP] for more information.


## 3 Initialize
After writing down a `config.json` is complete, you can initialize project. Provide root directory for `config.json` to `init_project` function. 
```
using GameDataManager
init_project("../MyProject")
```
Alternatively, if working directory of the julia session is same as the root directory of a `config.json` you can just excute `init_project()` to initialize project. 


## 4 Converting
It's as simple as typing in file name. Use name of `.xlsx` file configured from a [config.json](./test/project/config.json).
```julia 
julia>xl("items")
    ┌ NOTE: exporting xlsx file... ⚒
    └ ----------------------------------------------
    『items』
    SAVE => .\json\Items_Equipment.json
    ⨽Localize => .\localization\Items_Equipment_eng.json
    SAVE => .\json\Items_Consumable.json
    [ DONE: export complete ☺
```
Or if you excute `xl()`, **GDM** will convert every file. 


### `config.json` Examples
- [GameDataManger Test](./test/project/config.json)

# [WIP]Localization

# [WIP]Advanced Converting Features 

# [WIP]JSONSchema validation 

