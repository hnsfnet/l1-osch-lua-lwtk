local path   = require("path")     -- https://luarocks.org/modules/xavier-wang/lpath
local fs     = require("path.fs")  -- https://luarocks.org/modules/xavier-wang/lpath
local perf   = require("perf")

local util       = require("mkdoc.util")
local class_util = require("mkdoc.class_util")

local addSetKey  = util.addSetKey

local pprint   = require("mkdoc.pprint")            -- modified version from: https://github.com/jagt/pprint.lua
local parser   = require("mkdoc.lua-parser.parser") -- modified version from: https://github.com/andremm/lua-parser
local comments = require("mkdoc.comments")

local re = require("relabel")  -- https://luarocks.org/modules/sergio-medeiros/lpeglabel

local lwtk = require("lwtk")

local source_parser = {}

function source_parser.parseAllModules(TRACE, depOrderedModuleNames, moduleInfos, modules,
                                       classMixinInfos, mixinInfos)

    perf.start"totalparse"

    local parseModule
    do
        local function processExp(env, e)
            if e.tag == "Call" then
                local func = processExp(env, e[1])
                local args = {}
                for i = 2, #e do
                    args[i-1] = processExp(env, e[i])
                end
                if func == require then
                    --local rslt = require(args[1])
                    local rslt = moduleInfos[args[1]]
                    if not rslt then    
                        rslt = require(args[1])
                    end
                    return rslt
                elseif func == lwtk.newClass then
                    --[[
                    local class = lwtk.tryrequire(args[1])
                    if class then
                        if classDocs[class] ~= nil then
                            lwtk.errorf("already found: lwtk.newClass(%q)", class.__name)
                        end
                        classDocs[class] = false
                        return class, NEW_CLASS
                    else
                        print("ignoring class", args[1])
                    end ]]
                end
            elseif e.tag == "Index" then
                local e1 = processExp(env, e[1])
                local e2 = processExp(env, e[2])
                if e1 then
                    if moduleInfos[e1] == true then
                        return e1.memberInfos[e2]
                    else
                        return e1[e2]
                    end
                end
            elseif e.tag == "String" then
                return e[1]
            elseif e.tag == "Op" then
                local op = e[1]
                if op == "concat" then
                    local e1 = processExp(env, e[2])
                    local e2 = processExp(env, e[3])
                    return e1..e2
                elseif op == "or" then
                    local e1 = processExp(env, e[2])
                    local e2 = processExp(env, e[3])
                    return e1 or e2
                elseif op == "div" then
                elseif op == "not" then
                elseif op == "and" then
                else
                    error(op)
                end
            elseif e.tag == "Id" then
                return env[e[1]]
            elseif e.tag == "Number" then
                return e[1]
            elseif e.tag == "Table" then
            elseif e.tag == "Function" then
            elseif e.tag == "Boolean" then
                return e[1]
            elseif e.tag == "Invoke" then
            elseif e.tag == "Paren" then
            elseif e.tag == "Nil" then
                return nil
            else
                error(require"inspect"({tag = e.tag, pos = e.pos, end_pos = e.end_pos}))
            end
        end
        
        local moduleOutDirs = {}
        
        function parseModule(thisModuleName, thisModule, thisModuleInfo)
            local moduleFileNameStem = thisModuleName:gsub("%.", "/")
            if thisModuleInfo.isPackage then
                moduleFileNameStem = moduleFileNameStem.."/init"
            end
            local moduleFileName = moduleFileNameStem..".lua"
            local traceFileName = path("../doc/gen", moduleFileNameStem..".trace")
            local outDir  = path.parent(traceFileName)
            if not moduleOutDirs[outDir] then
                moduleOutDirs[outDir] = true
                fs.makedirs(outDir)
            end
     
            local traceOut = TRACE and io.open(traceFileName, "w")
            do
                print("Processing", moduleFileName)
                local function trace(...)
                    if traceOut then
                        local n = select("#", ...)
                        for i = 1, n do
                            traceOut:write(tostring(select(i, ...)))
                            if i < n then
                                traceOut:write("\t")
                            end
                        end
                        traceOut:write("\n")
                    end
                end
        
                local file = assert(io.open(moduleFileName, "r"), moduleFileName)
                local content = file:read("*a")
                file:close()
        
                comments.init(content, trace)
                perf.start"parse"
                local ast, err = parser.parse(content, moduleFileName, comments)
                perf.stop"parse"
                comments.sort()
        
                ------------------------------------------------------------------------------------
                if TRACE then
                    perf.start"trace"
                    trace(pprint.pformat(ast))
                    perf.stop"trace"
                end
                ------------------------------------------------------------------------------------
        
                local returnId   = nil
                local isClass    = thisModuleInfo.isClass
                local isMeta     = thisModuleInfo.isMeta
                local isMixin    = thisModuleInfo.isMixin
                local isFunction = thisModuleInfo.isFunction
        
                local last = ast[#ast]
                assert(last.tag == "Return" and #last == 1)
                if last[1].tag == "Id" then
                    returnId = last[1][1]
                else
                    local s = last
                    local doc, argListDoc = comments.stripArgListDoc(comments.getBefore(s.pos))
                    local shortDoc = comments.getShortDoc(doc)
                    thisModuleInfo.fullDoc = doc
                    thisModuleInfo.shortDoc = shortDoc
                    local argListString, isMethod = class_util.getArgListString(s[1])
                    if argListString and argListDoc then
                        assert(argListString == argListDoc)
                    end
                    if not argListString and argListDoc then
                        argListString, isMethod = comments.argListDocToMethod(argListDoc)
                    end
                    --assert(not isMethod)
                    thisModuleInfo.argListString = argListString
                    thisModuleInfo.isMethod = isMethod
                end
                local function processBlock(ast, env) 
                    for _, s in ipairs(ast) do
                        trace("TTT", s.pos, s.tag)
                        local tag = s.tag
                        if tag == "Local" or tag == "Localrec" then
                            local s1 = s[1]; 
                            local s2 = s[2]; 
                            local isReturnId = false
                            if s.tag == "Local" then
                                assert(s1.tag == "NameList")
                                assert(not s2.tag or s2.tag == "ExpList", s2)
                                for i = 1, #s1 do
                                    local n = s1[i]; assert(n.tag == "Id")
                                    if n[1] == returnId then
                                        assert(#s1 == 1 and #s2 == 1)
                                        isReturnId = true
                                        break
                                    end
                                end
                            else
                                assert(#s1 == 1 and s1.tag == nil and s1[1].tag == "Id")
                                isReturnId = (s1[1][1] == returnId)
                            end
                            if isReturnId then
                                trace("NEW_MODULE", s.pos, s.end_pos)
                                local docb = comments.getBefore(s.pos)
                                local doca = comments.getAfter(s.end_pos)
                                if docb then
                                    trace("FOUNDBEFORE", docb)--require"inspect"(doc))
                                end
                                if doca then
                                    trace("FOUNDAFTER", doca)
                                end
                                if doca and docb then
                                    lwtk.errorf("Ambiguous class comment in line %d of file %q", re.calcline(content, s.pos), moduleFileName)
                                end
                                env[returnId] = thisModule
                                local doc, argListDoc = comments.stripArgListDoc(docb or doca)
                                local shortDoc = comments.getShortDoc(doc)
                                thisModuleInfo.fullDoc = doc
                                thisModuleInfo.shortDoc = shortDoc

                                if isFunction then
                                    local argListString, isMethod
                                    if tag == "Localrec" then
                                        argListString, isMethod = class_util.getArgListString(s2[1])
                                        --assert(not isMethod)
                                    end
                                    if not argListString and argListDoc then
                                        argListString, isMethod = comments.argListDocToMethod(argListDoc)
                                    end
                                    thisModuleInfo.argListString = argListString
                                    thisModuleInfo.isMethod = isMethod
                                end
                            elseif tag == "Localrec" then
                                assert(#s2 == 1 and s2.tag == nil and s2[1].tag == "Function")
                                local rslt = processExp(env, s2[1])
                                trace("setting", s1[1][1], rslt)
                                env[s1[1][1]] = rslt
                            else
                                for i = 1, #s1 do
                                    local n = s1[i]; assert(n.tag == "Id")
                                    local e = s2[i]
                                    if e then
                                        local rslt = processExp(env, e)
                                        trace("setting", n[1], rslt)
                                        env[n[1]] = rslt
                                    end
                                end
                            end
                        elseif tag == "Set" then
                            local lhsl = s[1];
                            local expl = s[2];
                            local memberInfo = nil
                            for i = 1, #lhsl do
                                local lhs = processExp(env, lhsl[i]);
                                memberInfo = thisModuleInfo.memberInfos[lhs]
                                if memberInfo then
                                    assert(#lhsl == 1)
                                    break
                                end
                            end
                            if memberInfo then
                                local exp = expl[1]
                                local argListString, isMethod = class_util.getArgListString(exp)
                                local fullDoc, argListDoc = comments.stripArgListDoc(comments.getBefore(s.pos))
                                if not argListString and argListDoc then
                                    argListString, isMethod = comments.argListDocToMethod(argListDoc)
                                end
                                memberInfo.fullDoc       = fullDoc
                                memberInfo.shortDoc      = comments.getShortDoc(fullDoc)
                                memberInfo.argListString = argListString
                                memberInfo.isMethod      = isMethod
                                 --trace("LLLLLLLLLLLL", require"inspect"{memberInfo.memberName, processExp(env, exp), lwtk.TextLabel.getMeasures })
                            end
                        elseif tag == "Invoke" then
                            local e1 = processExp(env, s[1])
                            local m  = processExp(env, s[2])
                            if isClass and e1 == thisModule then
                                trace("CCCCCCCCCCCCCCCCCCCC", e1)
                                if m == "declare" then
                                    for i = 3, #s do
                                        local arg = processExp(env, s[i])
                                        trace("DDDDDDDDDDDDDDDDD", arg)
                                        assert(type(arg) == "string")
                                        --declared[arg] = declDoc
                                        local nextPos
                                        if i < #s then
                                            nextPos = s[i + 1].pos
                                        else
                                            nextPos = s.end_pos
                                        end
                                        local doca = comments.getAfter(s[i].end_pos, nextPos)
                                        local docb = comments.getBefore(s[i].pos)
                                        if doca then
                                            trace("FOUNDAFTER", doca)
                                        end
                                        if docb then
                                            trace("FOUNDBEFORE", docb)
                                        end
                                        if doca and docb then
                                            lwtk.errorf("Ambiguous comment for declaration in line %d of file %q", re.calcline(content, s[i].pos), moduleFileName)
                                        end
                                    end
                                end
                            end
                        elseif tag == "Block" then
                            local nextEnv = setmetatable({}, { __index = env })
                            processBlock(s, nextEnv)
                        elseif tag == "If" then
                            local cond = processExp(env, s[1])
                            local nextEnv = setmetatable({}, { __index = env })
                            if cond then
                                processBlock(s[2], nextEnv)
                            elseif s[3] then
                                processBlock(s[3], nextEnv)
                            end
                        end
                    end
                end
                local env = setmetatable({}, { __index = _G })
                processBlock(ast, env)
            end
            if traceOut then
                traceOut:close()
            end
        end
    end
    ---------------------------------------------------------------------------------------------------------------------------
    do
        for _, thisModuleName in ipairs(depOrderedModuleNames) do

            local thisModule     = modules[thisModuleName]
            local thisModuleInfo = moduleInfos[thisModuleName]

            ---------------------------------------------------------------
            parseModule(thisModuleName, thisModule, thisModuleInfo)
            ---------------------------------------------------------------
            
            -- isMethod is only known after parsing the function declaration
            --
            if not thisModuleInfo.isInternal and thisModuleInfo.isClass --[[or thisModuleInfo.isMixin]] then
                local methods = {}
                local functions = {}
                if not thisModuleInfo.memberFunctions then
                    error(require"inspect"{thisModuleName})
                end
                for _, f in ipairs(thisModuleInfo.memberFunctions) do
                    if rawget(thisModule.__index, f.memberName) then
                        local isMethod = f.isMethod
                        if isMethod == nil then
                            if not f.originalMemberInfo then
                                error(require"inspect"{thisModuleName, f})
                            end
                            isMethod = f.originalMemberInfo.isMethod
                            assert(type(isMethod) == "boolean", f.memberName)
                        elseif f.originalMemberInfo then
                            assert(isMethod == f.originalMemberInfo.isMethod)
                        end
                        if isMethod then
                            addSetKey(methods, f.memberName, f) 
                        else
                            addSetKey(functions, f.memberName, f)
                        end
                    end
                end
                thisModuleInfo.methods   = methods
                thisModuleInfo.functions = functions
            end
        end
    end
    ---------------------------------------------------------------------------------------------------------------------------
    do
        for _, info in ipairs(classMixinInfos) do
            local subClassPaths = info.subClassPaths
            table.sort(subClassPaths)
            local subClassTree = {}
            for _, p in ipairs(subClassPaths) do
                local r = subClassTree
                for n in p:gmatch("[^/]+") do
                    local r2 = r[n]
                    if not r2 then
                        r2 = { moduleName = n }
                        addSetKey(r, n, r2)
                    end
                    r = r2
                end
            end
            info.subClassTree = subClassTree
        end
    end
    ---------------------------------------------------------------------------------------------------------------------------
    do
        local function compareMixinRealisation(a, b)
            return a.pathString < b.pathString
        end
        for _, mixinInfo in ipairs(mixinInfos) do
            local reals = mixinInfo.mixinRealisations
            table.sort(reals, compareMixinRealisation)
            local mixinSupers = {}
            for _, r in ipairs(reals) do
                local s = mixinSupers
                for _, e in ipairs(r) do
                    local s2 = s[e.moduleName]
                    if not s2 then
                        s2 = { moduleName = e.moduleName, isMixin = e.isMixin }
                        addSetKey(s, e.moduleName, s2)
                    end
                    s = s2
                end
            end
            mixinInfo.mixinSupers = mixinSupers
        end
    end

    perf.stop"totalparse"
end

return source_parser
