JSON = JSON[0]
local function checkArg(n, have, ...)
  have = type(have)
  local function check(want, ...)
    if not want then
      return false
    else
      return have == want or check(...)
    end
  end
  if not check(...) then
    local msg = string.format("bad argument #%d (%s expected, got %s)",
                              n, table.concat({...}, " or "), have)
    error(msg, 3)
  end
end

-------------------------------------------------------------------------------

local function log(...)
	js.global:log(...)
end

local function wrapNativeLib(lib)
	return setmetatable({}, {__index = function(t, method)
		return function( ... )
			return lib[method](lib, ...)
		end
	end})
end

local function fromNativeObject(serialised)
	local t = {}
	for i = 0, #serialised-1,2 do
		log("NTCV:",serialised[i],serialised[i+1])
		t[serialised[i]] = serialised[i+1]
	end
	return t
end

local function wrapFunction(func, fn)
	--log("Wrap>", fn)
	return function(...)
		log("Call> ", fn)
		return func(...)
	end
end

local function wrapTable(tab, ignore)
	local newtab = {}
	
	for k, v in pairs(tab) do
		if type(v) == "function" then
			newtab[k] = wrapFunction(v, k)
		elseif type(v) == "table" then
			newtab[k == ignore and "" or k] = wrapTable(v, ignore)
		else
			newtab[k] = v
		end
	end
	
	return newtab
end


local unicode = wrapNativeLib(unicode)

local sandbox

local wrappers = {
	checkArg = checkArg,
	error = function(...)
		log("REPORTEDERROR:",...)
		log(debug.traceback())
		error(...)
	end,
	print = log,
	pcall = function(fn, ...)
		local args = {...}
		log("Pcall!")
		local res = {xpcall(function()
				return fn(table.unpack(args))
			end,
			function(e,...) 
				log("Failed pcall @ ",debug.traceback(),"PCE: ",e)
				return e,... 
			end)}
		log("[x]Pcall END: ",res[1], res[2])
		return table.unpack(res)
	end,
	load = function(ld, source, mode, env)
		return load(ld, source, mode, env or sandbox)
	end,
	unicode = unicode,
	component = { --Low level components
		invoke = function(c,m,...)
			--log("CINVOKE["..c.."]"..m)
			local res = component:invoke(c,m,...)
			if not res then return end
			return JSON:decode(res)
		end,
		list = function(filter, exact)
			log("GETLIST/"..(filter or "nil"));
			local filter = filter
			if not filter then
				local key = nil
				local set = fromNativeObject(component:list())
				return setmetatable(set, {__call=function()
					key = next(set, key)
					if key then
						return key, set[key]
					end
				end})
			end
			local set = {}
			for k,v in pairs(fromNativeObject(component:list())) do
				if v:match("^"..filter..(exact and "$" or "")) then
					set[k] = v
					log("Lmatch/"..k.."/"..filter)
				end
			end
			local key = nil
			return setmetatable(set, {__call=function()
				key = next(set, key)
				if key then
					return key, set[key]
				end
			end})
		end,
		proxy = function(addr)
			return setmetatable({}, {__index = function(c, method)
				return function(...)
					log("CINVOKE(via proxy)[" .. addr .. "]" .. method)
					return component:invoke(addr,method,...)
				end
			end})
		end,
		methods = function(address)
			log("FIXME: component;methods;"..address)
		end
	}
}

sandbox = setmetatable(wrappers,{__index = function(t,i)
	log("_get", i, type(_G[i]))
	
	if i == "_G" then
		return sandbox
	elseif type(_G[i]) == "function" then
		----
		--return _G[i]
		----
		return function(...)
			log("Call[g]>",i)
			--log(debug.traceback())
			--log("")
			return _G[i](...)
		end
	elseif type(_G[i]) == "table" and i ~= "table" then
		return wrapTable(_G[i])
	end
	return _G[i]
end})

wrappers._G = sandbox

function runStage(stageUrl)
	--component:invoke("webgpu","set",1,3,"Downloading stage "..stageUrl)
	local kernelCode = JSON:decode(component:invoke("webinternet", "request", stageUrl))

	local kfun,e = load(kernelCode, "="..stageUrl, nil, sandbox)

	if not kfun then
		log("-------------------------------------------------------------------")
		log("STAGE LOADING FAILED:")
		log(e)
		log("-------------------------------------------------------------------")
	end

	local kcoro = coroutine.create(function()
		local status, err = xpcall(kfun, function(err) 
			log("Kernel Error:",err)
			log(debug.traceback())
			return err
		end)
		log("STAGE QUIT WITH STATUS: ", status, ";E:", type(err))
	end)

	--component:invoke("webgpu", "set", 1,4,"Booting stage "..stageUrl)
	log("STARTING STAGE-------------> " .. stageUrl)

	for i=0,10 do
		local data = {coroutine.resume(kcoro)}
		log("Resumed stage, yield data:", table.unpack(data))
		log("stage thread status: ", coroutine.status(kcoro))
		if coroutine.status(kcoro) == "dead" then
			log("Stage "..stageUrl.." has quit")
			break
		end	
	end
end

runStage("vm/component.lua")
runStage("vm/gpu.lua")

runStage("vm/eeprom.lua")
