local perf = require("perf")

local util       = require("mkdoc.util")
local class_util = require("mkdoc.class_util")

local addSet         = util.addSet
local addSetKey      = util.addSetKey
local addSetKey2     = util.addSetKey2
local SortedListFromSet = util.SortedListFromSet
local SetFromList    = util.SetFromList
local ASSERT         = util.ASSERT
local PRINT          = util.PRINT

local lwtk         = require("lwtk")
local getMixinBase = lwtk.get.mixinBase

local getClassModuleName = class_util.getClassModuleName

local module_scanner = {}

function module_scanner.scan(depOrderedModuleNames, moduleInfos, modules)

    local function getClassModuleInfo(c)
        return moduleInfos[getClassModuleName(c)]
    end

    perf.start"moduleScan"

    local classInfos = {}      -- maps moduleName to moduleInfo for classes
    local classMixinInfos = {} -- maps moduleName to moduleInfo for classes and mixins
    local functionInfos = {}   -- maps moduleName to moduleInfo for functions
    local metaInfos = {}       -- maps moduleName to moduleInfo for metas
    local mixinInfos = {}      -- maps moduleName to moduleInfo for mixins
    local otherInfos = {}      -- maps moduleName to moduleInfo for other

    do
        local isReservedClassMemberName = SetFromList {
            "override",
            "static",
            "declared",
            "implement",
            "__index",
            "__newindex",
            "__name"
        }
        local function addMemberInfo(moduleInfo, memberName, member, class)
            -- for Mixins: class != module
            local moduleName = moduleInfo.moduleName
            local memberType = type(member)
            local isEntity = (memberType == "table" or memberType == "function")
            local memberInfo = moduleInfo.memberInfos2[memberName]
            local isDeclared = (not class and true) or (class.declared[memberName])
            if not memberInfo then
                memberInfo = {
                    moduleName   = moduleName,
                    memberName   = memberName,
                    isDeclared   = isDeclared,
                    isEntity     = isEntity,
                    isValue      = not isEntity,
                    memberType   = memberType,
                    realisations = {}
                }
                addSetKey(memberInfo.realisations, member, class and class:getClassPath() or true)
                if isEntity then
                    addSetKey2(moduleInfo.memberInfos2, memberName, member, memberInfo)
                else
                    addSetKey(moduleInfo.memberInfos2, memberName, memberInfo)
                end
                if memberType == "table" and not memberName:match("^__") and memberName ~= "implement"
                    and memberName ~= "override" and memberName ~= "declared" and memberName ~= "static"
                    and not getmetatable(member)
                then
                    for k, v in pairs(member) do
                        addMemberInfo(moduleInfo, memberName.."."..k, v, nil)
                    end
                end
            else
                assert(moduleInfo.isMixin)
                ASSERT(isDeclared == memberInfo.isDeclared, isDeclared, memberInfo.isDeclared, moduleName, memberName, memberInfo)
                if isEntity then
                    local backRef = moduleInfo.memberInfos2[member]
                    if backRef then
                        assert(backRef == memberInfo)
                    else
                        moduleInfo.memberInfos2[member] = memberInfo
                        addSetKey(memberInfo.realisations, member, class:getClassPath())
                        if isDeclared then
                            PRINT("##################", moduleName, memberName, modules[moduleName][memberName] ~= nil, SortedListFromSet(memberInfo.realisations))
                        end
                    end
                else
                    if not memberInfo.realisations[member] then
                        addSet(memberInfo.realisations, member)
                    end
                end
            end
        end
        local function visitSuperClasses(thisModuleName, thisModule, thisModuleInfo)
            local thisClassPath = class_util.getReverseClassPathString(thisModule)
            local super = thisModule:getSuperClass()
            local mixinVisited = false
            while super do
                local superInfo = getClassModuleInfo(super)
                addSet(superInfo.subClassPaths, thisClassPath)
                if not mixinVisited and superInfo.isMixin then
                    -- for Mixins: class != module, i.e. super != modules[superName]
                    if superInfo.mixinRealisations[super] then
                        mixinVisited = true
                    else
                        local list = class_util.getReverseClassPathList(super)
                        list.pathString = class_util.classPathListToString(list)
                        addSetKey2(superInfo.mixinRealisations, super, list.pathString, list)
                        for memberName, member in pairs(super) do
                            if not isReservedClassMemberName[memberName] then
                                addMemberInfo(superInfo, memberName, member, super)
                            end
                        end
                    end
                end
                super = super:getSuperClass()
            end
        end
        for _, thisModuleName in ipairs(depOrderedModuleNames) do
            local thisModule     = modules[thisModuleName]
            local thisModuleInfo = moduleInfos[thisModuleName]
            local thisModuleType = type(thisModule)

            local isClass = lwtk.isInstanceOf(thisModule, lwtk.Class)
            local isMixin = lwtk.isInstanceOf(thisModule, lwtk.Mixin)
            local isMeta  = lwtk.isInstanceOf(thisModule, lwtk.Meta)
            local isFunction = (thisModuleType == "function")
            if isClass then
                thisModuleInfo.isClass = true
                thisModuleInfo.memberFunctions = {}
                thisModuleInfo.inheritedMethods = {}
            elseif isMixin then
                thisModuleInfo.isMixin = true
                thisModuleInfo.memberFunctions = {}
                thisModuleInfo.inheritedMethods = {}
            elseif isMeta then
                thisModuleInfo.isMeta = true
                thisModuleInfo.memberFunctions = {}
            elseif isFunction then
                thisModuleInfo.isFunction = true
            end
            
            if isClass --[[or isMixin]] then
                thisModuleInfo.subClassPaths = {}
            elseif isMixin then
                thisModuleInfo.subClassPaths = {}
                thisModuleInfo.mixinRealisations = {}
            end
            if not thisModuleInfo.isInternal then
                if isClass then
                    addSetKey(classInfos,      thisModuleName, thisModuleInfo)
                    addSetKey(classMixinInfos, thisModuleName, thisModuleInfo)
                elseif isMixin then
                    addSetKey(mixinInfos,      thisModuleName, thisModuleInfo)
                    addSetKey(classMixinInfos, thisModuleName, thisModuleInfo)
                elseif isMeta then
                    addSetKey(metaInfos, thisModuleName, thisModuleInfo)
                elseif isFunction then
                    addSetKey(functionInfos, thisModuleName, thisModuleInfo)
                else
                    addSetKey(otherInfos, thisModuleName, thisModuleInfo)
                end
                if thisModuleType == "table" and not thisModuleInfo.isPackage then
                    local class = thisModuleInfo.isClass and thisModule
                    if class then
                        visitSuperClasses(thisModuleName, thisModule, thisModuleInfo)
                        local declared = class.declared
                        for memberName, member in pairs(thisModule) do
                            if not isReservedClassMemberName[memberName] then
                                addMemberInfo(thisModuleInfo, memberName, member, class)
                            end
                        end
                    elseif not isMixin then -- Mixin visited above in "visitSuperClasses"
                        for memberName, member in pairs(thisModule) do
                            addMemberInfo(thisModuleInfo, memberName, member, nil)
                        end
                    end
                end
            end
        end
    end
    perf.stop"moduleScan"

    return {
        classInfos      = classInfos,
        classMixinInfos = classMixinInfos,
        functionInfos   = functionInfos,
        metaInfos       = metaInfos,
        mixinInfos      = mixinInfos,
        otherInfos      = otherInfos,
    }
end

return module_scanner
