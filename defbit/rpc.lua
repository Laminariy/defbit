local M = {}

function M.new_rpc(connector, parser)
	local rpc = {
		connector = connector,
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
