--#########################################################################################
-- TerraME - a software platform for multiple scale spatially-explicit dynamic modeling.
-- Copyright (C) 2001-2014 INPE and TerraLAB/UFOP -- www.terrame.org
--
-- This code is part of the TerraME framework.
-- This framework is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library.
--
-- The authors reassure the license terms regarding the warranties.
-- They specifically disclaim any warranties, including, but not limited to,
-- the implied warranties of merchantability and fitness for a particular purpose.
-- The framework provided hereunder is on an "as is" basis, and the authors have no
-- obligation to provide maintenance, support, updates, enhancements, or modifications.
-- In no event shall INPE and TerraLAB / UFOP be held liable to any party for direct,
-- indirect, special, incidental, or consequential damages arising out of the use
-- of this library and its documentation.
--
-- Authors: Pedro R. Andrade (pedro.andrade@inpe.br)
--#########################################################################################

local comboboxExamples
local comboboxModels
local comboboxPackages
local aboutButton
local configureButton
local dbButton
local docButton
local installLocalButton
local installButton
local quitButton
local runButton
local dialog
local oldState

local function disableAll()
	oldState = {
		[comboboxExamples] = comboboxExamples.enabled,
		[comboboxModels]   = comboboxModels.enabled,
		[dbButton]         = dbButton.enabled,
		[docButton]        = docButton.enabled,
		[configureButton]  = configureButton.enabled,
		[runButton]        = runButton.enabled
	}

	comboboxExamples.enabled   = false
	comboboxModels.enabled     = false
	comboboxPackages.enabled   = false
	aboutButton.enabled        = false
	configureButton.enabled    = false
	dbButton.enabled           = false
	docButton.enabled          = false
	installLocalButton.enabled = false
	installButton.enabled      = false
	quitButton.enabled         = false
	runButton.enabled          = false
end

local function enableAll()
	comboboxExamples.enabled = oldState[comboboxExamples]
	comboboxModels.enabled   = oldState[comboboxModels]
	configureButton.enabled  = oldState[configureButton]
	dbButton.enabled         = oldState[dbButton]
	docButton.enabled        = oldState[docButton]
	runButton.enabled        = oldState[runButton]

	comboboxPackages.enabled   = true
	aboutButton.enabled        = true
	installLocalButton.enabled = true
	installButton.enabled      = true
	quitButton.enabled         = true
end

local function buildComboboxPackages(default)
	local s = sessionInfo().separator
	comboboxPackages:clear()
	local pos = 0
	local index = 0
	local pkgDir = sessionInfo().path..s.."packages"
	forEachFile(pkgDir, function(file)
		if file == "luadoc" or not isDir(pkgDir..s..file) then return end
	
		qt.combobox_add_item(comboboxPackages, file)
	
		if file == default then
			index = pos
		else
			pos = pos + 1
		end
	end)
	return index
end

local function aboutButtonClicked()
	disableAll()
	local msg = "Package "..comboboxPackages.currentText
	local info = packageInfo(comboboxPackages.currentText)

	msg = msg.."\n\nVersion: "..tostring(info.version)
	msg = msg.."\n\nDate: "..tostring(info.date)
	msg = msg.."\n\nAuthors: "..tostring(info.authors)
	msg = msg.."\n\nContact: "..tostring(info.contact)

	if info.url then
		msg = msg.."\n\nURL: "..info.url
	end

	qt.dialog.msg_about(msg)
	enableAll()
end

local function docButtonClicked()
	disableAll()
	_Gtme.showDoc(comboboxPackages.currentText)
	enableAll()
end

local function dbButtonClicked()
	disableAll()
	local mysqlCheck = _Gtme.validateMySql()		
	if not (mysqlCheck == "") then
		qt.dialog.msg_critical(mysqlCheck)
		enableAll()
		return
	end		
		
	local files = _Gtme.sqlFiles(comboboxPackages.currentText)

	local msg = "The following databases will be imported:\n"
	_Gtme.forEachElement(files, function(_, value)
		local database = string.sub(value, 1, string.len(value) - 4)
		msg = msg.."- "..database.."\n"
	end)

	-- QMessageBox::StandardButton
	local ok = 1024
	local cancel = 4194304

	msg = msg.."\nConfirm installation?"
	if qt.dialog.msg_question(msg, "Confirm?", ok + cancel, cancel) == ok then
		local success = false

		while not success do
			if not _Gtme.buildConfig() then
				enableAll()
				return
			end

			local result = _Gtme.importDatabase(comboboxPackages.currentText)

			if result then
				qt.dialog.msg_critical("Error: "..result)
			else
				qt.dialog.msg_information("Databases sucessfully installed.")
				success = true
			end
		end
	end
	enableAll()
