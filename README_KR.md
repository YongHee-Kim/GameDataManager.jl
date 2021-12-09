# GameDataManager.jl
게임 기획자를 위한 데이터 관리 패키지입니다. 

# 소개 
지난 20여년간 게임개발은 언리얼 엔진, 유니티 엔진등의 상용 엔진과 어도비와 오토데스크등의 그래픽 디자인 소프트웨어, 그리고 오픈소스를 등에 업은 프로그래밍 언어와 라이브러리의 발전과 함께 기술적으로 눈부신 성장을 이룩했습니다. 
그러나 게임 기획 부분은 상대적으로 발전이 더딘 일반 사무용 소프트웨어인 Excel을 사용하며 그렇기 때문에 나날이 생산성이 향상되는 프로그래밍과 그래픽 디자이너에 비해 게임 기획자의 생산성은 정체 상태에 있는게 사실입니다. 시스템 기획자는 업무시간의 대부분을 게임 데이터를 관리하며 이 데이터간의 상호작용을 책정하고, 상호 작용의 결과를 예측하는 일을 하는데 사용하는데 Excel만으로는 날이 갈수록 복잡해지는 부분유료화 게임의 데이터를 관리하는데에 너무나 많은 노동력을 사용하게 되고, 오류가 생기거나 기획의도에 맞지 않는 데이터를 생산할 가능성도 높아집니다. 
**GameDataManger**는 기획자가 게임 데이터의 기획과 데이터의 상호작용 그 자체를 책정하는데에 집중할 수 있도록, 데이터의 입력과 오류 추적에 들이는 시간을 최소화 하는 것을 목표로 개발되었습니다.
  
> 이 프로그램은 [Devsisters™](https://www.devsisters.com)에서 개발한 동명의 [GameDataManger](https://github.com/devsisters/GameDataManager.jl)를 기반으로 하고 있습니다. GameDataManger의 개발과 오픈소스화를 지원해주신 [Devsisters™](https://www.devsisters.com)에 감사드립니다. 

## 주요 기능
1. 데이터 변환  
    `.xlsx`&`.xlsm`데이터를 `.json` 혹은 `.csv`, `.tsv`로 변환합니다 
2. 현지화   
    파일명과 데이터 컬럼명, 그리고 주어진 키값을 조합하여 현지화Key를 자동으로 배정하고 번역에 필요한 `"Key": Value` 데이터를 생성합니다. 
3. 오류 검사   
    변환하는 데이터별로 [JSONSchema](https://json-schema.org/)를 작성하면 오류 검사를 수행합니다. (데이터 포맷이 `.json`일 경우만 사용 가능) 
4. [WIP]데이터 검색 및 계산작업  
    Julia Script를 작성하여 여러 파일의 데이터를 빠르게 호출하고 게임 기획에 필요한 계산 작업을 수행할 수 있습니다.  

# 설치 
[공식 메뉴얼을](http://juliakorea.github.io/ko/latest/manual/getting-started/) 참고하여 줄리아를 설치합니다.
Julia REPL에서 `]`을 눌러 [패키지 모드](https://docs.julialang.org/en/v1/stdlib/Pkg/)로 진입한 후 다음과 같이 입력하여 **GameDataManager**를 설치합니다
``` julia 
pkg>add https://github.com/YongHee-Kim/GameDataManager.jl
```

# 튜토리얼 

## 프로젝트 설정
**GameDataManager**를 사용학 위해서는 'config.json' 작성이 필요합니다. 
작성 예제는 다음과 같습니다.
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
`name`: 프로젝트의 이름입니다.  
`environment`: 데이터 원본 경로, 추출된 데이터의 경로등을 기입합니다. 
- `xlsx`: 엑셀 파일의 경로
- `out`: 변환된 데이터 파일의 경로   
- `localize`: 현지화 데이터의 경로   
- `jsonschema`: JSONSchema의 경로. 파일명이 out파일 동일할 경우 Schema검사를 수행합니다. 

      
## 파일 변환 설정
프로젝트 `name`과 `environment` 작성이 끝나면 이어서 변환할 엑셀 파일과 시트 정보를 작성합니다. 
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
`xlsxtables`: 각각의 xlsx 파일에 대한 시트별 추출 설정입니다.
- `name`: 엑셀 시트의 이름입니다.  
- `out`: 추출할 파일명입니다. `.json`, `.csv`, `.tsv`를 사용할 수 있습니다.  
- `localize`: 현지화 관련 설정입니다. 값이 없으면 현지화를 하지 않습니다. 자세한 사용법은 [링크]를 참고해 주세요  
- `kwargs`: 데이터 추출 방식에 대한 추가 설정입니다. 자세한 사용법은 [링크]를 참고해 주세요

### `config.json` 예제
- [GameDataManger Test](./test/project/config.json)


## 프로젝트 초기화하기
`config.json` 작성이 끝났으니 이제 프로젝트를 초기화할 수 있습니다.  
"config.json" 파일이 있는 경로를 복사하여 `init_project`에 붙여넣으면 됩니다.
```
using GameDataManager
init_project("../MyProject")
```

!!! note
> Julia REPL의 현재 경로가 `config.json`이 있는 폴더인 상태에서 `using GameDataManager`를 호출하면 자동으로 프로젝트를 초기화합니다.  
> [메뉴얼](https://docs.julialang.org/en/v1/manual/getting-started/)을 참고하여 startup.jl에서 프로젝트 경로로 이동하도록 설정하거나, VSCode WorkSpace 기본 경로에 config.json을 두면 편리합니다. 

## 파일 변환하기 
[config.json](./test/project/config.json)의 `xlsxtables`에서 기입한 엑셀 파일명만 입력하면 데이터를 추출할 수 있습니다.
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
혹은 아무런 인자 없이 `xl()`만 입력하면 `confing.json#/xlsxtables`에 명시된 모든 데이터를 추출합니다. 


# 추가 기능 

## Export kwargs  

## 


# 