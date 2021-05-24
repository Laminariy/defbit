local M = {}

function M.new_rpc(connection, parser)
	local rpc = {
		connection = connection,
		parser = parser,

		enviroment = {},
		waiters = {},
		rpc_ids = 0
	}

	function rpc._get_result(self, data)
		local id, result = data.id, data.result
		for i, waiter in ipairs(self.waiters) do
			if waiter.id == id then
				waiter.on_result(unpack(result))
				table.remove(self.waiters, i)
				break
			end
		end
	end

	function rpc._get_call(self, call)
		local result = {
			id = call.id
		}
		local method = self.enviroment[call.method]
		if method then
			result.result = {method(unpack(call.args))}
		else
			result.result = {'error! method not exists'}
		end
		local data = self.parser.encode('rpc_result', result)
		self.connection:send(data)
	end

	function rpc._get_execution(self, execution)
		local result = {
			id = execution.id
		}

		local fn, args = execution.fn, execution.args
		setfenv(fn, self.enviroment)
		local res = {pcall(fn, unpack(args))}
		result.result = {unpack(res, 2)}

		local data = self.parser.encode('rpc_result', result)
		self.connection:send(data)
	end


	function rpc.set_enviroment(self, enviroment)
		self.enviroment = enviroment
	end

	function rpc.execute(self, fn, args, on_result)
		-- on_result(res1, res2, ...)
		local execution = {
			id = self.rpc_ids,
			fn = fn,
			args = args
		}

		table.insert(self.waiters, {id = self.rpc_ids, on_result = on_result})

		self.rpc_ids = self.rpc_ids + 1

		local data = self.parser.encode('rpc_execution', execution)
		self.connection:send(data)
	end

	function rpc.call(self, method, args, on_result)
		-- on_result(res1, res2, ...)
		local call = {
			id = self.rpc_ids,
			method = method,
			args = args
		}

		table.insert(self.waiters, {id = self.rpc_ids, on_result = on_result})

		self.rpc_ids = self.rpc_ids + 1

		local data = self.parser.encode('rpc_call', call)
		self.connection:send(data)
	end

	return rpc
end

return M
