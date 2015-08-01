local function newGpu(element)
	local gpu = {}
	gpu.type = "gpu"

	local cbg = 0x0
	local lines = {}
	for i = 1, 24 do
		lines[i] = (" "):rep(80)
	end

	function gpu.bind() end
	function gpu.getScreen() return "webscreen" end

	gpu.getBackground = function() return cbg, false end
	gpu.setBackground = function(color) cbg = color return true end

	gpu.getForeground = function() return cbg, false end
	gpu.setForeground = function(color) cbg = color return true end

	gpu.getResolution = function() return 80, 24 end
	gpu.setResolution = function() return true end

	gpu.maxDepth = function() return 8 end

	gpu.set = function(x, y, value, vertical)
		lines[y-1] = value
		native:jqset("#terml"..(y-1), value)
		--console.log("#terml"+(y-1));
		return true;
	end

	gpu.fill = function(x, y, w, h, char)
		for i = 1, h do
			lines[y+i-1] = char:rep(w)
			native:jqset("#terml"..(y+i-1), char:rep(w))
			--print("#terml"..(y+i-1));
		end
		return true
	end

	return gpu
end

component.add("webgpu", newGpu("#term"))
