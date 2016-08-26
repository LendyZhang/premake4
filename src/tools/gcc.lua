--
-- gcc.lua
-- Provides GCC-specific configuration strings.
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--


	premake.gcc = { }


--
-- Set default tools
--

	premake.gcc.cc     = "gcc"
	premake.gcc.cxx    = "g++"
	premake.gcc.ar     = "ar"


--
-- Translation of Premake flags into GCC flags
--

	local cflags =
	{
		EnableSSE        = "-msse -mfpmath=sse",
		EnableSSE2       = "-msse2 -mfpmath=sse",
		EnableSSE4       = "-msse4",
		EnableNEON       = "-march=armv7-a -mfloat-abi=softfp -mfpu=neon",
		ExtraWarnings    = "-Wall -Wextra",
		FatalWarnings    = "-Werror",
		FloatFast        = "-ffast-math",
		FloatStrict      = "-ffloat-store",
		LinkTimeOptimize = "-flto",
		NoFramePointer   = "-fomit-frame-pointer",
		Optimize         = "-O2",
		OptimizeSize     = "-Os",
		OptimizeSpeed    = "-O3",
		OptimizeFull     = "-Ofast",
		Symbols          = "-g",
	}

	local cxxflags =
	{
		NoExceptions     = "-fno-exceptions",
		NoRTTI           = "-fno-rtti",
	}

	local cdialectflags =
	{
		["c89"]   = 1,
		["c99"]   = 1,
		["c11"]   = 1,
		["gnu89"] = 1,
		["gnu99"] = 1,
		["gnu11"] = 1,
	}

	local cxxdialectflags =
	{
		["c++98"]   = 1,
		["c++11"]   = 1,
		["c++14"]   = 1,
		["gnu++98"] = 1,
		["gnu++11"] = 1,
		["gnu++14"] = 1,
	}


