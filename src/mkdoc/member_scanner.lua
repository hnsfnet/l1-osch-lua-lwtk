local perf = require("perf")

local util       = require("mkdoc.util")
local class_util = require("mkdoc.class_util")

local append     = util.append
local addSet     = util.addSet
local addSetKey  = util.addSetKey
local addSetKey2 = util.addSetKey2

local lwtk         = require("lwtk")
local getMixinBase = lwtk.get.mixinBase

local getClassModuleName = class_util.getClassModuleName

local member_scanner = {}

function member_scanner.scan(depOrderedModuleNames, moduleInfos, modules, classInfos, reverseLookup)

    perf.start"memberScan"

    do
        local function addMemberInfo(moduleInfo, memberName, member, class)
            -- for Mixins: class != module
            local moduleName = moduleInfo.moduleName
            local memberType = type(member)
            if memberType == "table" or memberType == "function" then
                local memberInfo = moduleInfo.memberInfos[memberName]
                if not memberInfo then
                    memberInfo = {
                        moduleName = moduleName,
                        isEntity = true,
                        memberName = memberName,
                        memberType = memberType,
                        member = member,
                        referringInfos = {},
                    }
                    if memberType == "function" then
                        if moduleInfo.memberFunctions then
                            addSetKey2(moduleInfo.memberFunctions, memberName, member, memberInfo)
                        end
                    end
                    local existingInfo = reverseLookup[member]
                    if not existingInfo then
                        reverseLookup[member] = memberInfo
                    else
                        if existingInfo.moduleName == moduleName then
                            error(require"inspect"{memberName, moduleName, existingInfo})
                        end
                        addSetKey(existingInfo.referringInfos, moduleName, memberInfo)
                        memberInfo.originalMemberInfo = existingInfo
                    end
                    addSetKey2(moduleInfo.memberInfos, memberName, member, memberInfo)
            
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
                end
            else
                local memberInfo = moduleInfo.memberInfos[memberName]
                if not memberInfo then
                    memberInfo = {
                        moduleName = moduleName,
                        isValue = true,
                        memberName = memberName,
                        memberType = memberType,
                        member = member
                    }
                    addSetKey(moduleInfo.memberInfos, memberName, memberInfo)
                else
                    assert(moduleInfo.isMixin)
                    if memberType ~= memberInfo.memberType or member ~= memberInfo.member then
                        error(require"inspect"{moduleName, memberName, memberType, memberInfo.memberType, memberInfo})
                    end
                end
            end
        end
        local function addToInheritedMethods(inheritedMethods, memberName, class)
            local i = 0
            local s = class:getSuperClass() 
            while s do
                i = i + 1
                local fromList = inheritedMethods[i]
                if not fromList then
                    fromList = { moduleName = getClassModuleName(s), isMixin = getMixinBase[s] }
                    inheritedMethods[i] = fromList
                end
                if s.declared[memberName] then
                    append(fromList, { moduleName = getClassModuleName(s),
                                       memberName = memberName })
                    break
                end
                s = s:getSuperClass()
            end
        end
        for _, thisModuleName in ipairs(depOrderedModuleNames) do
            local thisModule     = modules[thisModuleName]
            local thisModuleInfo = moduleInfos[thisModuleName]
            local thisModuleType = type(thisModule)

            if thisModuleType == "table" and not thisModuleInfo.isPackage then
                local class = thisModuleInfo.isClass and thisModule
                if class then
                    local declared = class.declared
                    local inheritedMethods = thisModuleInfo.inheritedMethods
                    for memberName, member in pairs(thisModule) do
                        if declared[memberName] then
                            addMemberInfo(thisModuleInfo, memberName, member, class)
                        else
                            if type(member) == "function" and rawget(class.__index, memberName) then
                                addToInheritedMethods(inheritedMethods, memberName, class)
                            end
                        end
                    end
                else
                    for memberName, member in pairs(thisModule) do
                        addMemberInfo(thisModuleInfo, memberName, member, nil)
                    end
                end
            end

        end
    end
    do
        for _, thisModuleInfo in ipairs(classInfos) do
            local thisModuleName = thisModuleInfo.moduleName
            local thisModule     = modules[thisModuleName]
            for k, v in pairs(thisModule.__index) do
                local memberInfo = thisModuleInfo.memberInfos[k]
                if not memberInfo then
    --                error(require"inspect"{thisModuleName, k})
                end
                if type(v) == "function" then
                    if thisModule.declared[k] then
                        memberInfo.overrideList = class_util.getOverrideList(thisModule, k) -- TODO
                    end
                end
            end
        end
    end
    perf.stop"memberScan"
end

return member_scanner
