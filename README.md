# DefBit
Simple Defold library for multiplayer games.

Events, RPC, shared tables.

---

## Installation

Install DefBit in your project by adding it as a [library dependency](https://www.defold.com/manuals/libraries/). Open your game.project file and in the "Dependencies" field under "Project", add:
```
https://github.com/Laminariy/--/archive/v1.1.0.zip
```

Then open the "Project" menu of the editor and click "Fetch Libraries". You should see the "defbit" folder appear in your assets panel after a few moments.

## Usage

### Server

```lua
local defbit = require "defbit.defbit"


local PORT = 8888
local clients = {}

local function on_connect(client)
	print("client connected to server")
	table.insert(clients, client)

	-- send hello event to client
	client.event:fire("Hello from server!")

	-- set enviroment for rpc
	local enviroment = {
		server_data = 'this is server data',
		ping = function()
			print("get ping from client")
			return "pong"
		end
	}
	client.rpc:set_enviroment(enviroment)

	-- set shared table
	local shared_table = {
		entity_id = 0,
		position = {x=5, y=10},
		health = {max=10, current=10},
		state = "idle"
	}
	local options = {
		del_acess = "server",
		rights = {
			position = "client",
			health = "server",
			state = "both"
		}
		on_update = function(self, fields)
			print("client changed some shared fields")
			for _, field in ipairs(fields) do
				print(field..': '..self[field])
			end
		end
	}
	shared_table = client.shared:create(shared_table)
	client.shared:add(shared_table, options)
end

local function on_disconnect(client)
	print("client disconnected from server")
	for i, cl in ipairs(clients) do
			if cl == client then
				table.remove(self.clients, i)
				break
			end
		end
end

function init(self)
	self.server = defbit.server(PORT, on_connect, on_disconnect)
	local ok, err = self.server:start()
	if ok then
		print("server started")
	end
end

function update(self, dt)
	-- update server and clients
	self.server:update()

	for _, client in ipairs(clients) do
		client:update()
		-- sync shared tables
		client.shared:delta_sync()
	end
end

function final(self)
	-- stop server and disconnect all clients
	self.server:stop()
	for _, client in ipairs(clients) do
		client:disconnect()
	end
end
```

### client

```lua
local defbit = require "defbit.defbit"


local ADDRESS, PORT = "localhost", 8888

local function on_disconnect(client)
	print("disconnected from server")
end

function init(self)
	self.client = defbit.client(ADDRESS, PORT, on_disconnect)
	local ok, err = self.client:connect()
	if ok then
		print("connected to server")

		-- set event listener
		self.client.event:set_listener("Hello from server!", function(type, data)
			print("server says hello!")
		end)

		-- make rpc
		local function serv_func()
			return server_data, ping()
		end
		local function on_result(server_data, pong)
			print(server_data)
			print(pong)
		end
		self.client.rpc:execute(serv_func, {}, on_result)

		-- set shared listeners
		self.client.shared:set_add_listener(function(shared_table)
			print("server added new shared table")
			shared_table.position = {x=1, y=79}
			shared_table.state = "run"
		end)
	end
end

function update(self, dt)
	self.client:update()
	self.client.shared:delta_sync()
end

function final(self)
	self.cllient:disconnect()
end
```
## DefBit Reference

### `defbit.server(port, on_connect, on_disconnect[, connector, parser])`

Returns new server object.

**Parameters**

- `port` <kbd>number</kbd> Server port.
- `on_connect(client)` <kbd>function</kbd> Callback will be called when new client connected to server.
- `on_disconnect(client)` <kbd>function</kbd> Callback will be called when client disconnected from server.
- `connector` <kbd>table</kbd> (_optional_)
- `parser` <kbd>table</kbd> (_optional_)

### `defbit.client(address, port, on_disconnect[, connector, parser])`

Returns new client object.

**Parameters**

- `address` <kbd>string</kbd> Server address.
- `port` <kbd>number</kbd> Server port.
- `on_disconnect(client)` <kbd>function</kbd> Callback will be called when client disconnected from server.
- `connector` <kbd>table</kbd> (_optional_)
- `parser` <kbd>table</kbd> (_optional_)

## Server Reference

### `server:start()`

Starts server object.

### `server:update()`

Must be called as often as possible.

### `server:stop()`

Stops server object.

## Client Reference

### `client.event`

Event object.

### `client.rpc`

RPC object.

### `client.shared`

Shared object.

### `client:connect()`

Connect client to server.

### `client:update()`

Must be called as often as possible.

### `client:disconnect()`

Disconnect client from server.

## Event Reference

### `event:fire(type[, data])`

Sends event to the other side.

**Parameters**

- `type` <kbd>string</kbd> Event type.
- `data` <kbd>table</kbd> (_optional_) Event data.

### `event:set_listener([type,] listener)`

Set event listener.

**Parameters**

- `type` <kbd>string</kbd> (_optional_) Event type. If nil, listener will catch all events (_all type).
- `listener(type, data)` <kbd>function</kbd> Listener that catch events.

### `event:remove_listener([type,] listener)`

Removes event listener.

**Parameters**

- `type` <kbd>string</kbd> (_optional_) Event type. If nil type will be "_all".
- `listener(type, data)` <kbd>function</kbd> Listener that was registered by set_listener.

## RPC Reference

### `rpc:set_enviroment(enviroment)`

Set enviroment for all incoming rpc.

**Parameters**

- `enviroment` <kbd>table</kbd> Enviroment table.

### `rpc:call(method, args, on_result)`

Call method by name.

**Parameters**

- `method` <kbd>string</kbd> Method name.
- `args` <kbd>table</kbd> Table with method arguments.
- `on_result(res1, res2, ...)` <kbd>function</kbd> Result callback. Takes all the arguments returned by the method.

### `rpc:execute(fn, args, on_result)`

Execute function on the other side.

**Parameters**

- `fn` <kbd>function</kbd> Function to be executed on the other side.
- `args` <kbd>table</kbd> Table with method arguments.
- `on_result(res1, res2, ...)` <kbd>function</kbd> Result callback. Takes all the arguments returned by the function.

## Shared Reference

### `shared:create(tbl)`

Returns new shared table.

**Parameters**

- `tbl` <kbd>table</kbd> Table to be synchronized between server and client.

### `shared.set_options(shared_table, options)`

Set options to shared table

**Parameters**

- `shared_table` <kbd>table</kbd> Shared table.
- `options` <kbd>table</kbd> Options table.

**Options**
- `del_access` <kbd>string</kbd> Who can delete a table. Can be "server", "client" or "both".
- `rights` <kbd>table</kbd> (_optional_) Table that describes who can change fields. Format is {field_name=rights}. Rights can be "server", "client" or "both". If the field does not have a rule, it will not be synced.
- `on_update(shared_table, fields)` <kbd>function</kbd> (_optional_) This function will be called when the other side changes the data in the table.
- `sync_rules` <kbd>table</kbd> (_optional_) Table that describes when the fields are synchronized. Format is {field_name=rule}. Rule can be "delta", "full" or "both". Default is "both".

### `shared:add(shared_table[, options])`

Synchronize shared table between server and client.

**Parameters**

- `shared_table` <kbd>table</kbd> Shared table.
- `options` <kbd>table</kbd> (_optional_) Options table.

### `shared:remove(shared_table)`

Removes shared table.

**Parameters**

- `shared_table` <kbd>table</kbd> Table that was be synchronized between server and client.

### `shared:set_add_listener(listener)`

Set listener that will be called when other side adds a shared table.

**Parameters**

- `listener(shared_table)` <kbd>function</kbd> Function.

### `shared:set_remove_listener(listener)`

Set listener that will be called when other side removes a shared table.

**Parameters**

- `listener(shared_table)` <kbd>function</kbd> Function.

### `shared:set_update_listener(shared_table, listener)`

Set listener that will be called when the other side changes the data in the shared table.

**Parameters**

- `shared_table` <kbd>table</kbd> Shared table.
- `listener(shared_table, fields)` <kbd>function</kbd> Function.

### `shared:delta_sync()`

Sync changed data in shared tables.

### `shared:full_sync()`

Sync all data in shared tables.

## Issues and suggestions

If you have any issues, questions or suggestions please [create an issue](https://github.com/Laminariy/defbit/issues).

You can also find me in [VK](https://vk.com/glorius_silver).