end

local function configureButtonClicked()
	disableAll()
	local msg = "terrame -package "..comboboxPackages.currentText..
	            " -configure "..comboboxModels.currentText
	os.execute(msg)
	enableAll()
end

local function runButtonClicked()
	disableAll()
	local msg = "terrame -package "..comboboxPackages.currentText..
	            " -example "..comboboxExamples.currentText
	os.execute(msg)
	enableAll()
end

-- what to do when a new package is selected
local function selectPackage()
	local s = sessionInfo().separator
	comboboxExamples:clear()
	comboboxModels:clear()

	local result = xpcall(function() getPackage(comboboxPackages.currentText) end, function(err)
		sessionInfo().fullTraceback = true
		local trace = _Gtme.traceback()
		local merr = "Error: Package '"..comboboxPackages.currentText.."' could not be loaded:\n\n"
			..err.."\n\n"..trace

		qt.dialog.msg_critical(merr)
	end)

	if not result then
		comboboxModels.enabled = false
		configureButton.enabled = false
		comboboxExamples.enabled = false
		runButton.enabled = false
		dbButton.enabled = false
		docButton.enabled = false
		return
	end

	local docpath = packageInfo(comboboxPackages.currentText).path
	docpath = docpath..s.."doc"..s.."index.html"

	docButton.enabled = isFile(docpath)

	local models = _Gtme.findModels(comboboxPackages.currentText)

	comboboxModels.enabled = #models > 1
	configureButton.enabled = #models > 0

	forEachElement(models, function(_, value)
		qt.combobox_add_item(comboboxModels, value)
	end)

	local ex = _Gtme.findExamples(comboboxPackages.currentText)

	comboboxExamples.enabled = #ex > 1
	runButton.enabled = #ex > 0

	forEachElement(ex, function(_, value)
		qt.combobox_add_item(comboboxExamples, value)
	end)

	data = function() end

	if not pcall(function() dofile(_Gtme.packageInfo(comboboxPackages.currentText).path..s.."data.lua") end) then
		dbButton.enabled = false
	else
		local files = _Gtme.sqlFiles(comboboxPackages.currentText)
		dbButton.enabled = #files > 0
	end
end

