require "defbit.parsers.data_dumper"


local M = {}

function M.encode(type, data)
	local data = {
		type = type,
		data = data
	}
	data = DataDumper(data, _, true)
	return data
end

function M.decode(data)
	-- могут ли выбивать ошибки?
	-- assert, pcall
	local decoded = loadstring(data)
	local env = {}
	setfenv(decoded, env)
	decoded = decoded()
	return decoded
end

return M