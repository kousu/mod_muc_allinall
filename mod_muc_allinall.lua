-- synchronize bookmarks (joined (MUC) chat rooms) to equal all public rooms on the server
-- private rooms are still allowed
-- "the server" is defined by muc_allinall_host:
-- For users on *this* module's containing host, the rooms on the component $muc_allinall_host
-- are queried and the users are joined to everything public returned.
--

-- TODO:
-- - [ ] Detect mod_allinall_host automagically (Conversations and Gajim can do it)

local modulemanager = require"core.modulemanager";
local usermanager = require"core.usermanager";

local jid_join = require"util.jid".join;
local jid_split = require "util.jid".split;

local st = require "util.stanza";

local mod_pep = module:depends("pep")

local host = module.host;

local muc_allinall_host = module:get_option("muc_allinall_host");
module:log("debug", "muc_allinall_host=%s", muc_allinall_host);

local muc_host = nil;

local XMLNS_BM2 = "urn:xmpp:bookmarks:1";
local XMLNS_XEP0060 = "http://jabber.org/protocol/pubsub";

local default_options = {
	["persist_items"] = true;
	["max_items"] = "max";
	["send_last_published_item"] = "never";
	["access_model"] = "whitelist";
};

local function get_current_bookmarks(jid, service)
	local ok, items = service:get_items(XMLNS_BM2, jid)
	if not ok then
		if items == "item-not-found" then
			return {}, nil;
		else
			return nil, items;
		end
	end
	return items or {};
end

local function update_bookmark(jid, service, room, bookmark)
	local ok, err = service:publish(XMLNS_BM2, jid, room, bookmark, default_options);
	if ok then
		module:log("debug", "found existing matching bookmark, updated")
	else
		module:log("error", "failed to update bookmarks: %s", err)
	end
end

local function find_matching_bookmark(storage, room)
	return storage[room];
end

local function inject_bookmark(jid, room, autojoin, name)
	module:log("debug", "Injecting bookmark for %s into %s", room, jid);
	local pep_service = mod_pep.get_pep_service(jid_split(jid))

	if not name then
		local bare, _, _ = jid_split(room)
		name = bare
	end

	local current, err = get_current_bookmarks(jid, pep_service);
	if err then
		module:log("error", "Could not retrieve existing bookmarks for %s: %s", jid, err);
		return;
	end
	local found = find_matching_bookmark(current, room)
	if found then
		local existing = found:get_child("conference", XMLNS_BM2);
		if autojoin ~= nil then
			existing.attr.autojoin = autojoin and "true" or "false"
		end
		if name ~= nil then
			-- do not change already configured names
			if not existing.attr.name then
				existing.attr.name = name
			end
		end
	else
		module:log("debug", "no existing bookmark found, adding new")
		found = st.stanza("item", { xmlns = XMLNS_XEP0060; id = room })
			:tag("conference", { xmlns = XMLNS_BM2; name = name; autojoin = autojoin and "true" or "false"; })
	end

	update_bookmark(jid, pep_service, room, found)
end

local function remove_bookmark(jid, room)
	local pep_service = mod_pep.get_pep_service(jid_split(jid))

	return pep_service:retract(XMLNS_BM2, jid, room, st.stanza("retract", { id = room }));
end

local function handle_muc_added(event)
	-- Add MUC to all members' bookmarks
	local room = event.room;
	module:log("info", "Adding new group chat %s to all member bookmarks...", room.jid);
	--module:log("debug", "muc_jid=%s, muc_name=%s, module.host=%s", room.jid, room.name, module.host);
	-- btw it's not safe to call usermanager.users during setup() 
	for username in usermanager.users(host) do
		--module:log("debug", "handle-muc-added: username=%s", username);
		local user_jid = username .. "@" .. module.host;
		--module:log("debug", "user_jid=%s, room.jid=%s, true, room.name=%s", user_jid, room.jid, room.name);
		inject_bookmark(user_jid, room.jid, true, room.name);
	end
end

local function handle_muc_removed(event)
	-- Remove MUC from all members' bookmarks
	local room = event.room;
	module:log("info", "Removing group chat %s from all member bookmarks...", room.jid);
	--module:log("debug", "muc_jid=%s, muc_name=%s, module.host=%s", room.jid, room.name, module.host);
	-- btw it's not safe to call usermanager.users during setup() 
	for username in usermanager.users(host) do
		--module:log("debug", "handle-muc-removed: username=%s", username);
		local user_jid = username .. "@" .. module.host;
		--module:log("debug", "user_jid=%s, room.jid=%s", user_jid, room.jid);
		remove_bookmark(user_jid, room.jid);
	end
end

module:hook("resource-bind", function(event)
	-- When a user connects, sync their bookmarks
	--if true then	return; end; -- DEBUG: for testing the inline handlers above in isolation
	local session = event.session;
	local user = session.username;
	local user_jid = jid_join(user, host);

	module:log("info", "Loading existing bookmarks for %s", user_jid);
	local pep_service = mod_pep.get_pep_service(jid_split(user_jid))
	local current, err = get_current_bookmarks(user_jid, pep_service);
	if err then
		module:log("error", "Could not retrieve existing bookmarks for %s: %s", user_jid, err);
		return;
	end

	module:log("info", "Syncing all rooms on %s to %s's bookmarks", muc_allinall_host, user_jid);

	-- TODO: figure out how to do a set difference
	-- because the removes should be current - complement(all_rooms())
	-- and the adds should be all_rooms() - current
	-- For now, this works, but it's doing unnecessary work (and risks mangling bookmarks needlessly)
	
	--module:log("info", "-------------------");
	for muc_jid, bookmark in pairs(current) do
		if type(muc_jid) ~= "number" then -- ignore redundant numeric keys.
			local _, _muc_host, _ = jid_split(muc_jid);
			--module:log("info", "Testing if should clear %s from %s's bookmarks", muc_jid, user_jid);
			if _muc_host == muc_allinall_host then
			local room = muc_host.get_room_from_jid(muc_jid)
				if not room or not room:get_hidden() then
 	 				--module:log("info", "Clearing %s from %s's bookmarks", muc_jid, user_jid);
					remove_bookmark(user_jid, muc_jid)
				end
			end
		end
	end

	--module:log("info", "-------------------");
	for room in muc_host.all_rooms() do
		local muc_jid, room_name = room.jid, room:get_name();
		--module:log("info", "Testing if should add %s to %s's bookmarks", muc_jid, user_jid);
		--add a bookmark if *not* a tombstone ("destroyed") and it's either public or the user is a member
		if not room._data.destroyed and (room:get_public() or room:get_affiliation(user_jid)) then
			--module:log("info", "Adding %s, %s, true, %s", user_jid, muc_jid, room_name);
			inject_bookmark(user_jid, muc_jid, true, room_name);
		end
	end

end);


local function setup()
	if not muc_allinall_host then
		module:log("info", "MUC management disabled (muc_allinall_host set to nil)");
		return;
	end

	local target_module = modulemanager.get_module(muc_allinall_host, "muc");
	if not target_module then
		module:log("error", "host %s is not a MUC host -- group management will not work correctly; check your muc_allinall_host setting!", muc_allinall_host);
	else
		muc_host = target_module;

		-- TODO: can these be global
		module:context(muc_allinall_host):hook("muc-room-created", handle_muc_added)
		module:context(muc_allinall_host):hook("muc-room-destroyed", handle_muc_removed)
	end
end

if prosody.start_time then  -- server already started
	setup();
else
	module:hook_global("server-started", setup);
end
