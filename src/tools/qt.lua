--
-- qt.lua
-- Interface for qt extension
-- 20170901, windows vs2010+
-- figo2080@gmail.com
--
	premake.qt = { }
	local qt = premake.qt

	function qt.extmatcher(fname, extension)
		local ext = path.getextension(fname):lower()
		return ext == extension
	end

	function qt.isuifile( fname )
	-- body
		return qt.extmatcher( fname, ".ui" )	
	end

	function qt.isqrcfile( fname )
	-- body
		return qt.extmatcher( fname, ".qrc" )
	end

	function qt.istsfile( fname )
	-- body
		return qt.extmatcher( fname, ".ts" )
	end

	function qt.isqobjectfile( prj, fname )
	-- body
		local isqobj = false
		if path.iscppheader(fname) then
			--because premake script in build director, fname relative to project directory
			local absfname = prj.location.."/"..fname
			--local relname = fname:sub(4)
			local file = io.open(absfname)
			if file ~= nil then
				for line in file:lines() do
					if line:find("^%s*Q_OBJECT%f[^%w_]") or line:find("^%s*Q_GADGET%f[^%w_]") then
						isqobj = true
						break
					end
				end
				io.close(file)
			else
				print("file no open:" .. fname )
			end
		end

		return isqobj
	end

	--add generated files to project
	function qt.addgeneratedfile( cfg, genfilename )
		table.insert( cfg.files, genfilename )
	end

	function qt.getgenerateddir( cfg )
		if cfg.custombuild_qtgendir ~= nil then
			return cfg.custombuild_qtgendir
		end

		if cfg.objdir ~= nil then
			return cfg.objdir
		end

		return "./"
	end

	-- type for generated files: "moc" or "qrc"
	function qt.getgeneratedfilename( generateddir, srcfilename, type )
		local newfile = {}
		local basename = path.getbasename(srcfilename)

		if type == "ui" then
			newfile.name  = generateddir.."/"..type.."_"..basename..".h"
			newfile.vpath = "GeneratedFiles/"..basename..".h"
		else
			newfile.name  = generateddir.."/"..type.."_"..basename..".cpp"
			newfile.vpath = "GeneratedFiles/"..basename..".cpp"
		end
		return newfile
	end

	-- Utility: print table function
	key = ""
	function qt.PrintTable(table , level)
	  level = level or 1
	  local indent = ""
	  for i = 1, level do
		indent = indent.."  "
	  end

	  if key ~= "" then
		print(indent..key.." ".."=".." ".."{")
	  else
		print(indent .. "{")
	  end

	  key = ""
	  for k,v in pairs(table) do
		 if type(v) == "table" then
			key = k
			PrintTable(v, level + 1)
		 else
			local content = string.format("%s%s = %s", indent .. "  ",tostring(k), tostring(v))
		  print(content)  
		  end
	  end
	  print(indent .. "}")

	end

	function qt.getbindir( cfg )
		if cfg.custombuild_qtbin ~= nil then
			return cfg.custombuild_qtbin
		end

		return "$(QTDIR)\\bin"
	end

	function qt.getgendir( cfg, fcfg )
		if cfg.custombuild_qtgendir ~= nil then
			return cfg.custombuild_qtgendir
		end

		if cfg.objdir ~= nil then
			return cfg.objdir
		end

		return  path.getdirectory(fcfg.name)
	end

	-- cfg: project config, fcfg: file config
	function qt.addmocbuildrule( cfg, fcfg )
		local fc = {}

		fc.basename = path.getbasename(fcfg.name)
		local gendir = qt.getgendir(cfg, fcfg)
		local bindir = qt.getbindir(cfg, fcfg)

		--local outputs = gendir.."/$(ConfigurationName)".."/moc_"..fc.basename..".cpp"
		local outputs = gendir.."/moc_"..fc.basename..".cpp"
		local command = bindir.."/moc \"%%(FullPath)\" -o \""..outputs.."\""

		-- if has precompiled header, prepend it ( -b or -f ? )
		if cfg.pchheader then
			command = command.." -b\""..cfg.pchheader.."\""
		end

		-- append the defines
		if #cfg.defines > 0 then
			for _, def in ipairs(cfg.defines) do
				command = command.." -D"..def
			end
		end

		-- append the include directories
		if #cfg.includedirs > 0 then
			for _, inc in ipairs(cfg.includedirs) do
				command = command.." -I\""..inc.."\""
			end
		end
		-- custom command
		fc.addtionalinputs	= "%%(AdditionalInputs)"
		fc.message			= "Moc%%27ing"..fcfg.name
		fc.command			= command
		fc.outputs			= outputs

		return fc
	end

	function qt.adduibuildrule( cfg, fcfg )
		local fc = {}

		fc.basename = path.getbasename(fcfg.name)

		local gendir = qt.getgendir(cfg, fcfg)
		local bindir = qt.getbindir(cfg, fcfg)

		local outputs = gendir.."/ui_"..fc.basename..".h"
		local command = bindir.."/uic -o \""..outputs.."\" \"%%(FullPath)\""
		
		fc.addtionalinputs	= "%%(AdditionalInputs)"
		fc.message			= "Qt Uic'ing"..fcfg.name
		fc.command			= command
		fc.outputs			= outputs

		return fc
	end

	function qt.addqrcbuildrule( cfg, fcfg )
		local fc = {}

		fc.basename = path.getbasename(fcfg.name)
		local gendir = qt.getgendir(cfg, fcfg)
		local bindir = qt.getbindir(cfg, fcfg)

		local outputs = gendir.."/qrc_"..fc.basename..".cpp"
		local command = bindir.."/rcc -name \"%%(Filename)\" -no-compress \"%%(FullPath)\" -o \""..outputs.."\""

		fc.addtionalinputs	= "%%(FullPath);%%(AdditionalInputs)"
		fc.message			= "Rcc%%27ing"..fcfg.name
		fc.command			= command
		fc.outputs			= outputs

		return fc
	end

	-- add qt custom build rule by section
	function qt.addcustombuildrule( cfg, fcfg, section )
		if section == "UI" then
			return qt.adduibuildrule( cfg, fcfg )
		elseif section == "QRC" then
			return qt.addqrcbuildrule( cfg, fcfg )
		elseif section == "QObject" then
			return qt.addmocbuildrule( cfg, fcfg )
		else
			print( "Error: Invalid custom rule group section"..section )
			return nil
		end
	end
