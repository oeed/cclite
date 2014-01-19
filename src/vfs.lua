-- Virtal FileSystem for Love2D by Gamax92
-- Adapted from an older private project of mine

local mountTable = {}
vfs = {}
function vfs.normalize(path)
	-- Borrowed from ComputerCraft
	path = "/" .. path
	local tPath = {}
	for part in path:gmatch("[^/]+") do
   		if part ~= "" and part ~= "." then
   			if part == ".." and #tPath > 0 then
   				table.remove(tPath)
   			else
   				table.insert(tPath, part)
   			end
   		end
	end
	return "/" .. table.concat(tPath, "/")
end
function vfs.fake2real(path)
	path = vfs.normalize(path)
	local base
	for i = 1,#mountTable do
		if (path == mountTable[i][2] or path:sub(1,#mountTable[i][2]+1) == mountTable[i][2] .. "/" or (mountTable[i][2] == "/" and path:sub(1,#mountTable[i][2]) == mountTable[i][2])) and (base == nil or #mountTable[i][2] > #mountTable[base][2]) then
			base = i
		end
	end
	if base == nil then
		error("Please mount / first before using vfs",3)
	end
	return mountTable[base][1] .. (mountTable[base][2] == "/" and path or path:sub(#mountTable[base][2]+1))
end
local quickPatch = {"append","createDirectory","isFile","lines","load","newFile","read","remove","write"}
for i = 1,#quickPatch do
	vfs[quickPatch[i]] = function(path,...)
		return love.filesystem[quickPatch[i]](vfs.fake2real(path),...) -- I don't think this works.
	end
end
local copyOver = {"getAppdataDirectory","getIdentity","getSaveDirectory","getUserDirectory","getWorkingDirectory","isFused","setIdentity","setSource"}
for i = 1,#copyOver do
	vfs[copyOver[i]] = love.filesystem[copyOver[i]]
end
function vfs.exists(filename)
	filename = vfs.normalize(filename)
	for i = 1,#mountTable do
		if mountTable[i][2] == filename then
			return true
		end
	end
	return love.filesystem.isDirectory(vfs.fake2real(filename))
end
function vfs.getDirectoryItems(dir)
	local result = love.filesystem.getDirectoryItems(vfs.fake2real(dir))
	-- TODO: Inject mount points into results
	return result
end
function vfs.getLastModified(filename)
	local filename = vfs.normalize(filename)
	for i = 1,#mountTable do
		if mountTable[i][2] == filename then
			return mountTable[i][3]
		end
	end
	return love.filesystem.getLastModifed(vfs.fake2real(filename))
end
function vfs.getSize(filename)
	-- TODO: This most likely should report an error if the path is a mount path
	-- But Love2D crashes on directories so I can't get an example.
	return love.filesystem.getSize(vfs.fake2real(filename))
end
vfs.init = function() end -- love.filesystem.init -- Don't call this, EVER
function vfs.isDirectory(filename)
	filename = vfs.normalize(filename)
	for i = 1,#mountTable do
		if mountTable[i][2] == filename then
			return true
		end
	end
	return love.filesystem.isDirectory(vfs.fake2real(filename))
end
vfs.fsmount = love.filesystem.mount
function vfs.mount(realPath,fakePath) -- Not the same as love.filesystem.mount
	table.insert(mountTable,{vfs.normalize(realPath),vfs.normalize(fakePath),os.time()}) -- TODO: os.time() doesn't guarentee unix epoch time.
end
function vfs.newFileData(contents,name,decoder)
	if name == nil and decoder == nil then
		return love.filesystem.newFileData(contents,name,decoder)
	end
	return love.filesystem.newFileData(vfs.fake2real(contents))
end
vfs.fsunmount = love.filesystem.unmount
function vfs.unmount(fakePath) -- Not the same as love.filesystem.unmount
	fakePath = vfs.normalize(fakePath)
	for i = 1,#mountTable do
		if mountTable[i][2] == fakePath then
			table.remove(mountTable,i)
			return true
		end
	end
	return false
end