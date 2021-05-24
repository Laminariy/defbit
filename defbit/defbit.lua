local standart_connector = require "defbit.connectors.tcp_connector"
local standart_parser = require "defbit.parsers.lua_parser"

local event = require "defbit.event"
local rpc = require "defbit.rpc"
local shared = require "defbit.shared"


local M = {}

local connection_warn = {}
function connection_warn.send(self, data)
	print('error! client not connected!')
end


function M.server(port, on_connect, on_disconnect, connector, parser)
	local connector = connector or standart_connector
	local parser = parser or standart_parser

	local defbit_server = {
		port = port,
		backlog = 32,
		connection = _,
		parser = parser,

		on_connect = on_connect,
		on_disconnect = on_disconnect
	}

	function defbit_server.start(self)
		local function on_connect(client_socket)
			local adress, port = client_socket:getpeername()
			local client = M.client(address, port, self.on_disconnect, connector, parser)
			local ok, err = client:connect(client_socket)
			if ok then
				self.on_connect(client)
			end
		end

		local server = connector.new_server(on_connect)
		local ok, err = server:start(self.port, self.backlog)
		if ok then
			self.connection = server
		end

		return ok, err
	end

	function defbit_server.update(self)
		if self.connection then
			self.connection:update()
		end
	end

	function defbit_server.stop(self)
		if self.connection then
			self.connection:stop()
			self.connection = nil
		end
	end

	return defbit_server
end

function M.client(address, port, on_disconnect, connector, parser)
	local connector = connector or standart_connector
	local parser = parser or standart_parser

	local defbit_client = {
		address = address,
		port = port,
		connection = _,
		parser = parser,

		on_disconnect = on_disconnect,

		event = event.new_event(connection_warn, parser),
		shared = shared.new_shared(connection_warn, parser),
		rpc = rpc.new_rpc(connection_warn, parser)
	}

	function defbit_client.connect(self, client_socket)
		local function on_message(connection, data)
			local data = self.parser.decode(data)
			if data.type == 'event' then
				self.event:_trigger_listeners(data.data)
			elseif data.type == 'shared' then

			elseif data.type == 'rpc_call' then
				self.rpc:_get_call(data.data)
			elseif data.type == 'rpc_execution' then
				self.rpc:_get_execution(data.data)
			elseif data.type == 'rpc_result' then
				self.rpc:_get_result(data.data)
			end
		end

		local function on_disconnect(connection)
			self:disconnect()
			if self.on_disconnect then
				self:on_disconnect()
			end
		end

		local connection = connector.new_client(on_message, on_disconnect)
		local ok, err = connection:connect(self.address, self.port, client_socket)
		if ok then
			self.connection = connection
			self.event.connection = connection
			self.shared.connection = connection
			self.rpc.connection = connection
		end

		return ok, err
	end

	function defbit_client.update(self)
		if self.connection then
			self.connection:update()
		end
	end

	function defbit_client.disconnect(self)
		if self.connection then
			self.connection:disconnect()
			self.connection = _
			self.event.connection = connection_warn
			self.shared.connection = connection_warn
			self.rpc.connection = connection_warn
		end
	end

	return defbit_client
end

return M
