local path = require("path")     -- https://luarocks.org/modules/xavier-wang/lpath
local fs   = require("path.fs")  -- https://luarocks.org/modules/xavier-wang/lpath
local perf = require("perf")

local util = require("mkdoc.util")

local append     = util.append
local addSetKey  = util.addSetKey
local addSetKey2 = util.addSetKey2

local module_loader = {}

function module_loader.loadModules()

    perf.start"directoryScan"

    local moduleFileNames = {}
    for n, t in fs.scandir("lwtk") do
        if t == "file" and path.isfile(n) then
            moduleFileNames[#moduleFileNames + 1] = n
        end
    end

    perf.stop"directoryScan"

    ---------------------------------------------------------------------------------------------------------------------------

    perf.start"requireModules"

    local depOrderedModuleNames = {}
    local moduleInfos = {}   -- maps moduleName and module to moduleInfo
    local modules = {}       -- maps moduleName to module
    local packageInfos = {}  -- maps moduleName to moduleInfo for packages
    local reverseLookup = {} -- maps lwtkObject to infoObject

    ---------------------------------------------------------------------------------------------------------------------------

    local original_require = _G.require
    do
        local isPackage = {}
        local moduleNames = {}
        local toModuleFileName = {}
        
        for i, moduleFileName in ipairs(moduleFileNames) do
            local moduleName = moduleFileName:gsub("^(.*)%.lua$", "%1"):gsub("/", "."):gsub("%.init$", "")
            isPackage[moduleName] =  moduleFileName:match("%/init%.lua$") and true or false
            moduleNames[i] = moduleName
            toModuleFileName[moduleName] = moduleFileName
        end

        function _G.require(moduleName)
            local module = original_require(moduleName)
            if not moduleName:match("^lwtk") then
                return module
            end
            if not reverseLookup[module] then
                --printf("Loading %s\n", moduleName, )
                append(depOrderedModuleNames, moduleName)
                local isP = isPackage[moduleName]
                local moduleType = type(module)
                local packageName = moduleName:gsub("^(.*)%.[^.]+$", "%1")
                local isInternal =  moduleName:match("^lwtk%.internal") and true or false
                local moduleInfo = {
                    moduleName = moduleName,
                    docFileName = toModuleFileName[moduleName]:gsub("%.lua", ".md"),
                    packageName = packageName,
                    isInternal = isInternal,
                    isModule = true,
                    isPackage = isP,
                    moduleType = moduleType,
                    memberInfos = {},   -- maps memberName and member to memberInfo
                    memberInfos2 = {},
                    referringInfos = {}
                }
                reverseLookup[module] = moduleInfo
                addSetKey2(moduleInfos, moduleName, module, moduleInfo)
                if isP then
                    addSetKey(packageInfos, moduleName, moduleInfo)
                end
                modules[moduleName] = module
            end
            return module
        end
        
        for _, moduleName in ipairs(moduleNames) do
            --printf("Requiring %s\n", moduleName)
            require(moduleName)
        end
    end
    _G.require = original_require
        
    perf.stop"requireModules"

    return {
        moduleFileNames      = moduleFileNames,
        depOrderedModuleNames = depOrderedModuleNames,
        moduleInfos          = moduleInfos,
        modules              = modules,
        packageInfos         = packageInfos,
        reverseLookup        = reverseLookup,
    }
end

return module_loader
