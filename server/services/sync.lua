local sync = {}
local packets = require "packets"

function sync.init(g)
	g.onupdate:catch(sync.update)
end

function sync.update(g, dt)
	local world = g.world
	local socket = g.socket

	local genstate = g.genstate

  for _, e in pairs(world.entities) do

--		-- sync edits
--		local p_edits, p_edits_count = e:property_edits()
--		local t_edits, t_edits_count = e:tag_edits()
--
--		if p_edits_count > 0 or t_edits_count > 0 then
--			local packet = packets.entityremoteset(e.id, p_edits, t_edits)
--			e:clear_tag_edits()
--			e:clear_property_edits()
--
--			for _, p in ipairs(world:query("player")) do
--				if p.view:entity(e.id) then p.master:send(packet) end
--			end
--		end

		-- sync destroys
		if g.world:tagged(e, "destroyed") then
			for _, p in pairs(world:query("player")) do
				if p.view:entity(e.id) then 
					p.view:remove(e)
				end
			end
		end
  end

	-- remove destroyed entities
	for _, e in pairs(world:query("destroyed")) do
		world:remove(e)
	end
end

return sync
