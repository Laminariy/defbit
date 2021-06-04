local M = {}

function M.new_shared(connection, parser)
	local shared = {
		connection = connection,
		parser = parser,

		type = 'client',
		shared_tables = {},
		shared_ids = 0,

		add_listener = _,
		remove_listener = _
	}

	function shared._get_new_table(self, shared_table)
		local id, del_access, fields = shared_table.id, shared_table.del_access, shared_table.fields

		local tbl = {}
		local meta = {
			id = id,
			_shared = true,
			del_access = del_access,
			fields = {} --{field_name = {value, rights, was_changed}}
		}

		for key, value in pairs(fields) do
			meta.fields[key] = {value = value.value, rights = value.rights, was_changed = false}
		end

		function meta.__newindex(tbl, key, value)
			if meta.fields[key] then
				if self.type == meta.fields[key].rights or meta.fields[key].rights == 'both' then
					meta.fields[key].was_changed = true
					meta.fields[key].value = value
				end
			else
				rawset(tbl, key, value)
			end
		end

		function meta.__index(tbl, key)
			if meta.fields[key] then
				return meta.fields[key].value
			else
				return rawget(tbl, key)
			end
		end

		setmetatable(tbl, meta)
		table.insert(self.shared_tables, tbl)

		if self.add_listener then
			self.add_listener(tbl)
		end
	end

	function shared._get_removed_table(self, shared_table)
		local id = shared_table.id

		for i, tbl in ipairs(self.shared_tables) do
			if getmetatable(tbl).id == id then
				table.remove(self.shared_tables, i)
				if self.remove_listener then
					self.remove_listener(tbl)
				end
				break
			end
		end
	end

	local function unparse_sh_fields(self, tbl, meta, fields)
		-- TO DO: unparse
		local field_names = {}
		for key, value in pairs(fields) do
			if meta.fields[key].rights == 'both' or self.type ~= meta.fields[key].rights then
				if type(value) == 'table' then
					
				else
					rawset(tbl, key, value)
				end
				table.insert(field_names, key)
			end
		end
	end

	function shared._get_sync(self, sync_table)
		local id = sync_table.id
		for _, tbl in ipairs(self.shared_tables) do
			local meta = getmetatable(tbl)
			if meta.id == id then
				local field_names = {}
				for key, value in pairs(sync_table.fields) do
					if meta.fields[key].rights == 'both' or self.type ~= meta.fields[key].rights then
						if type(value) == 'table' then
							
						else
							rawset(tbl, key, value)
						end
						table.insert(field_names, key)
					end
				end
				if meta.on_update then
					meta.on_update(tbl, field_names)
				end
				break
			end
		end
	end


	function shared.create(self, tbl, options)
		-- TO DO: one shared table in many clients
		-- was_changed on defbit.client, not in shared_table
		--[[
		options = {
			on_update(table, fields),
			rights = {field_name = "both", "server", "client"},
			del_access = "server", "client", "both"
		}
		]]

		local meta = {
			_shared = true,
			del_access = options.del_access or "both",
			fields = {}, --{field_name = {value, rights, was_changed}}
			on_update = options.on_update
		}

		for field, rights in pairs(options.rights) do
			meta.fields[field] = {value = tbl[field], rights = rights, was_changed = false}
			tbl[field] = nil
		end

		function meta.__newindex(tbl, key, value)
			if meta.fields[key] then
				if self.type == meta.fields[key].rights or meta.fields[key].rights == 'both' then
					meta.fields[key].was_changed = true
					meta.fields[key].value = value
				end
			else
				rawset(tbl, key, value)
			end
		end

		function meta.__index(tbl, key)
			if meta.fields[key] then
				return meta.fields[key].value
			else
				return rawget(tbl, key)
			end
		end

		setmetatable(tbl, meta)

		return tbl
	end

	function shared.add(self, shared_table)
		local meta = getmetatable(shared_table)
		meta.id = self.type..'_'..self.shared_ids
		self.shared_ids = self.shared_ids + 1
		local sh_table = {
			id = meta.id,
			del_access = meta.del_access,
			fields = {}
		}

		for key, value in ipairs(meta.fields) do
			sh_table.fields[key] = {value = value.value, rights = value.rights}
		end

		local data = self.parser.encode('shared_add', sh_table)
		self.connection:send(data)

		table.insert(self.shared_tables, shared_table)
	end

	function shared.remove(self, shared_table)
		local meta = getmetatable(shared_table)
		if meta.del_access == self.type or meta.del_access == 'both' then
			for i, tbl in ipairs(self.shared_tables) do
				if tbl == shared_table then
					local data = self.parser.encode('shared_remove', {id = meta.id})
					self.connection:send(data)
					table.remove(self.shared_tables, i)
					break
				end
			end
		end
	end

	function shared.set_add_listener(self, listener)
		-- listener(shared_table)
		self.add_listener = listener
	end

	function shared.set_remove_listener(self, listener)
		-- listener(shared_table)
		self.remove_listener = listener
	end

	function shared.set_update_listener(self, shared_table, listener)
		local meta = getmetatable(shared_table)
		meta.on_update = listener
	end

	local function parse_d_sh_fields(fields)
		local sh_fields = {}

		for field, data in pairs(fields) do
			if data.was_changed then
				sh_fields[field] = data.value
				data.was_changed = false
			end
			if getmetatable(data.value)._shared then
				local fields = getmetatable(data.value).fields
				sh_fields[field] = parse_d_sh_fields(fields)
			end
		end

		return sh_fields
	end

	function shared.delta_sync(self)
		for _, tbl in ipairs(self.shared_tables) do
			local meta = getmetatable(tbl)
			local sync_tbl = {
				id = meta.id,
				fields = parse_d_sh_fields(meta.fields)
			}

			if next(sync_tbl.fields) then
				local data = self.parser.encode('shared_sync', sync_tbl)
				self.connection:send(data)
			end
		end
	end

	local function parse_f_sh_fields(self, fields)
		local sh_fields = {}

		for field, data in pairs(fields) do
			if data.rights == self.type or data.rights == 'both' then
				if getmetatable(data.value)._shared then
					local fields = getmetatable(data.value).fields
					sh_fields[field] = parse_f_sh_fields(self, fields)
				else
					sh_fields[field] = data.value
				end
			end
			data.was_changed = false
		end

		return sh_fields
	end

	function shared.full_sync(self)
		for _, tbl in ipairs(self.shared_tables) do
			local meta = getmetatable(tbl)
			local sync_tbl = {
				id = meta.id,
				fields = parse_f_sh_fields(self, meta.fields)
			}

			if next(sync_tbl.fields) then
				local data = self.parser.encode('shared_sync', sync_tbl)
				self.connection:send(data)
			end
		end
	end

	return shared
end

return M
