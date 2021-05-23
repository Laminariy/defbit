local event = require "defbit.event"
local rpc = require "defbit.rpc"
local shared = requiere "defbit.shared"


local M = {}

local function new_defbit(address, port, connector, parser)
	local defbit = {
		address = address,
		port = port,
		connector = connector,
		parser = parser,

		event = event.new_event(connector, parser),
		shared = shared.new_shared(connector, parser),
		rpc = rpc.new_rpc(connector, parser)
	}

	function defbit.update(self)

	end

	function defbit.disconnect(self)

	end

	return defbit
end


function M.connect(address, port, connector, parser)

	-- return new_defbit
end

function M.listen(port, on_connect, connector, parser)
	-- on_connect(new_defbit)
end

function M.stop_listen()

end

return M
