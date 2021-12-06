module MyGame
    using GameDataManager

    export foo, bar 

    function foo()
        println("Hello World, I will return a XLSXTable")
        return GameDataManager.loadtable("items")
    end

    function bar(what)
        
    end
end