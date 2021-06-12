require "defbit.parsers.data_dumper"


local M = {}

function M.encode(type, data)
	data = {
		type = type,
		data = data
	}
	data = DataDumper(data, _, true)
	return data
end

function M.decode(data)
	local decoded, err = loadstring(data)
	if err then
		return {type='err', data=err}
	end
	local env = {loadstring=loadstring}
	setfenv(decoded, env)
	local status, decoded_data = pcall(decoded)
	if not status then
		return {type='err', data=decoded_data}
	end
	return decoded_data
end

return M
