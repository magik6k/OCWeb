local function log(...)
	js.global:log(...)
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
		--log("Call> ", fn)
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


local sandbox

local wrappers = {
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
	component = {
		invoke = function(c,m,...)
			log("CINVOKE["..c.."]"..m)
			return component:invoke(c,m,...)
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
		methods = function(address)
			log("FIXME: component;methods;"..address)
		end
	}
}

function runKernel(kernelUrl)
	component:invoke("webgpu","set",1,3,"Downloading eeprom "..kernelUrl)
	local kernelCode = component:invoke("webinternet", "request", kernelUrl)

	sandbox = setmetatable(wrappers,{__index = function(t,i)
		log("_get", i, type(_G[i]))
		
		if i == "_G" then
			return sandbox
		elseif type(_G[i]) == "function" then
			----
			return _G[i]
			----
			--[[return function(...)
				log("Call[g]>",i)
				--log(debug.traceback())
				--log("")
				return _G[i](...)
			end]]
		elseif type(_G[i]) == "table" and i ~= "table" then
			return wrapTable(_G[i])
		end
		return _G[i]
	end})

	local kfun,e = load(kernelCode, "=KERNEL", nil, sandbox)

	local kcoro = coroutine.create(function()
		local status, err = xpcall(kfun, function(err) 
			log("Kernel Error:",err)
			log(debug.traceback())
			return err
		end)
		log("KERNEL QUIT WITH STATUS: ", status, ";E:", type(err))
	end)

	--component:invoke("webgpu", "set", 1,4,"Booting kernel "..kernelUrl)
	log("STARTING KERNEL-------------> "..kernelUrl)

	for i=0,10 do
		local data = {coroutine.resume(kcoro)}
		log("Resume kernel, yield data:", table.unpack(data))
		log("kernel thread status: ", coroutine.status(kcoro))
		if coroutine.status(kcoro) == "dead" then
			log("Kernel "..kernelUrl.." has quit")
			break
		end	
	end
end

runKernel("vm/eeprom.lua")
