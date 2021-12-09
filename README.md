# GameDataManager.jl[KR](README_KR.md/#Introduction)
Easy and convenient toolkit for game designers

# Introduction 

# Tutorials 

## 1 Project Setup 
...
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

## 2 Export Settings
...
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

## 3 Exporting *.xlsx*
...
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


### `config.json` 예제
- [GameDataManger Test](./test/project/config.json)


# Additional Features 

## 1 Export kwargs  

## 
