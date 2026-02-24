local path = require("path")     -- https://luarocks.org/modules/xavier-wang/lpath
local perf = require("perf")

local lpeg = require "lpeglabel" -- https://luarocks.org/modules/sergio-medeiros/lpeglabel
lpeg.locale(lpeg)
local P, S = lpeg.P, lpeg.S
local C = lpeg.C
local alnum = lpeg.alnum

local util       = require("mkdoc.util")
local class_util = require("mkdoc.class_util")

local format = string.format

local fprintf    = util.fprintf
local addSetKey  = util.addSetKey

local lwtk = require("lwtk")

local output = {}

---------------------------------------------------------------------------------------------------------------------------

local function sortMembers(members)
    if members then
        table.sort(members, function(a,b) 
            local an, bn = a.memberName, b.memberName
            local am, bm = an:match("^_"), bn:match("^_")
            if (am and bm) or (not am and not bm) then
                return an < bn 
            else
                return not am
            end
        end)
    end
end

local function sortInheritedMembers(superClassList)
    if superClassList then
        for i = #superClassList, 1, -1 do
            local methods = superClassList[i]
            if #methods > 0 then
                sortMembers(methods)
            else
                table.remove(superClassList, i)
            end
        end
    end
end

local function sortModules(modules, deep)
    table.sort(modules, function(a,b) return a.moduleName < b.moduleName end)
    if deep then
        for _, module in ipairs(modules) do
            if module.methods then
                sortMembers(module.methods)
            end
            if module.functions then
                sortMembers(module.functions)
            end
            if module.inheritedMethods then
                sortInheritedMembers(module.inheritedMethods)
            end
        end
    end
end

local function newSubstLinks(genDirPrefix)

    local linkFormat = "[%s]("..genDirPrefix.."%s.md)"
    local linkPattern = (     C(  (S'["' * P"lwtk.")
                                + (-(S'["' * P"lwtk.") * -P"lwtk." * P(1))^1
                               )
                            + ((P"lwtk." * (alnum + P".")^1) / 
                                function(m)
                                    if lwtk.tryrequire(m) then
                                        return format(linkFormat, m, m:gsub("%.", "/"))
                                    else
                                        return m
                                    end
                                end 
                              )
                        )^0 / function(...) return table.concat { ... } end

    return function(docString)
        return lpeg.match(linkPattern, docString)
    end
end

---------------------------------------------------------------------------------------------------------------------------

