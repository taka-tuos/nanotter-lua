Pluagin = {}

Pluagin.listeners = {
	spawn = {},
	kill = {},
}

function Pluagin:load_all()
	for file in lfs.dir("./core/plugin/") do
		if file ~= "." and file ~= ".." then
			print("LOADING core.plugin." .. file .. "." .. file)
			require("core.plugin." .. file .. "." .. file)
			_G[file].register()
		end
	end
end

function Pluagin:add_event(event)
	if self.listeners[event] == nil then print("Event " .. event .. " was created") self.listeners[event] = {}
	else print("WARN : Event " .. event .. "is already create") end
end

function Pluagin:add_listener(event, listener)
	if self.listeners[event] == nil then Pluagin:add_event(event) end
	table.insert(self.listeners[event], listener)
end

function Pluagin:notify_listeners(event, ...)
	local obj = {}
	for _,listener in pairs(self.listeners[event]) do
		local ret,key = listener(...)
		if key then obj[key] = ret end
	end
	return obj
end