local function installButtonClicked()
	disableAll()

	local pkgs = _Gtme.downloadPackagesList()

	if getn(pkgs) == 0 then
		local msg = "Could not download the packages list. "..
		            "Please verify your internet connection and try again. "..
		            "If it still does not work, close and open TerraME again."
		qt.dialog.msg_critical(msg)
		enableAll()
		return
	end

	local pkgsTab = {}

	local dialog = qt.new_qobject(qt.meta.QDialog)
	dialog.windowTitle = "Download and install package"

	local externalLayout = qt.new_qobject(qt.meta.QVBoxLayout)

	qt.ui.layout_add(dialog, externalLayout)

	local listPackages = qt.new_qobject(qt.meta.QListWidget)

	local count = 0
	forEachOrderedElement(pkgs, function(idx)
		local sep = string.find(idx, "_")
		local package = string.sub(idx, 1, sep - 1)
		local version = string.sub(idx, sep + 1, string.find(idx, "zip") - 2)

		pkgsTab[count] = {file = idx, newversion = true}

		local ok, info = pcall(function() return packageInfo(package) end)

		if ok then
        	if _Gtme.verifyVersionDependency(info.version, ">=", version) then
				package = package.." (already installed)"
				pkgsTab[count].newversion = false
			else
				package = package.." (version "..version.." available)"
			end
		end

		count = count + 1
		qt.listwidget_add_item(listPackages, package)
	end)

	local installButton = qt.new_qobject(qt.meta.QPushButton)
	installButton.text = "Install"
	qt.connect(installButton, "clicked()", function()
		local tmpfolder = tmpDir()
		local cdir = currentDir()

		_Gtme.chDir(tmpfolder)

		local pkgfile = pkgsTab[listPackages.currentRow].file
		local installed = {}

		local installRecursive

		installRecursive = function(pkgfile)
			_Gtme.print("Downloading "..pkgfile)
			_Gtme.downloadPackage(pkgfile)
			_Gtme.print("Installing "..pkgfile)
			local package = string.sub(pkgfile, 1, string.find(pkgfile, "_") - 1)

    		os.execute("unzip -oq \""..pkgfile.."\"")

    		_Gtme.print("Verifying dependencies")

    		local pinfo = packageInfo(package)
    		local result = true

    		if pinfo.tdepends then
		    	forEachElement(pinfo.tdepends, function(_, dtable)
					if dtable.package == "terrame" or dtable.package == "base" then return end

					_Gtme.print("Package depends on "..dtable.package)
		    	    local isInstalled = pcall(function() packageInfo(dtable.package) end)

					if not isInstalled then
						forEachElement(pkgs, function(idx)
							if string.match(idx, dtable.package.."_") then
								installRecursive(idx)
								installed[dtable.package] = true
								return false
							end
						end)
					end
				end)
			end

			local result = _Gtme.installPackage(pkgfile)
			return result
		end

		local result = installRecursive(pkgfile)
		local package = string.sub(pkgfile, 1, string.find(pkgfile, "_") - 1)

		if result then
			msg = "Package '"..package.."' successfully installed."

			print(_Gtme.getn(installed))

			if _Gtme.getn(installed) == 1 then
				msg = msg.." One additional dependency package was installed:"
			elseif _Gtme.getn(installed) > 1 then
				msg = msg.." Additional dependency packages were installed:"
			end

			if _Gtme.getn(installed) > 0 then
				forEachOrderedElement(installed, function(idx)
					msg = msg.."\n- "..idx
				end)
			end

			qt.dialog.msg_information(msg)

			local index = buildComboboxPackages(package)
			comboboxPackages:setCurrentIndex(index)
			selectPackage()
			disableAll()
		else
			qt.dialog.msg_critical("Package '"..package.."' could not be installed.")
		end

		os.execute("rm -f \""..pkgfile.."\"")

		_Gtme.chDir(cdir)
		os.execute("rm -rf \""..tmpfolder.."\"")
		dialog:done(0)
	end)

	local cancelButton = qt.new_qobject(qt.meta.QPushButton)
	cancelButton.text = "Cancel"
	qt.connect(cancelButton, "clicked()", function()
		dialog:done(0)
	end)

	qt.connect(listPackages, "itemClicked(QListWidgetItem*)", function()
		installButton.enabled = pkgsTab[listPackages.currentRow].newversion
	end)

	qt.ui.layout_add(externalLayout, listPackages)
	qt.ui.layout_add(externalLayout, installButton)
	qt.ui.layout_add(externalLayout, cancelButton)

	dialog:show()
	dialog:exec()
	enableAll()
end
	
local function installLocalButtonClicked()
	disableAll()
	local s = sessionInfo().separator
	local fname = qt.dialog.get_open_filename("Select Package", "", "*.zip")
	if fname == "" then
		enableAll()
		return
	end

	local file = _Gtme.makePathCompatibleToAllOS(fname)
	local _, pfile = string.match(file, "(.-)([^/]-([^%.]+))$") -- remove path from the file
	local package

	local result = xpcall(function() package = string.sub(pfile, 1, string.find(pfile, "_") - 1) end, function(err)
		qt.dialog.msg_information(file.." is not a valid file name for a TerraME package.")
	end)

	if not package then
		enableAll()
		return
	end

	local currentVersion
	local packageDir = _Gtme.sessionInfo().path..s.."packages"
	if isDir(packageDir..s..package) then
		currentVersion = packageInfo(package).version
		_Gtme.printNote("Package '"..package.."' is already installed")
	else
		_Gtme.printNote("Package '"..package.."' was not installed before")
	end

	local tmpfolder = tmpDir()

	os.execute("cp \""..file.."\" \""..tmpfolder.."\"")
	_Gtme.chDir(tmpfolder)

	os.execute("unzip -oq \""..file.."\"")

	local newVersion = _Gtme.include(package..s.."description.lua").version

	if currentVersion then
		if not _Gtme.verifyVersionDependency(newVersion, ">=", currentVersion) then
			local msg = "New version ("..newVersion..") is older than current one ("
				..currentVersion..").".."\nDo you really want to install "
				.."an older version of package '"..package.."'?"
			local ok = 1024
			local cancel = 4194304

			if qt.dialog.msg_question(msg, "Confirm?", ok + cancel, cancel) == ok then
				_Gtme.printNote("Removing previous version of package")
				os.execute("rm -rf \""..packageDir..s..package.."\"")
			else
				os.execute("rm -rf \""..tmpfolder.."\"")
				enableAll()
				return
			end
		end
	end

	local pkg = xpcall(function() _Gtme.installPackage(fname) end, function(err)
		qt.dialog.msg_critical("File "..fname.." could not be installed:\n"..err)
	end)

	if pkg then
		local ok = true
		xpcall(function() getPackage(package) end, function(err)
			os.execute("rm -rf \""..packageInfo(package).path.."\"")
			qt.dialog.msg_critical(err)
			ok = false
		end)


		if ok then
			qt.dialog.msg_information("Package '"..package.."' successfully installed.")
			local index = buildComboboxPackages(package)
			comboboxPackages:setCurrentIndex(index)
			selectPackage()
			disableAll()
		end
	end

	enableAll()
