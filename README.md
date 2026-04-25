# GameDataManager.jl[KR](README_KR.md/#Introduction)
Easy and convenient toolkit for game designers to help manage data tables

# Introduction 
Game industries have seen lots of innovation and technological advancement, but the game design department has fallen behind. Artists and software engineers cannot rely on tools from 20 years ago — yet game designers can still use Excel 2003 with little or no trouble, because the tools game designers use have not changed much over the decades. Game designers spend most of their working hours wrestling with data. They have to architect the relationship between data and calculate possible outcomes of the interaction between players and data. And [GAAS](https://en.wikipedia.org/wiki/Games_as_a_service) has made managing data even more complicated. Spreadsheets are simply not enough to handle the complex data of a GAAS title. 
This is where **GameDataManager** comes in. It is designed to improve the productivity of game designers by providing necessary and convenient methods for data wrangling. 

## Core Functions 
1. Data Converting 
    Converts `.xlsx`&`.xlsm` to `.json` or `.csv`&`.tsv` 
2. Localization 
    Generate localization data with a combination of file name and given keycolumn or row number. 
3. Data Validation 
    Validate `.json` data with [JSONSchema](https://json-schema.org/)
4. [WIP] Data wrangling & simulation 
    Provides a simple API for writing Julia scripts to run simulations in a reproducible and maintainable manner.  

# Installation 
```julia
julia> Pkg.add("https://github.com/YongHee-Kim/GameDataManager.jl")
```

# Tutorials 

## 1 Project Setup 
Create a `config.json` with basic information about the project.
```json
{
    "name": "MyGame",
    "environment": {
        "xlsx": "./xlsx",
        "out": "./json",
        "localize": "./localization",
        "jsonschema": "./jsonschema"
    },
    "localization": {
        "baseLanguage": "eng"
    },
    ...
}
```

`name`: Name of the project.  
`environment`: Path information. You can use either an absolute path or a relative path from `config.json`.
- `xlsx`: Root path for `.xlsx`&`.xlsm`.
- `out`: Root path for converted data.
- `localize`: (optional) Root path for localization data.
- `jsonschema`: (optional) Root path for JSONSchema files.

`localization` *(optional)*: Top-level localization settings.
- `baseLanguage`: Language tag used as the suffix for generated localization files (e.g. `Items_Weapon_eng.json`). Defaults to `kr`.

## 2 Convert Settings
Convert settings per workbook. You must list every worksheet to convert.  
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
- `name`: Name of the worksheet.
- `out`: Name of the converted file. Supports `.json`, `.csv` and `.tsv`.
- `localize`: Enables the localizer for this worksheet. See [Localization](#localization).
- `kwargs`: Forwarded to [`XLSXasJSON.JSONWorksheet`](https://github.com/YongHee-Kim/XLSXasJSON.jl) — common keys are `start_line` (header row, default `1`) and `row_oriented` (default `true`; set `false` for column-oriented sheets).


## 3 Initialize
Once `config.json` is in place, initialize the project by passing the directory containing it to `init_project`.
```julia
using GameDataManager
init_project("../MyProject")
```
If the Julia session's working directory already contains `config.json`, calling `init_project()` with no arguments uses `pwd()`.


## 4 Converting
It's as simple as typing in the file name. Use the name of an `.xlsx` file configured from [config.json](./test/project/config.json).
```julia 
julia> xl("items")
    ┌ NOTE: exporting xlsx file... ⚒
    └ ----------------------------------------------
    『items』
    SAVE => .\json\Items_Equipment.json
    ⨽Localize => .\localization\Items_Equipment_eng.json
    SAVE => .\json\Items_Consumable.json
    [ DONE: export complete ☺
```
Or call `xl()` with no argument to convert every file in the config. By default, a single failing file does not abort the batch — pass `xl(; strict=true)` to rethrow the first error instead.

# Advanced Features 

## Localization 

The localizer extracts text from designer-flagged columns into a separate JSON file so it can be handed off to a localization service or runtime lookup table. The original sheet keeps a stable key in place of the text.

### Step 1 — Mark columns with `$`
Prefix any column name in the spreadsheet with `$` to opt it in. The prefix is preserved on the source-language column and stripped on the generated key column.

| Key    | $Description           |
| ------ | ---------------------- |
| WPN001 | A sturdy steel sword.  |
| WPN002 | An ornate silver bow.  |

### Step 2 — Configure `localize` per worksheet
```json
{
    "name": "Weapon",
    "out": "Items_Weapon.json",
    "localize": {
        "keycolumn": "/Key"
    }
}
```
- `keycolumn`: JSONPointer to the column whose values uniquely identify each row. Required if you want more robust keys; values must be non-empty and unique within the sheet.
- Omit `keycolumn` (or pass an empty string) to fall back to the row number.

### Step 3 — Run `xl()`
For the example above, two files are written:

`./json/Items_Weapon.json`
```json
[
  {
    "Key":          "WPN001",
    "Description":  "$gamedata.Items_Weapon.Description.WPN001",
    "$Description": "A sturdy steel sword."
  },
  {
    "Key":          "WPN002",
    "Description":  "$gamedata.Items_Weapon.Description.WPN002",
    "$Description": "An ornate silver bow."
  }
]
```

`./localization/Items_Weapon_eng.json`
```json
{
  "$gamedata.Items_Weapon.Description.WPN001": "A sturdy steel sword.",
  "$gamedata.Items_Weapon.Description.WPN002": "An ornate silver bow."
}
```

The generated key follows the pattern `$gamedata.<out_basename>.<column_path>.<keyvalue>` (or `<rownum>` when no `keycolumn` is configured). Characters that are unsafe for most localization services (`,`, `;`, `/`, etc.) are normalized to `.` or `_`.

The `$`-prefixed column is kept in the converted file as the source-of-truth string; downstream code reads the bare column (`Description`) and uses it as a lookup key against the per-language localization file. To translate, copy `Items_Weapon_eng.json` to `Items_Weapon_<lang>.json` and replace each value.

### Notes
- Duplicate generated keys raise an Error. This usually means two rows share the same `keycolumn` value - fix the data or pick a different key column.
- A missing `keycolumn` value raises an Error pointing at the offending row.
- Files are only rewritten when their content changes, so re-running `xl()` is cheap and your VCS only sees real edits.
