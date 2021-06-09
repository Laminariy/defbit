local M = {}

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end


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
		local id, fields, options = shared_table.id, shared_table.fields, shared_table.options
		local shared_table = self:create(fields)
		local meta = getmetatable(shared_table)
		meta.set_id(id)
		if options then
			options.type = self.type
			meta.set_options(options)
		end
		table.insert(self.shared_tables, shared_table)

		if self.add_listener then
			self.add_listener(shared_table)
		end
	end

	function shared._get_removed_table(self, shared_table)
		local id = shared_table.id
		for i, sh_tbl in ipairs(self.shared_tables) do
			if getmetatable(sh_tbl).id == id then
				table.remove(self.shared_tables, i)
				local meta = getmetatable(sh_tbl)
				meta.set_id(_)
				meta.set_options(_)
				meta.set_update_listener(_)
				if self.remove_listener then
					self.remove_listener(sh_tbl)
				end
				break
			end
		end
	end

	function shared._get_sync(self, sync_table)
		local id, fields = sync_table.id, sync_table.fields
		for _, sh_tbl in ipairs(self.shared_tables) do
			local meta = getmetatable(sh_tbl)
			if meta.id == id then
				meta.set_changed_data(fields)
				break
			end
		end
	end


	function shared.create(self, tbl)
		local meta = {
			id = _,
			options = _,
			on_update = _,

			__is_shared = true,
			__shared_fields = deepcopy(tbl),
			__changed_fields = {} -- {key: is_changed}
		}

		function meta.__newindex(tbl, key, value)
			if meta.options then
				local type, rights = meta.options.type, meta.options.rights
				if rights[key] and (type == rights[key] or rights[key] == 'both') then
					meta.__shared_fields[key] = value
					meta.__changed_fields[key] = true
				end
				return
			end
			meta.__shared_fields[key] = value
			meta.__changed_fields[key] = true
		end

		function meta.__index(tbl, key)
			return meta.__shared_fields[key]
		end

		function meta.clear_changed_fields()
			for key, _ in pairs(meta.__changed_fields) do
				meta.__changed_fields[key] = nil
			end
		end

		function meta.set_id(id)
			if meta.id and id then
				error('table already shared', 3)
				return
			end
			meta.id = id
		end

		function meta.set_options(options)
			--[[
			options = {
				type = 'client', 'server'
				on_update(table, fields),
				rights = {field_name = "both", "server", "client"},
				del_access = "server", "client", "both"
			}
			]]
			if options then
				meta.on_update = options.on_update
				options.on_update = nil
			end
			meta.options = options
		end

		function meta.set_update_listener(listener)
			meta.on_update = listener
		end

		function meta.get_changed_data()
			local changed = {}
			changed.__is_shared = true
			for key, _ in pairs(meta.__changed_fields) do
				if getmetatable(meta.__shared_fields[key]) and getmetatable(meta.__shared_fields[key]).__is_shared then
					changed[key] = getmetatable(meta.__shared_fields[key]).get_changed_data()
				else
					changed[key] = meta.__shared_fields[key]
				end
			end
			return changed
		end

		function meta.get_full_data()
			local data = {}
			data.__is_shared = true
			for key, value in pairs(meta.__shared_fields) do
				if getmetatable(value).__is_shared then
					data[key] = getmetatable(value).get_full_data()
				else
					data[key] = value
				end
			end
			return data
		end

		function meta.set_changed_data(changed_data)
			changed_data.__is_shared = nil
			local changed_fields = {}
			local typ = type -- fast fix
			local type, rights = meta.options.type, meta.options.rights
			for key, value in pairs(changed_data) do
				if type ~= rights[key] or rights[key] == 'both' then
					table.insert(changed_fields, key)
					if typ(value) == 'table' and value.__is_shared then
						getmetatable(meta.__shared_fields[key]).set_changed_data(value)
					else
						meta.__shared_fields[key] = value
					end
				end
			end
			if meta.on_update then
				meta.on_update(meta.__child, changed_fields)
			end
		end

		meta.__child = setmetatable({}, meta)
		return meta.__child
	end

	function shared.set_options(self, shared_table, options)
		options.type = self.type
		getmetatable(shared_table).set_options(options)
	end

	function shared.add(self, shared_tbl, options)
		local meta = getmetatable(shared_tbl)
		assert(meta.__is_shared, 'you must provide shared table')

		meta.set_id(self.type..'_'..self.shared_ids)
		self.shared_ids = self.shared_ids + 1

		if options then
			options.type = self.type
			meta.set_options(options)
		end

		table.insert(self.shared_tables, shared_tbl)

		local data = {
			id = meta.id,
			fields = meta.__shared_fields,
			options = options
		}
		data = self.parser.encode('shared_add', data)
		self.connection:send(data)
	end

	function shared.remove(self, shared_tbl)
		local meta = getmetatable(shared_tbl)
		assert(meta.__is_shared, 'you must provide shared table')
		assert(meta.id, 'table must be added to client')

		local del_access = meta.options.del_access
		if del_access ~= self.type and del_access ~= 'both' then
			return
		end

		for i, sh_tbl in ipairs(self.shared_tables) do
			if shared_tbl == sh_tbl then
				local data = self.parser.encode('shared_remove', {id = meta.id})
				self.connection:send(data)
				table.remove(self.shared_tables, i)
				break
			end
		end

		meta.set_id(_)
		meta.set_options(_)
		meta.set_update_listener(_)
	end

	function shared.delta_sync(self)
		for _, shared_table in ipairs(self.shared_tables) do
			local meta = getmetatable(shared_table)
			local sync_tbl = {
				id = meta.id,
				fields = meta.get_changed_data()
			}

			sync_tbl.fields.__is_shared = nil -- fast hack
			if next(sync_tbl.fields) then
				local data = self.parser.encode('shared_sync', sync_tbl)
				self.connection:send(data)
				meta.clear_changed_fields()
			end
		end
	end

	function shared.full_sync(self)
		for _, shared_table in ipairs(self.shared_tables) do
			local meta = getmetatable(shared_table)
			local sync_tbl = {
				id = meta.id,
				fields = meta.get_full_data()
			}
			local data = self.parser.encode('shared_sync', sync_tbl)
			self.connection:send(data)
			meta.clear_changed_fields()
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
		getmetatable(shared_table).set_update_listener(listener)
	end

	return shared
end

return M