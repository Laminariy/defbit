local socket = require "builtins.scripts.socket"

local M = {}

function M.new_server(on_connect)
	local server = {
		on_connect = on_connect
	}

	function server.start(self, port, backlog)
		local server_socket, err = socket.bind("*", port, backlog)
		if not server_socket or err then
			print("unable to start server "..err)
			return nil, err
		end
		server_socket:settimeout(0)
		self.server_socket = server_socket
		return true
	end

	function server.update(self)
		if self.server_socket then
			local client_socket, err = self.server_socket:accept()
			if client_socket then 
				client_socket:settimeout(0)
				self.on_connect(client_socket)
			end
		end
	end

	function server.stop(self)
		if self.server_socket then
			self.server_socket:close()
			self.server_socket = nil
		end
	end

	return server
end



function M.new_client(on_message, on_disconnect)
	local client = {
		queue = {},
		loaded_data = "",

		on_message = on_message,
		on_disconnect = on_disconnect
	}

	function client.connect(self, address, port, client_socket)
		if client_socket then
			self.client_socket = client_socket
			return true
		end

		local client_socket, err = socket.connect(address, port)
		if not client_socket or err then
			print("connection to server failed: "..err)
			return nil, err
		end
		client_socket:settimeout(0)
		self.client_socket = client_socket
		return true
	end

	function client.send(self, data)
		if self.client_socket then
			table.insert(self.queue, {data = data.."\r\n", sent_index = 0})
		end
	end

	function client.update(self)
		if self.client_socket then
			local read, write = socket.select({self.client_socket}, {self.client_socket}, 0)

			if read[self.client_socket] then
				local data, err, partial = self.client_socket:receive("*l")
				if partial then
					self.loaded_data = self.loaded_data..partial
				end
				if data then
					self.on_message(self, self.loaded_data..data)
					self.loaded_data = ""
				end
				if err and err == "closed" then
					self:disconnect()
					if self.on_disconnect then
						self.on_disconnect(self)
					end
				end
			end

			if write[self.client_socket] then
				local data = self.queue[1]
				if data then
					local index, err, err_index = self.client_socket:send(data.data, data.sent_index+1, #data.data)
					if err then
						data.sent_index = err_index
					else
						data.sent_index = index
						if data.sent_index == #data.data then
							table.remove(self.queue, 1)
						end
					end
					if err and err == "closed" then
						self:disconnect()
						if self.on_disconnect then
							self.on_disconnect(self)
						end
					end
				end
			end
		end
	end

	function client.disconnect(self)
		if self.client_socket then
			self.client_socket:close()
			self.client_socket = nil
			self.queue = {}
			self.loaded_data = ""
		end
	end

	return client
end

return M