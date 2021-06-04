local game = require "examples.tic_tac_toe.modules.game"


local M = {}

function M.new()
	local session = {
		game = game.new(),
		users = {},
		stats = {
			players = 0,
			spectators = 0
		}
	}

	function session.add_user(session, user, type)
		-- type: 'player', 'spectator'
		user.type = type
		if user.type == 'player' and session.stats.players == 2 then
			return nil, 'Session already has the maximum number of players'
		end
		table.insert(session.users, user)
		if user.type == 'player' then
			session.stats.players = session.stats.players + 1
			if session.stats.players == 2 then
				session.game:start()
			end
		elseif user.type == 'spectator' then
			session.stats.spectators = session.stats.spectators + 1
		end
		return true
	end

	function session.remove_user(session, user)
		for i, us in ipairs(session.users) do
			if us == user then
				table.remove(session.users, i)
				if user.type == 'player' then
					session.stats.players = session.stats.players - 1
					session.game:stop()
				elseif user.type == 'spectator' then
					session.stats.spectators = session.stats.spectators - 1
				end
				return true
			end
		end
		return nil, 'user not exist'
	end

	return session
end

return M