local nativeComponent = component

local component = {}
local components = {}

function component.invoke(addr, fun, ...)
	print("INV:"..addr.." / "..fun)
	if components[addr] then
		return components[addr][fun](...)
	end
	return nativeComponent.invoke(addr, fun, ...)
end

function component.list(filter, exact)
	--log("GETLIST/"..(filter or "nil"));
	local filter = filter
	if not filter then
		local key = nil
		local set = nativeComponent.list(filter, exact)
		for k, v in pairs(components) do
			set[k] = v.type
		end
		return setmetatable(set, {__call=function()
			key = next(set, key)
			if key then
				return key, set[key]
			end
		end})
	end
	local set = {}
	for k,v in pairs(nativeComponent.list(filter, exact)) do
		if v:match("^"..filter..(exact and "$" or "")) then
			set[k] = v
			--log("Lmatch/"..k.."/"..filter)
		end
	end
	for k,v in pairs(components) do
		if v.type:match("^"..filter..(exact and "$" or "")) then
			set[k] = v.type
			--log("Lmatch/"..k.."/"..filter)
		end
	end
	local key = nil
	return setmetatable(set, {__call=function()
		key = next(set, key)
		if key then
			return key, set[key]
		end
	end})
end

function component.add(addr, comp)
	components[addr] = comp
end

_G.component = component
