local M = {}

function M.connect(adress, port, on_message)

	--return connection
end

function M.listen(adress, port, queue_size, on_connect)
	--[[
		on_connect(connection)
	]]

end

function M.disconnect(connection)

end

function M.stop_listen()

end

function M.send(connection, data)

end

function M.update()

end

return M