function output.generate(moduleInfos, modules, packageInfos,
                         classInfos, mixinInfos, metaInfos, functionInfos, otherInfos)

    sortModules(moduleInfos, true)
    sortModules(packageInfos)

    ---------------------------------------------------------------------------------------------------------------------------
    perf.start"output"

    do
        local substLinks = newSubstLinks("")
        
        local sections = {
            { "Classes",   classInfos },
            { "Mixins",    mixinInfos },
            { "Metas",     metaInfos },
            { "Functions", functionInfos },
            { "Other",     otherInfos }
        }
        for _, s in ipairs(sections) do
            sortModules(s[2])
            for _, info in ipairs(s[2]) do
                if not info.isPackage then
                    local packInfo = moduleInfos[info.packageName]
                    local infos = packInfo[s[2]]
                    if not infos then
                        infos = {}
                        packInfo[s[2]] = infos
                    end
                    addSetKey(infos, info.moduleName, info)
                end
            end
        end
        
        local outName = "../doc/gen/modules.md"
        local out = io.open(outName, "w")
        do
            local function pr(...)
                fprintf(out, ...)
            end
            pr("# Module Index\n\n")
            for _, p in ipairs(packageInfos) do
                if not p.isInternal then
                    pr("   * [%s](#%s)", p.moduleName, p.moduleName:gsub("%.",""))
                    if p.shortDoc then
                        pr(" - %s", substLinks(p.shortDoc))
                    end
                    pr("\n")
                end
            end    
            for _, p in ipairs(packageInfos) do
                local packageName = p.moduleName
                if not p.isInternal then
                    pr("\n## %s\n", packageName)
                    pr("\n")
                    for _, s in ipairs(sections) do
                        local infos = p[s[2]]
                        if infos then
                            pr("### %s\n", s[1])
                            for _, m in ipairs(infos) do
                                if m.packageName == packageName then
                                    local b = m.isClass and "**" or ""
                                    pr("   * %s[%s](%s)%s", b, m.moduleName, m.docFileName, b)
                                    if m.shortDoc then
                                        pr(" - %s", substLinks(m.shortDoc))
                                    end
                                    pr("\n")
                                end
                            end
                        end
                    end
                end
            end
        end
        out:close()
    end
    ---------------------------------------------------------------------------------------------------------------------------
    do
        for _, m in ipairs(moduleInfos) do
            if not m.isInternal then
                local genDirPrefix = string.rep("../", #m.moduleName:gsub("[^.]*(%.?)[^.]*", "%1"))
                local substLinks = newSubstLinks(genDirPrefix)
                local shortModuleName = m.moduleName:gsub("^lwtk%.", "")
                local out = assert(io.open(path("../doc/gen", m.docFileName), "w"))
                do
                    local function pr(...)
                        fprintf(out, ...)
                    end
                    local function prind(n)
                        for i = 1, n do
                            out:write(" ")
                        end
                    end
                    local module = modules[m.moduleName]
                    local tp
                    if type(module) == "function" then
                        tp = "Function "
                    elseif m.isClass then
                        tp = "Class "
                    elseif m.isMixin then
                        tp = "Mixin "
                    elseif m.isMeta then
                        tp = "Meta "
                    elseif type(module) == "table" then
                        tp = "Table "
                    elseif type(module) == "number" or type(module) == "string" then
                        tp = ""
                    else 
                        error(m.moduleName)
                    end
                    pr("# %s%s\n\n", tp, m.moduleName)
                    if m.moduleType == "function" then
                        local argListString = m.argListString
                        if m.isMethod and argListString then
                            argListString = "self, "..argListString
                        end
                        pr("   * **`%s(%s)`**\n\n", shortModuleName,
                                                     argListString or "?")
                        if m.fullDoc then
                            pr(class_util.indent(5, substLinks(m.fullDoc)))
                        end
                    else
                        if m.fullDoc then
                            pr("%s\n", substLinks(m.fullDoc))
                        end
                    end
                    ------------------------------------------------------------------------
                    local contentsTitlePrinted = false
                    local function assureContentsTitle()
                        if not contentsTitlePrinted then
                            pr("\n")
                            pr("## Contents\n\n")
                            contentsTitlePrinted = true
                        end
                    end
                    local classPathList
                    if m.isClass then
                        classPathList = class_util.getClassPathList(module)
                        if #classPathList > 1 then
                            assureContentsTitle()
                            pr("   * [Inheritance](#inheritance)\n")
                        end
                    elseif m.isMixin then
                        if #m.mixinRealisations > 0 then
                            assureContentsTitle()
                            pr("   * [Inheritance](#inheritance)\n")
                        end
                    end
                    local hasNewOk, hasNew = pcall(function() return module["new"] end)
                    hasNew = hasNewOk and hasNew
                    local hasConstructor = (m.isMeta or m.isClass) and hasNew
                    if hasConstructor then
                        assureContentsTitle()
                        pr("   * [Constructor](#constructor)\n")
                    end
                    local methodFunctionSections = {
                        { "Methods",   "methods",   m.methods   },
                        { "Functions", "functions", m.functions }
                    }
                    for _, section in pairs(methodFunctionSections) do
                        if section[3] and #section[3] > 0 then
                            assureContentsTitle()
                            pr("   * [%s](#%s)\n", section[1], section[2])
                            for _, meth in ipairs(section[3]) do
                                pr("      * [%s()](#.%s)", meth.memberName, meth.memberName)
                                if meth.shortDoc then
                                    pr(" - %s", meth.shortDoc)
                                else
                                    local orig = meth.originalMemberInfo
                                    if orig and orig.shortDoc then
                                        pr(" - %s", orig.shortDoc)
                                    end
                                end
                                pr("\n")
                            end
                        end
                    end
                    if m.inheritedMethods and #m.inheritedMethods > 0 then
                        assureContentsTitle()
                        pr("   * [Inherited Methods](#inherited-methods)\n")
                    end
                    if (m.isClass or m.isMixin) and #m.subClassPaths > 0 then
                        assureContentsTitle()
                        pr("   * [Subclasses](#subclasses)\n")
                    end
                    ------------------------------------------------------------------------
                    pr("\n")
                    if m.isClass and #classPathList > 1 then
                        pr("\n## Inheritance\n")
                        --pr("   * Super class path:\n", #classPathList>2 and "es" or "")
                        pr("   * ")
                        for i = #classPathList, 1, -1 do
                            pr(" / ")
                            local c = classPathList[i]
                            local cname = c.moduleName
                            local b = c.isMixin and "" or "**"
                            if cname == m.moduleName then
                                pr("_%s`%s`%s_", b,
                                               cname:gsub("^lwtk%.",""), 
                                               b)
                            else
                                pr("%s[%s](%s%s.md#inheritance)%s", 
                                                    b,
                                                    cname:gsub("^lwtk%.",""), 
                                                    genDirPrefix, 
                                                    cname:gsub("%.","/"),
                                                    b)
                            end
                        end
                        pr("\n")
                    elseif m.isMixin and #m.mixinRealisations > 0 then
                        pr("\n## Inheritance\n")
                        local function prSup(indn, sup, top)
                            for _, s0 in ipairs(sup) do
                                local s = s0
                                prind(indn) pr("   * ")
                                if top then
                                    pr("/ ")
                                end
                                while true do
                                    if s ~= s0 then
                                        pr(" / ")
                                    end
                                    local sname = s.moduleName
                                    local b = s.isMixin and "" or "**"
                                    if sname == m.moduleName then
                                        pr("_%s`%s`%s_", b, sname:gsub("^lwtk%.",""), 
                                                     b)
                                    else
                                        pr("%s[%s](%s%s.md#inheritance)%s", b, sname:gsub("^lwtk%.",""), 
                                                                               genDirPrefix,
                                                                               sname:gsub("%.","/"), 
                                                                               b)
                                    end
                                    if #s ~= 1 then
                                        break
                                    end
                                    s = s[1]
                                end
                                if #s > 1 then
                                    pr(" /\n")
                                    prSup(indn + 5, s)
                                else
                                    pr("\n")
                                end
                            end
                        end
                        prSup(0, m.mixinSupers, true)
                    end
                    if hasConstructor then
                        pr("\n## Constructor\n")
                        if m.isMeta or module.declared["new"] then
                            local newInfo = assert(m.memberInfos["new"])
                            local argListString = newInfo.argListString
                            pr("   * <span id=%q>**`%s(%s)`**</span>\n\n", ".new", shortModuleName,
                                                                                   argListString or "?")
                            if newInfo.fullDoc then
                                pr(class_util.indent(5, newInfo.fullDoc))
                                pr("\n")
                            end
                            local overrideList = m.isClass and class_util.getOverrideList(module, "new")
                            if overrideList then
                                local indent = "     "
                                --pr("%s   * Overrides:\n", indent)
                                for i, ov in ipairs(overrideList) do
                                    local b = ov.isMixin and "" or "**"
                                    pr("%s   * %s: %s[%s()](%s%s.md#constructor)%s\n", string.rep(indent, i), 
                                                               ov.overrideText,
                                                               b,
                                                               ov.moduleName:gsub("^lwtk%.", ""),
                                                               genDirPrefix,
                                                               ov.moduleName:gsub("%.", "/"),
                                                               b)
                                end
                                pr("\n")
                            end
                        else
                            local inheritedFrom = class_util.findDeclaratingSuperClass(module, "new")
                            local inheritedFromInfo = assert(moduleInfos[inheritedFrom])
                            local newInfo = assert(inheritedFromInfo.memberInfos["new"])
                            local argListString = newInfo.argListString
                            pr("   * <span id=%q>**`%s(%s)`**</span>\n\n", ".new", shortModuleName,
                                                                                   argListString or "?")
                            local b = inheritedFromInfo.isClass and "**" or ""
                            pr("        * Inherited from: %s[%s()](%s%s.md#constructor)%s\n", b, inheritedFrom.__name:gsub("^lwtk%.",""),
                                                                                    genDirPrefix,
                                                                                    inheritedFrom.__name:gsub("%.", "/"), 
                                                                                    b)
                        end
                        pr("\n")
                    end
                    for _, section in pairs(methodFunctionSections) do
                        if section[3] and #section[3] > 0 then
                            pr("\n## %s\n", section[1])
                            for _, meth in ipairs(section[3]) do
                                --print("#####################", require"inspect"{meth.methodName, moduleDoc.membersDoc})
                                local argListString = meth.argListString
                                local isMethod = meth.isMethod
                                local original = meth.originalMemberInfo
                                if not argListString and original then
                                    argListString = original.argListString
                                    isMethod = original.isMethod
                                end
                                local sep = isMethod and ":" or "."
                                pr("   * <span id=%q>**`%s%s%s(%s)`**</span>\n\n", "."..meth.memberName, shortModuleName, sep, meth.memberName,
                                                                                                         argListString or "?")
                                if meth.fullDoc then
                                    pr(class_util.indent(5, meth.fullDoc))
                                    pr("\n")
                                elseif original and original.fullDoc then
                                    pr(class_util.indent(5, original.fullDoc))
                                    pr("\n")
                                end 
                                if original then
                                    if original.isModule then
                                        pr("        * Implementation: [%s()](%s%s.md)\n", 
                                                                            original.moduleName,
                                                                            genDirPrefix,
                                                                            original.moduleName:gsub("%.","/"))
                                    else
                                        pr("        * Implementation: [%s:%s()](%s%s.md#%s)\n", 
                                                                            original.moduleName:gsub("^lwtk%.",""),
                                                                            original.memberName,
                                                                            genDirPrefix,
                                                                            original.moduleName:gsub("%.","/"),
                                                                            original.memberName)
                                    end
                                end
                                if meth.overrideList then
                                    local indent = "     "
                                    for i, ov in ipairs(meth.overrideList) do
                                        pr("%s   * %s: [%s:%s()](%s%s.md#.%s)\n", string.rep(indent, i), 
                                                                   ov.overrideText,
                                                                   ov.moduleName:gsub("^lwtk%.", ""),
                                                                   meth.memberName,
                                                                   genDirPrefix,
                                                                   ov.moduleName:gsub("%.", "/"),
                                                                   meth.memberName)
                                    end
                                    pr("\n")
                                end
                                pr("\n")
                            end
                        end
                    end
                    if m.inheritedMethods and #m.inheritedMethods > 0 then
                        pr("\n## Inherited Methods\n")
                        for _, fromList in ipairs(m.inheritedMethods) do
                            local b = fromList.isMixin and "" or "**"
                            local fromFile = format("%s%s.md", genDirPrefix, fromList.moduleName:gsub("%.", "/"))
                            pr("   * %s[%s](%s)%s:\n", b, fromList.moduleName:gsub("^lwtk%.",""), fromFile, b)
                            pr("      * ")
                            for i, fr in ipairs(fromList) do
                                if i > 1 then pr(", ") end
                                pr("[%s()](%s#.%s)", fr.memberName, fromFile, fr.memberName)
                            end
                            pr("\n")
                        end
                    end
                    if (m.isClass or m.isMixin) and #m.subClassPaths > 0 then
                        pr("\n## Subclasses\n")
                            --pr("   * Sub class path%s:\n", #m.subClassTree[1] > 1 and "s" or "")
                        local function prSub(indn, sub, top)
                            for _, s0 in ipairs(sub) do
                                local s = s0
                                prind(indn) pr("   * ")
                                if top then
                                    pr("/ ")
                                end
                                while true do
                                    if s ~= s0 then
                                        pr(" / ")
                                    end
                                    local sname = s.moduleName
                                    local sinfo = moduleInfos[sname]
                                    local b = sinfo.isMixin and "" or "**"
                                    local hasSubclass = sinfo.subClassPaths and #sinfo.subClassPaths > 0
                                    if m.moduleName == sname then
                                        pr("_%s`%s`%s_", b, sname:gsub("^lwtk%.",""),
                                                       b)
                                    else
                                        pr("%s[%s](%s%s.md#%s)%s", b, sname:gsub("^lwtk%.",""),
                                                                    genDirPrefix,
                                                                    sname:gsub("%.","/"), 
                                                                    hasSubclass and "subclasses" or "inheritance",
                                                                    b)
                                    end
                                    if #s ~= 1 then
                                        break
                                    end
                                    s = s[1]
                                end
                                if #s > 1 then
                                    pr(" /\n")
                                    prSub(indn + 5, s)
                                else
                                    pr("\n")
                                end
                            end
                        end
                        prSub(0, m.subClassTree, true)
                        --pr("%s", pprint.pformat(m.subClassTree))
                        pr("\n")
                    end
                end
                out:close()
            end
        end
    end
    perf.stop"output"
end

return output