end

local function quitButtonClicked()
	dialog:done(0)
end

function _Gtme.packageManager()
	require("qtluae")

	dialog = qt.new_qobject(qt.meta.QDialog)
	dialog.windowTitle = "TerraME"

	local externalLayout = qt.new_qobject(qt.meta.QVBoxLayout)
	local internalLayout = qt.new_qobject(qt.meta.QGridLayout)
	internalLayout.spacing = 8

	qt.ui.layout_add(dialog, externalLayout)

	comboboxPackages = qt.new_qobject(qt.meta.QComboBox)

	aboutButton = qt.new_qobject(qt.meta.QPushButton)
	aboutButton.text = "About"
	qt.connect(aboutButton, "clicked()", aboutButtonClicked)

	docButton = qt.new_qobject(qt.meta.QPushButton)
	docButton.text = "Documentation"
	qt.connect(docButton, "clicked()", docButtonClicked)

	dbButton = qt.new_qobject(qt.meta.QPushButton)
	dbButton.text = "Databases"
	qt.connect(dbButton, "clicked()", dbButtonClicked)

	label = qt.new_qobject(qt.meta.QLabel)
	label.text = "Package:"
	qt.ui.layout_add(internalLayout, label,            0, 0)
	qt.ui.layout_add(internalLayout, comboboxPackages, 0, 1)
	qt.ui.layout_add(internalLayout, aboutButton,      0, 2)
	qt.ui.layout_add(internalLayout, docButton,        0, 3)
	qt.ui.layout_add(internalLayout, dbButton,         0, 4)

	-- models list + execute button
	comboboxModels = qt.new_qobject(qt.meta.QComboBox)

	label = qt.new_qobject(qt.meta.QLabel)
	label.text = "Model:"

	configureButton = qt.new_qobject(qt.meta.QPushButton)
	configureButton.text = "Configure"
	qt.connect(configureButton, "clicked()", configureButtonClicked)

	qt.ui.layout_add(internalLayout, label,           1, 0)
	qt.ui.layout_add(internalLayout, comboboxModels,  1, 1)
	qt.ui.layout_add(internalLayout, configureButton, 1, 2)

	-- examples list + execute button
	comboboxExamples = qt.new_qobject(qt.meta.QComboBox)

	label = qt.new_qobject(qt.meta.QLabel)
	label.text = "Example:"

	runButton = qt.new_qobject(qt.meta.QPushButton)
	runButton.text = "Run"
	qt.connect(runButton, "clicked()", runButtonClicked)

	qt.ui.layout_add(internalLayout, label,            2, 0)
	qt.ui.layout_add(internalLayout, comboboxExamples, 2, 1)
	qt.ui.layout_add(internalLayout, runButton,        2, 2)

	local index = buildComboboxPackages("base")
	comboboxPackages:setCurrentIndex(index)

	qt.connect(comboboxPackages, "activated(int)", selectPackage)

	buttonsLayout = qt.new_qobject(qt.meta.QHBoxLayout)

	installButton = qt.new_qobject(qt.meta.QPushButton)
	installButton.minimumSize = {150, 28}
	installButton.maximumSize = {160, 28}
	installButton.text = "Install package"
	qt.ui.layout_add(buttonsLayout, installButton)

	qt.connect(installButton, "clicked()", installButtonClicked)

	installLocalButton = qt.new_qobject(qt.meta.QPushButton)
	installLocalButton.minimumSize = {150, 28}
	installLocalButton.maximumSize = {160, 28}
	installLocalButton.text = "Install local package"
	qt.ui.layout_add(buttonsLayout, installLocalButton)

	qt.connect(installLocalButton, "clicked()", installLocalButtonClicked)

	quitButton = qt.new_qobject(qt.meta.QPushButton)
	quitButton.minimumSize = {100, 28}
	quitButton.maximumSize = {110, 28}
	quitButton.text = "Quit"
	qt.ui.layout_add(buttonsLayout, quitButton)

	qt.connect(quitButton, "clicked()", quitButtonClicked)

	qt.ui.layout_add(externalLayout, internalLayout)
	qt.ui.layout_add(externalLayout, buttonsLayout, 3, 0)

	selectPackage()
	dialog:show()
	local result = dialog:exec()
end