--
-- Map platforms to flags
--

	premake.gcc.platforms =
	{
		Native = {
			cppflags = "-MMD",
		},
		x32 = {
			cppflags = "-MMD",
			flags    = "-m32",
			ldflags  = "-L/usr/lib32",
		},
		x64 = {
			cppflags = "-MMD",
			flags    = "-m64",
			ldflags  = "-L/usr/lib64",
		},
		Universal = {
			cppflags = "",
			flags    = "-arch i386 -arch x86_64 -arch ppc -arch ppc64",
		},
		Universal32 = {
			cppflags = "",
			flags    = "-arch i386 -arch ppc",
		},
		Universal64 = {
			cppflags = "",
			flags    = "-arch x86_64 -arch ppc64",
		},
		PS3 = {
			cc         = "ppu-lv2-g++",
			cxx        = "ppu-lv2-g++",
			ar         = "ppu-lv2-ar",
			cppflags   = "-MMD",
		},
		WiiDev = {
			cppflags    = "-MMD -MP -I$(LIBOGC_INC) $(MACHDEP)",
			ldflags		= "-L$(LIBOGC_LIB) $(MACHDEP)",
			cfgsettings = [[
  ifeq ($(strip $(DEVKITPPC)),)
    $(error "DEVKITPPC environment variable is not set")'
  endif
  include $(DEVKITPPC)/wii_rules']],
		},
	}

	local platforms = premake.gcc.platforms


--
-- Returns a list of compiler flags, based on the supplied configuration.
--

	function premake.gcc.getcppflags(cfg)
		local flags = { }
		table.insert(flags, platforms[cfg.platform].cppflags)

		-- We want the -MP flag for dependency generation (creates phony rules
		-- for headers, prevents make errors if file is later deleted), but
		-- Haiku doesn't support it (yet)
		if flags[1]:startswith("-MMD") and cfg.system ~= "haiku" then
			table.insert(flags, "-MP")
		end

		return flags
	end


	function premake.gcc.getcflags(cfg)
		local result = table.translate(cfg.flags, cflags)
		table.insert(result, platforms[cfg.platform].flags)

		-- Add C language dialect.
		if cfg.languagedialect ~= nil then
			local std = string.lower(cfg.languagedialect)
			if cdialectflags[std] ~= nil then
				table.insert(result, "-std=" .. std)
			end
		end

		if cfg.system ~= "windows" and cfg.kind == "SharedLib" then
			table.insert(result, "-fPIC")
		end
		return result
	end


	function premake.gcc.getcxxflags(cfg)
		local result = table.translate(cfg.flags, cxxflags)

		-- Add C++ language dialect.
		if cfg.languagedialect ~= nil then
			local std = string.lower(cfg.languagedialect)
			if cxxdialectflags[std] ~= nil then
				table.insert(result, "-std=" .. std)
			end
		end
		return result
	end


--
-- Returns a list of linker flags, based on the supplied configuration.
--

	function premake.gcc.getldflags(cfg)
		local result = { }

		-- OS X has a bug, see http://lists.apple.com/archives/Darwin-dev/2006/Sep/msg00084.html
		if not cfg.flags.Symbols then
			if cfg.system == "macosx" then
				table.insert(result, "-Wl,-x")
			else
				table.insert(result, "-s")
			end
		end

		if cfg.flags.EnableNEON then
			table.insert(result, "-march=armv7-a -Wl,--fix-cortex-a8")
		end

		if cfg.flags.LinkTimeOptimize then
			table.insert(result, "-flto")

			if cfg.flags.OptimizeFull then
				table.insert(result, cflags.OptimizeFull)
			elseif cfg.flags.OptimizeSpeed then
				table.insert(result, cflags.OptimizeSpeed)
			elseif cfg.flags.OptimizeSize then
				table.insert(result, cflags.OptimizeSize)
			elseif cfg.flags.Optimize then
				table.insert(result, cflags.Optimize)
			end
		end

		if cfg.kind == "SharedLib" then
			if cfg.system == "macosx" then
				table.insert(result, "-dynamiclib")
			else
				table.insert(result, "-shared")
			end

			if cfg.system == "windows" and not cfg.flags.NoImportLib then
				table.insert(result, '-Wl,--out-implib="' .. cfg.linktarget.fullpath .. '"')
			end
		end

		if cfg.kind == "WindowedApp" and cfg.system == "windows" then
			table.insert(result, "-mwindows")
		end

		local platform = platforms[cfg.platform]
		table.insert(result, platform.flags)
		table.insert(result, platform.ldflags)

		return result
	end


--
-- Return a list of library search paths. Technically part of LDFLAGS but need to
-- be separated because of the way Visual Studio calls GCC for the PS3. See bug
-- #1729227 for background on why library paths must be split.
--

	function premake.gcc.getlibdirflags(cfg)
		local result = { }
		for _, value in ipairs(premake.getlinks(cfg, "all", "directory")) do
			table.insert(result, '-L' .. _MAKE.esc(value))
		end
		return result
	end



--
-- This is poorly named: returns a list of linker flags for external 
-- (i.e. system, or non-sibling) libraries. See bug #1729227 for 
-- background on why the path must be split.
--

	function premake.gcc.getlinkflags(cfg)
		local result = {}
		for _, value in ipairs(premake.getlinks(cfg, "siblings", "basename")) do
			table.insert(result, '-l' .. _MAKE.esc(value))
		end
		for _, value in ipairs(premake.getlinks(cfg, "system", "name")) do
			if path.getextension(value) == ".framework" then
				table.insert(result, '-framework ' .. _MAKE.esc(path.getbasename(value)))
			else
				table.insert(result, '-l' .. _MAKE.esc(value))
			end
		end
		return result
	end



--
-- Decorate defines for the GCC command line.
--

	function premake.gcc.getdefines(defines)
		local result = { }
		for _,def in ipairs(defines) do
			table.insert(result, '-D' .. def)
		end
		return result
	end



--
-- Decorate include file search paths for the GCC command line.
--

	function premake.gcc.getincludedirs(includedirs)
		local result = { }
		for _,dir in ipairs(includedirs) do
			table.insert(result, "-I" .. _MAKE.esc(dir))
		end
		return result
	end


--
-- Return platform specific project and configuration level
-- makesettings blocks.
--

	function premake.gcc.getcfgsettings(cfg)
		return platforms[cfg.platform].cfgsettings
	end
