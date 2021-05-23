local M = {}

function M.new_rpc(connection, parser)
	local rpc = {
		connection = connection,
		parser = parser
	}

	function rpc.set_api(api)

	end

	function rpc.execute(fn, data, on_result)
		-- on_result(result)

	end

	function rpc.call(method, data, on_result)
		-- on_result(result)

	end

	return rpc
end

return M
