# GameDataManager

## Introduction
**GameDataManager.jl** is a Julia package that provides functionality for managing game data.
 It allows users to load xlsx data and turn them into .json or '.csv' format to be read by game engine 


## Core Functions 
1. Data Converting 
Converts Excel files (.xlsx and .xlsm) into JSON (.json) or CSV (.csv and .tsv) formats. 
2. Localization 
Generates a unique localization key from filename, column, and row number, stores it with its value in a separate file, and replaces the original value with this key in the output file.
3. Data Validation 
validates JSON data using [JSONSchema](https://json-schema.org/). JSONSchema is a vocabulary that allows you to annotate and validate JSON documents.\
4. **(WIP)**Data wangling & simulation 
Provides a simple API to write a Julia script to run necessary simulations in a reproducible and maintainable manner.


## Requirements
* Julia v1.6 and above
* Linux, macOS or Windows.

## Installation

From a Julia session, run:

```julia
julia> using Pkg

julia> Pkg.add("https://github.com/YongHee-Kim/GameDataManager.jl")
```


## License
The source code for the package **GameDataManager.jl** is licensed under
the [MIT License](https://github.com/YongHee-Kim/GameDataManager.jl/blob/main/LICENSE).

## Getting Help
Open a new [issue](https://github.com/YongHee-Kim/GameDataManager.jl/issues) for bug reports or feature requests

## Contributing

Contributions are always welcome!

To contribute, fork the project on [GitHub](https://github.com/YongHee-Kim/GameDataManager.jl)
and send a Pull Request.