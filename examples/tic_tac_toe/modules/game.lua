local M = {}

function M.new()
	local game = {
		board = {},
		turn = 'red',
		turn_count = 0,
		game_started = false
	}

	function game.clean_board(game)
		for x = 1, 3 do
			game.board[x] = {}
			for y = 1, 3 do
				game.board[x][y] = 'empty'
			end
		end
	end

	function game.start(game)
		game:clean_board()
		game.game_started = true
	end

	function game.make_turn(game, player, position)
		-- player: 'red', 'blue'
		-- position = {x, y}
		--
		-- returns
		-- nil, err if error
		-- {state, player} if not error
		-- state: 'game', 'win', 'draw'

		if not game.game_started then
			return nil, 'game not started'
		end
		if player ~= game.turn then
			return nil, 'another player turn'
		end

		local x, y = position.x, position.y
		if game.board[x][y] == 'empty' then
			game.board[x][y] = player
			game.turn_count = game.turn_count + 1

			-- check col
			for i = 1, 3 do
				if board[x][i] ~= player then
					break
				end
				if i == 3 then
					-- win for player
					return {state='win', player=player}
				end
			end

			-- check row
			for i = 1, 3 do
				if board[i][y] ~= player then
					break
				end
				if i == 3 then
					-- win for player
					return {state='win', player=player}
				end
			end

			-- check diag
			if x == y then
				for i = 1, 3 do
					if board[i][i] ~= player then
						break
					end
					if i == 3 then
						-- win for player
						return {state='win', player=player}
					end
				end
			end

			-- check anti-diag
			if x+y == 4 then
				for i = 1, 3 do
					if board[i][4-i] ~= player then
						break
					end
					if i == 3 then
						-- win for player
						return {state='win', player=player}
					end
				end
			end

			-- check draw
			if game.turn_count == 9 then
				-- draw
				return {state='draw'}
			end

			return {state='game'}
		end
	end

	function game.stop(game)
		game.game_started = false
	end

	game:clean_board()

	return game
end

return M
