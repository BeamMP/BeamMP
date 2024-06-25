local M = {}

local ffi = require("ffi")

--- Receives a packet from the launcher, prefixed with a 4-byte binary header. Handles errors and partial receives.
-- Expects `recvState` to be a table of the format:
-- {
--	state = 'ready',
--	data = "",
--	missing = 0,
-- }
-- where state is:
--	'ready': ready to receive a new packet, data is contained within `data` if any
-- 	'partial': `partialData` contains data, we're missing `missing` bytes
-- 	'error': errorneous state
M.receive = function(launcherSocket, recvState)
	if recvState.state == 'ready' then
		local header, headerRecvStatus, partialHeader = launcherSocket:receive(4)
		if header == "" or (headerRecvStatus == 'timeout' and (partialHeader == nil or partialHeader == "")) then
			-- assume its ok?
			recvState.data = ""
			return recvState
		end
		if not header then
			-- error, either we failed to receive (lost connection), or we received a partial that was too
			-- small to be useful
			log('E', 'receive', 'Error: Failed to receive data: ' ..headerRecvStatus..', partial: "'..(partialHeader or "")..'"')
			recvState.state = 'error'
			return recvState
		end
		local len = ffi.cast("uint32_t*", ffi.new("char[?]", 4, header))[0]
		if not len then
			log('E', 'receive', 'Error: Failed to read header')
			recvState.state = 'error'
			return recvState
		end

		local fullBody, recvStatus, partialBody = launcherSocket:receive(len)
		if not fullBody then
			if recvStatus == 'timeout' then
				-- combine the previously received partial (if any) with this partial
				recvState.data = partialBody
				recvState.state = 'partial'
				recvState.missing = len - #partialBody
				log('W', 'receive', 'Partial receive, missing '..tostring(recvState.missing)..' bytes')
				dump(recvState)
				return recvState
			end

			-- error, either we failed to receive (lost connection), or we received a partial that was too
			-- small to be useful
			log('E', 'receive', 'Error: Failed to receive')
			recvState.state = 'error'
			return recvState
		end
		-- set ready again
		recvState.state = 'ready'
		recvState.data = fullBody
		recvState.missing = 0
	elseif recvState.state == 'partial' then
		-- in case of a partial receive previously, the state holds the previously received data.
		-- it also contains the expected number of bytes to read
		local fullBody, recvStatus, partialBody = launcherSocket:receive(recvState.missing)
		-- AGAIN partial, or just an error
		if not fullBody then
			if recvStatus == 'timeout' then
				-- combine the previously received partial (if any) with this partial
				recvState.data = recvState.data..(partialBody or "")
				recvState.state = 'partial'
				-- subtract what we've received now
				recvState.missing = recvState.missing - #partialBody
				log('W', 'receive', 'Partial receive AGAIN, missing '..tostring(recvState.missing)..' bytes')
				dump(recvState)
				return recvState
			end

			-- error, either we failed to receive (lost connection), or we received a partial that was too
			-- small to be useful
			log('E', 'receive', 'Error: Failed to receive')
			recvState.state = 'error'
			return recvState
		end
		-- finally received everything
		recvState.data = recvState.data..(partialBody or "")
		recvState.missing = 0
		recvState.state = 'ready'
	end
	return recvState
end

return M
