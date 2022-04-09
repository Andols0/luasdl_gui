-- The table for RW ops
local SDL = require("SDL")
local reader    = { }

function reader.size()
	--print("asksize", #reader.data)
	return #reader.data
end

function reader.read(n, size)
	--print("read", "offset", reader.offset, "n & size", n,size)
	local r = reader.data:sub(reader.offset,reader.offset + n*size-1)
	reader.offset = reader.offset + n * size
	if not r then
		return nil, 0
	end
	--print("Readreturn", r, #r)
	return r, #r
end

function reader.write(data, n, size)
	--print("Writing",#data, n, size)
	reader.data = data
	reader.offset = 1
	if not (n or size) then
		return #reader.data
	else
		n = n or 1
		size = size or 1
		return n * size
	end
end

function reader.seek(offset, whence)
	local v = nil
	--print("seek",offset, whence)
	if whence == SDL.rwopsSeek.Set then
		--print("Set")
		reader.offset = offset+1
	elseif whence == SDL.rwopsSeek.Current then
		--print("Current")
	elseif whence == SDL.rwopsSeek.End then
		--print("End")
		reader.offset = #reader.data - (offset +1 )
	end

	--print("seekreturn", reader.offset-1)
	--print("Realoffset", reader.offset)
	return reader.offset-1
end

function reader.close()

end

return SDL.RWCreate(reader)