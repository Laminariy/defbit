local M = {}

function M.new_shared(connection, parser)
	local shared = {
		connection = connection,
		parser = parser
	}

	function shared.add(self, table, options)

	end

	function shared.remove(self, shared_table)

	end

	function shared.set_add_listener(self, listener)
		-- listener(shared_table)

	end

	function shared.set_remove_listener(self, listener)

	end

	function shared.delta_sync(self)

	end

	function shared.full_sync(self)

	end

	return shared
end

return M
