local M = {}

function M.new_event(connection, parser)
	local event = {
		connection = connection,
		parser = parser,

		listeners = {}
	}

	function event._trigger_listeners(self, event)
		local type, data = event.type, event.data
		if self.listeners[type] then
			for _, listener in ipairs(self.listeners[type]) do
				listener(type, data)
			end
		end
		if self.listeners["_all"] then
			for _, listener in ipairs(self.listeners["_all"]) do
				listener(type, data)
			end
		end
	end


	function event.fire(self, type, data)
		local event = {type=type}
		if data then
			event.data = data
		end
		data = self.parser.encode('event', event)
		self.connection:send(data)
	end

	function event.set_listener(self, type, listener)
		-- listener(type, data)
		type = type or "_all"
		if not self.listeners[type] then
			self.listeners[type] = {}
		end
		table.insert(self.listeners[type], listener)
	end

	function event.remove_listener(self, type, listener)
		type = type or "_all"
		if self.listeners[type] then
			for i, subscriber in ipairs(self.listeners[type]) do
				if listener == subscriber then
					table.remove(self.listeners[type], i)
					if #self.listeners[type] == 0 then
						self.listeners[type] = nil
					end
					break
				end
			end
		end
	end

	return event
end

return M
