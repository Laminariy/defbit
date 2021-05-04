local M = {}

function M.new_event(connector, parser)
	local event = {
		connector = connector,
		parser = parser
	}

	function event.fire(self, type, data)

	end

	function event.set_listener(self, type, listener)
		-- listener(type, data)

	end

	function event.remove_listener(self, type, listener)

	end

	return event
end

return M
