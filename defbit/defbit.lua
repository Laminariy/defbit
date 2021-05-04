local M = {}

local function new_defbit(adress, port, connector, parser)
	local defbit = {
		adress = adress,
		port = port,
		connector = connector,
		parser = parser,

		event = nil,
		shared = nil,
		rpc = nil
	}

	function defbit.update(self)

	end

	function defbit.disconnect(self)

	end

	return defbit
end


function M.connect(adress, port, connector, parser)

	-- return new_defbit
end

function M.listen(adress, port, on_connect, connector, parser)
	-- on_connect(new_defbit)
end

function M.stop_listen()

end

return M
