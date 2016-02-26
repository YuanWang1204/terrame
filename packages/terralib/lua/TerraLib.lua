-------------------------------------------------------------------------------------------
-- TerraME - a software platform for multiple scale spatially-explicit dynamic modeling.
-- Copyright (C) 2001-2014 INPE and TerraLAB/UFOP.
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
-- indirect, special, incidental, or caonsequential damages arising out of the use
-- of this library and its documentation.
--
-- Authors: Pedro R. Andrade (pedro.andrade@inpe.br)
--          Rodrigo Avancini
-------------------------------------------------------------------------------------------

require("terralib_mod_binding_lua")

-- TODO: To document this

local binding = terralib_mod_binding_lua
local instance = nil
local initialized = false

local OperationMapper = {
	value = binding.VALUE_OPERATION,
	area = binding.PERCENT_TOTAL_AREA,
	presence = binding.PRESENCE,
	count = binding.COUNT,
	distance = binding.MIN_DISTANCE,
	minimum = binding.MIN_VALUE,
	maximum = binding.MAX_VALUE,
	percentage = binding.PERCENT_EACH_CLASS,
	stdev = binding.STANDARD_DEVIATION,
	mean = binding.MEAN,
	weighted = binding.WEIGHTED,
	intersection = binding.HIGHEST_INTERSECTION,
	occurrence = binding.HIGHEST_OCCURRENCE,
	sum = binding.SUM,
	wsum = binding.WEIGHTED_SUM
}

local VectorAttributeCreatedMapper = {
	presence = "presence",
	area = "percent_of_total_area",
	count = "total_values",
	distance = "min_distance",
	minimum = "min_val",
	maximum = "max_val",
	percentage = "percent_area_class",
	stdev = "stand_dev",
	mean = "mean",
	weighted = "weigh_area",
	intersection = "class_high_area",
	occurrence = "class_high_occurrence",
	sum = "sum_values",
	wsum = "weigh_sum_area" 
}

local RasterAttributeCreatedMapper = {
	mean = "_Mean",
	minimum = "_Min_Value",
	maximum = "_Max_Value",
	percentage = "",
	stdev = "_Standard_Deviation",
	sum = "_Sum"
}

local function hasConnectionError(type, connInfo)
	local ds = binding.te.da.DataSourceFactory.make(type)
	ds:setConnectionInfo(connInfo)
	local msg = binding.te.da.DataSource.Exists(ds)	
	
	ds = nil
	collectgarbage("collect")
	
	return msg
end

local function createPgConnInfo(host, port, user, pass, database, table, encoding)
	local connInfo = {}
	
	connInfo.PG_HOST = host 
	connInfo.PG_PORT = port 
	connInfo.PG_USER = user
	connInfo.PG_PASSWORD = pass
	connInfo.PG_DB_NAME = database
	connInfo.PG_NEWDB_NAME = table
	connInfo.PG_CONNECT_TIMEOUT = "4" 
	connInfo.PG_CLIENT_ENCODING = encoding -- "UTF-8" --"CP1252" -- "LATIN1" --"WIN1252" 	
	connInfo.PG_CHECK_DB_EXISTENCE = database		

	local errorMsg = hasConnectionError("POSTGIS", connInfo)	
	if errorMsg ~= "" then
		if string.match(errorMsg, "connections on port "..port) then
			errorMsg = "Please check the port '"..port.."'."
		end
		customError(errorMsg)
	end

	return connInfo
end

local function createFileConnInfo(filePath)
	local connInfo = {}
	connInfo.URI = filePath
	
	return connInfo
end

local function createAdoConnInfo(dbFilePath)
	local connInfo = {}
	--connInfo.PROVIDER = "Microsoft.Jet.OLEDB.4.0"
	connInfo.PROVIDER = "Microsoft.ACE.OLEDB.12.0" 
	connInfo.DB_NAME = dbFilePath
	connInfo.CREATE_OGC_METADATA_TABLES = "TRUE"	
	
	return connInfo
end

local function addDataSourceInfo(type, title, connInfo)
	local dsInfo = binding.te.da.DataSourceInfo()
	local dsId = binding.GetRandomicId()
		
	dsInfo:setId(dsId)
	dsInfo:setType(type)
	dsInfo:setAccessDriver(type)
	dsInfo:setTitle(title)
	dsInfo:setConnInfo(connInfo)
	dsInfo:setDescription("Created on TerraME")

	if not binding.te.da.DataSourceInfoManager.getInstance():add(dsInfo) then
		dsInfo = binding.te.da.DataSourceInfoManager.getInstance():getDsInfoByConnInfo(dsInfo:getConnInfoAsString())
	end
	
	return dsInfo:getId()
end

local function makeAndOpenDataSource(connInfo, type)
	local ds = binding.te.da.DataSourceFactory.make(type)

	ds:setConnectionInfo(connInfo) 
	ds:open()

	return ds	
end

local function createLayer(name, connInfo, type)
	local dsId = addDataSourceInfo(type, name, connInfo)	
	
	local ds = makeAndOpenDataSource(connInfo, type)
	ds:setId(dsId)
	
	binding.te.da.DataSourceManager.getInstance():insert(ds)
	
	local dSetType = nil
	local dSet = nil
	local dSetName = ""
	local env = nil
	local srid = 0

	if type == "OGR" then
		dSetName = getFileName(connInfo.URI)
		dSetType = ds:getDataSetType(dSetName)
		local gp = binding.GetFirstGeomProperty(dSetType)
		env = binding.te.gm.Envelope(binding.GetExtent(dSetType:getName(), gp:getName(), ds:getId()))
		srid = gp:getSRID()
	elseif type == "GDAL" then
		dSetName = getFileNameWithExtension(connInfo.URI)
		dSetType = ds:getDataSetType(dSetName)
		dSet = ds:getDataSet(dSetName)
		local rpos = binding.GetFirstPropertyPos(dSet, binding.RASTER_TYPE)
		local raster = dSet:getRaster(rpos)	
		env = raster:getExtent()
		srid = raster:getSRID()
	elseif type == "POSTGIS" then
		dSetName = connInfo.PG_NEWDB_NAME
		dSetType = ds:getDataSetType(dSetName)
		local gp = binding.GetFirstGeomProperty(dSetType)
		env = binding.te.gm.Envelope(binding.GetExtent(dSetType:getName(), gp:getName(), ds:getId()))
		srid = gp:getSRID()	
	end

	local id = binding.GetRandomicId()
	local layer = binding.te.map.DataSetLayer(id)
	
	layer:setDataSetName(dSetName)
	layer:setTitle(name)
	layer:setDataSourceId(ds:getId())
	layer:setExtent(env)
	layer:setVisibility(binding.VISIBLE)
	layer:setRendererType("ABSTRACT_LAYER_RENDERER")
	layer:setSRID(srid)

	binding.te.da.DataSourceManager.getInstance():detach(ds:getId())

	ds:close()
	ds = nil
	collectgarbage("collect")
	
	return layer
end

local function isValidTviewExt(filePath)
	return getFileExtension(filePath) == "tview"
end

local function releaseProject(project)
	local removed = {}
	for title, layer in pairs(project.layers) do
		local id = layer:getDataSourceId()

		if not removed[id] then
			binding.te.da.DataSourceInfoManager.getInstance():remove(id)
			removed[id] = id
		end

		collectgarbage("collect")
	end
end

local function saveProject(project, layers)
	local writer = binding.te.xml.AbstractWriterFactory.make()
	
	writer:setURI(project.file)

	-- TODO: THIS GET THE PATH WHERE WAS INSTALLED (PROBLEM)
	local schema = binding.FindInTerraLibPath("share/terralib/schemas/terralib/qt/af/project.xsd")
	schema = _Gtme.makePathCompatibleToAllOS(schema)

	writer:writeStartDocument("UTF-8", "no")

	writer:writeStartElement("Project")

	schema = string.gsub(schema, "%s", "%%20")
	
	writer:writeAttribute("xmlns:xsd", "http://www.w3.org/2001/XMLSchema-instance")
	writer:writeAttribute("xmlns:te_da", "http://www.terralib.org/schemas/dataaccess")
	writer:writeAttribute("xmlns:te_map", "http://www.terralib.org/schemas/maptools")
	writer:writeAttribute("xmlns:te_qt_af", "http://www.terralib.org/schemas/common/af")

	writer:writeAttribute("xmlns:se", "http://www.opengis.net/se")
	writer:writeAttribute("xmlns:ogc", "http://www.opengis.net/ogc")
	writer:writeAttribute("xmlns:xlink", "http://www.w3.org/1999/xlink")

	writer:writeAttribute("xmlns", "http://www.terralib.org/schemas/qt/af")
	writer:writeAttribute("xsd:schemaLocation", "http://www.terralib.org/schemas/qt/af "..schema)
	writer:writeAttribute("version", binding.te.common.Version.asString())

	writer:writeElement("Title", project.title)
	writer:writeElement("Author", project.author)
	
	writer:writeDataSourceList()
	
	writer:writeStartElement("ComponentList")
	writer:writeEndElement("ComponentList")

	writer:writeStartElement("te_map:LayerList")
	
	if layers then 
		local lserial = binding.te.map.serialize.Layer.getInstance()
		
		for title, layer in pairs(layers) do
			lserial:write(layer, writer)
		end
	end
	writer:writeEndElement("te_map:LayerList")

	writer:writeEndElement("Project")

	writer:writeToFile()
end

local function loadProject(project, file)		
	if not isFile(file) then
		customError("Could not read project file: "..file..".")
	end
	
	local xmlReader = binding.te.xml.ReaderFactory.make()

	xmlReader:setValidationScheme(false)
	xmlReader:read(file)
	
	if not xmlReader:next() then
		customError("Could not read project information in the file: "..file..".")
	end
	
	if xmlReader:getNodeType() ~= binding.START_ELEMENT then
		customError("Error reading the document "..file..", the start element wasn't found.")
	end
	
	if xmlReader:getElementLocalName() ~= "Project" then
		customError("The first tag in the document "..file.." is not 'Project'.")
	end	
	
	xmlReader:next()
	if xmlReader:getNodeType() ~= binding.START_ELEMENT then
		customError("PROJECT READ ERROR.")
	end
	if xmlReader:getElementLocalName() ~= "Title" then
		customError("PROJECT READ ERROR.")
	end

	xmlReader:next()
	if xmlReader:getNodeType() ~= binding.VALUE then
		customError("PROJECT READ ERROR.")
	end
	project.title = xmlReader:getElementValue()
	
	xmlReader:next() -- End element

	xmlReader:next()
	if xmlReader:getNodeType() ~= binding.START_ELEMENT then
		customError("PROJECT READ ERROR.")
	end
	if xmlReader:getElementLocalName() ~= "Author" then
		customError("PROJECT READ ERROR.")
	end

	xmlReader:next()

	if xmlReader:getNodeType() == binding.VALUE then
		project.author = xmlReader:getElementValue()
		xmlReader:next() -- End element
	end	

	-- read data source list from this project
	xmlReader:next()

	if xmlReader:getNodeType() ~= binding.START_ELEMENT then
		customError("PROJECT READ ERROR.")
	end
	if xmlReader:getElementLocalName() ~= "DataSourceList" then
		customError("PROJECT READ ERROR.")
	end

	xmlReader:next()

	-- DataSourceList contract form
	if (xmlReader:getNodeType() == binding.END_ELEMENT) and 
		(xmlReader:getElementLocalName() == "DataSourceList") then
		xmlReader:next()
	end

	while (xmlReader:getNodeType() == binding.START_ELEMENT) and
			(xmlReader:getElementLocalName() == "DataSource") do
		local  ds = binding.ReadDataSourceInfo(xmlReader)
		binding.te.da.DataSourceInfoManager.getInstance():add(ds)
	end
	
	-- end read data source list

	if xmlReader:getNodeType() ~= binding.START_ELEMENT then
		customError("PROJECT READ ERROR.")
	end
	if xmlReader:getElementLocalName() ~= "ComponentList" then
		customError("PROJECT READ ERROR.")
	end
	xmlReader:next() -- End element
	xmlReader:next() -- next after </ComponentList>

	if xmlReader:getNodeType() ~= binding.START_ELEMENT then
		customError("PROJECT READ ERROR.")
	end
	if xmlReader:getElementLocalName() ~= "LayerList" then
		customError("PROJECT READ ERROR.")
	end

	xmlReader:next()

	local lserial = binding.te.map.serialize.Layer.getInstance()
	
	-- Read the layers
	while (xmlReader:getNodeType() ~= binding.END_ELEMENT) and
			(xmlReader:getElementLocalName() ~= "LayerList") do
		local layer = lserial:read(xmlReader)
		
		if not layer then
			customError("PROJECT READ ERROR.")
		end
		
		project.layers[layer:getTitle()] = layer
	end
	
	if xmlReader:getNodeType() ~= binding.END_ELEMENT then
		customError("PROJECT READ ERROR.")
	end
	if xmlReader:getElementLocalName() ~= "LayerList" then
		customError("PROJECT READ ERROR.")
	end

	xmlReader:next()
	if not ((xmlReader:getNodeType() == binding.END_ELEMENT) or
		(xmlReader:getNodeType() == binding.END_DOCUMENT)) then
		customError("PROJECT READ ERROR.")
	end
	if xmlReader:getElementLocalName() ~= "Project" then
		customError("PROJECT READ ERROR.")
	end	
	
	-- TODO: THE ONLY WAY SO FAR TO RELEASE THE FILE AFTER READ
	-- WAS READ ANOTHER FILE (REVIEW)
	-- #880
	xmlReader:read(filePath("YgDbLUDrqQbvu7QxTYxX.xml", "terralib"))
end

local function addFileLayer(project, name, filePath, type)
	local connInfo = createFileConnInfo(filePath)
	
	loadProject(project, project.file)
	
	local layer = createLayer(name, connInfo, type)
	
	project.layers[layer:getTitle()] = layer
	saveProject(project, project.layers)
	releaseProject(project)
end

local function dataSetExists(connInfo, type)
	local ds = nil
	local dSetName = ""
	
	if type == "POSTGIS" then
		ds = makeAndOpenDataSource(connInfo, "POSTGIS")
		dSetName = string.lower(connInfo.PG_NEWDB_NAME)
	end
	
	local exists = ds:dataSetExists(dSetName)
	
	ds:close()
	ds = nil
	collectgarbage("collect")
	
	return exists
end

local function propertyExists(connInfo, property, type)
	local ds = makeAndOpenDataSource(connInfo, type)
	local dSetName = ""
	
	if type == "POSTGIS" then
		dSetName = string.lower(connInfo.PG_NEWDB_NAME)
	elseif type == "OGR" then
		dSetName = getFileName(connInfo.URI)
	elseif type == "GDAL" then
		dSetName = getFileNameWithExtension(connInfo.URI)
		local dSet = ds:getDataSet(dSetName)
		local rpos = binding.GetFirstPropertyPos(dSet, binding.RASTER_TYPE)
		local raster = dSet:getRaster(rpos)	
		local numBands = raster:getNumberOfBands()
		return (property >= 0) and (property < numBands)
	end
	
	local exists = ds:propertyExists(dSetName, property)
	
	ds:close()
	ds = nil
	collectgarbage("collect")
	
	return exists
end

local function dropDataSet(connInfo, type)
	local ds = nil
	local dSetName = ""
	
	if type == "POSTGIS" then
		ds = makeAndOpenDataSource(connInfo, "POSTGIS")
		dSetName = string.lower(connInfo.PG_NEWDB_NAME)
	elseif type == "OGR" then
		ds = makeAndOpenDataSource(connInfo, "OGR")
		dSetName = getFileName(connInfo.URI)
	end
	
	local tableExists = ds:dataSetExists(dSetName)
	if tableExists then
		ds:dropDataSet(dSetName)
	end	
	
	ds:close()
	ds = nil
	collectgarbage("collect")
end

local function copyLayer(from, to)
	local fromDsId = from:getDataSourceId()
	local fromDs = binding.GetDs(fromDsId, true)	
	
	from = binding.te.map.DataSetLayer.toDataSetLayer(from)	
	local dSetName = from:getDataSetName()
	
	local toDs = nil
		
	if to.type == "POSTGIS" then
		to.table = dSetName
		local toConnInfo = createPgConnInfo(to.host, to.port, to.user, to.password, to.database, to.table, to.encoding)	
		local toTable = string.lower(to.table)	
		local toDb = string.lower(to.database)	
		-- TODO: IT IS NOT POSSIBLE CREATE A DATABASE (REVIEW)
		--toConnInfo.PG_CHECK_DB_EXISTENCE = toDb		
		--print(binding.te.da.DataSource.exists("POSTGIS", toConnInfo))
		--local exists = binding.te.da.DataSource.exists("POSTGIS", toConnInfo)
		-- if exists then
			-- toConnInfo.PG_DB_TO_DROP = string.lower(to.dbName)	
			-- binding.te.da.DataSource.drop("POSTGIS", toConnInfo)	
		-- end		
		toDs = makeAndOpenDataSource(toConnInfo, "POSTGIS")
			
		local tableExists = toDs:dataSetExists(toTable)
		if tableExists then
			toDs:dropDataSet(toTable)
		end
	elseif to.type == "ADO" then
		local toConnInfo = createAdoConnInfo(to.file)
		-- TODO: ADO DON'T WORK (REVIEW)
		toDs = makeAndOpenDataSource(toConnInfo, "ADO") --binding.te.da.DataSource.create("ADO", toConnInfo)
		-- local tableExists = toDs:dataSetExists(toTable)
		-- if tableExists then
			-- toDs:dropDataSet(toTable)
		-- end		
		--fromDs:moveFirst()
	end
		
	local fromDSetType = fromDs:getDataSetType(dSetName)
	local fromDSet = fromDs:getDataSet(dSetName)
		
	binding.Create(toDs, fromDSetType, fromDSet)
			
	fromDSetType = nil
	fromDSet = nil
	fromDs:close()
	fromDs = nil
	toDs:close()
	toDs = nil
	collectgarbage("collect")	
end

local function createCellSpaceLayer(inputLayer, name, resolultion, connInfo, type) 
	local cLId = binding.GetRandomicId()
	local cellLayerInfo = binding.te.da.DataSourceInfo()
		
	cellLayerInfo:setConnInfo(connInfo)
	cellLayerInfo:setType(type)
	cellLayerInfo:setAccessDriver(type)
	cellLayerInfo:setId(cLId)
	cellLayerInfo:setTitle(name)
	cellLayerInfo:setDescription("Created on TerraME")
	
		
	local cellSpaceOpts = binding.te.cellspace.CellularSpacesOperations()
	local cLType = binding.te.cellspace.CellularSpacesOperations.CELLSPACE_POLYGONS
	
	local cellName = ""
	if type == "OGR" then
		cellName = getFileName(connInfo.URI)
	elseif type == "POSTGIS" then
		cellName = connInfo.PG_NEWDB_NAME
	end

	cellSpaceOpts:createCellSpace(cellLayerInfo, cellName, resolultion, resolultion, inputLayer:getExtent(), inputLayer:getSRID(), cLType, inputLayer)
end

local function renameEachClass(ds, dSetName, dsType, select, property)
	local dSet = ds:getDataSet(dSetName)
	local numProps = dSet:getNumProperties()
	local propsRenamed = {}
	
	for i = 0, numProps - 1 do
		local currentProp = dSet:getPropertyName(i)
		
		if string.match(currentProp, select) then
			local newName = ""
			if type(select) == "number" then
				if dsType == "POSTGIS" then
					newName = string.gsub(currentProp, "b"..select.."_", property.."_")
				else
					newName = string.gsub(currentProp, "B"..select.."_", property.."_")
				end
			else
				newName = string.gsub(currentProp, select.."_", property.."_")
			end
			ds:renameProperty(dSetName, currentProp, newName)
			propsRenamed[newName] = newName
		end		
	end
	
	return propsRenamed
end

local function getPropertyCreatedName(outDs, outDSetName, toLayer)
	local toDSetName = toLayer:getDataSetName()
	local toDsInfo = binding.te.da.DataSourceInfoManager.getInstance():getDsInfo(toLayer:getDataSourceId())
	local toDs = makeAndOpenDataSource(toDsInfo:getConnInfo(), toDsInfo:getType())

	
	local outDSet = outDs:getDataSet(outDSetName)
	local numProps = outDSet:getNumProperties()		
	local propCreatedName = ""
	
	while outDSet:moveNext() do
		for i = 0, numProps - 1 do
			local propName = outDSet:getPropertyName(i)
			if not toDs:propertyExists(toDSetName, propName) then
				if propName ~= "OGR_GEOMETRY" then
					propCreatedName = propName
				end
			end
		end
		outDSet:moveLast()
	end
	
	toDs:close()
	toDs = nil
	outDSet = nil
	collectgarbage("collect")

	return propCreatedName
end

local function getDataSetTypeByLayer(layer)
	local dSetName = layer:getDataSetName()
	local connInfo = binding.te.da.DataSourceInfoManager.getInstance():getDsInfo(layer:getDataSourceId())
	local ds = makeAndOpenDataSource(connInfo:getConnInfo(), connInfo:getType())
	local dst = ds:getDataSetType(dSetName)
	
	ds:close()
	ds = nil
	collectgarbage("collect")
	
	return dst
end

local function getNormalizedName(name)
	if string.len(name) <= 10 then
		return name
	end
	
	return string.sub(name, 1, 10)
end

local function vectorToVector(fromLayer, toLayer, operation, select, outConnInfo, outType, outDSetName)
	local v2v = binding.te.attributefill.VectorToVectorMemory()
	v2v:setInput(fromLayer, toLayer)			
			
	local outDs = v2v:createAndSetOutput(outDSetName, outType, outConnInfo)

	if operation == "average" then
		if area then
			operation = "weighted"
		else
			operation = "mean"
		end
	elseif operation == "majority" then
		if area then 
			operation = "intersection"
		else
			operation = "occurrence"
		end
	elseif operation == "sum" then
		if area then
			operation = "wsum"
		end
	end
	
	local toDst = getDataSetTypeByLayer(toLayer)

	v2v:setParams(select, OperationMapper[operation], toDst)

	local err = v2v:pRun() -- TODO: OGR RELEASE SHAPE PROBLEM (REVIEW)
	if err ~= "" then
		customError(err)
	end
	
	local propCreatedName = select.."_"..VectorAttributeCreatedMapper[operation]
	
	if outType == "OGR" then
		propCreatedName = getNormalizedName(propCreatedName)
	end
	
	propCreatedName = string.lower(propCreatedName)	
	
	outDs:close()
	outDs = nil
	toDst = nil
	v2v = nil
	collectgarbage("collect")
	
	return propCreatedName
end

local function rasterToVector(fromLayer, toLayer, operation, select, outConnInfo, outType, outDSetName)
	local r2v = binding.te.attributefill.RasterToVector()
			
	fromLayer = binding.te.map.DataSetLayer.toDataSetLayer(fromLayer)
	toLayer = binding.te.map.DataSetLayer.toDataSetLayer(toLayer)
	
	local rDs = binding.GetDs(fromLayer:getDataSourceId(), true)
    local rDSet = rDs:getDataSet(fromLayer:getDataSetName())
	local rpos = binding.GetFirstPropertyPos(rDSet, binding.RASTER_TYPE)
	local raster = rDSet:getRaster(rpos)
	
	if (fromLayer:getSRID() == 0) or (toLayer:getSRID() == 0) then
		customError("Input layer with invalid SRID information.")
	end
	
	local grid = raster:getGrid()
	grid:setSRID(fromLayer:getSRID())
			
	r2v:setInput(raster, toLayer)
			
	if operation == "average" then
		operation = "mean"
	end			
			
	r2v:setParams(select, OperationMapper[operation], false) -- TODO: TEXTURE PARAM (REVIEW)
			
	local outDs = r2v:createAndSetOutput(outDSetName, outType, outConnInfo)

	local err = r2v:pRun()
	if err ~= "" then
		customError(err)
	end
			
	local propCreatedName = "B"..select..RasterAttributeCreatedMapper[operation]
	
	if outType == "POSTGIS" then
		propCreatedName = string.lower(propCreatedName)
	end	
	
	return propCreatedName
end

local function isNumber(type)
	return	(type == binding.INT16_TYPE) or 
			(type == binding.INT32_TYPE) or 
			(type == binding.INT64_TYPE) or 
			(type == binding.UINT16_TYPE) or 
			(type == binding.UINT32_TYPE) or 
			(type == binding.UINT64_TYPE) or 
			(type == binding.FLOAT_TYPE) or 
			(type == binding.DOUBLE_TYPE) or 
			(type == binding.NUMERIC_TYPE)
end

local function getPropertiesTypes(dse)
	dse:moveFirst()
	local types = {}
	local numProps = dse:getNumProperties()
	
	for i = 0, numProps - 1 do
		types[dse:getPropertyName(i)] = dse:getPropertyDataType(i)
	end
	
	return types
end	

local function createDataSetAdapted(dSet)
	local count = 0
	local numProps = dSet:getNumProperties()
	local set = {}
		
	while dSet:moveNext() do
		local line = {}
		for i = 0, numProps - 1 do
			local type = dSet:getPropertyDataType(i)
			
			if isNumber(type) then
				line[dSet:getPropertyName(i)] = tonumber(dSet:getAsString(i))
			elseif type == binding.BOOLEAN_TYPE then
				line[dSet:getPropertyName(i)] = dSet:getBool(i)
			elseif type == binding.GEOMETRY_TYPE then
				line[dSet:getPropertyName(i)] = dSet:getGeom(i)
			else
				line[dSet:getPropertyName(i)] = dSet:getAsString(i)
			end
		end
		set[count] = line
		count = count + 1
	end	
	
	return set
end

local function finalize()
	if initialized then		
		binding.te.plugin.PluginManager.getInstance():clear()
		binding.TeSingleton.getInstance():finalize()	

		initialized = false	
		instance = nil
		
		collectgarbage("collect")
	end
end

TerraLib_ = {
	type_ = "TerraLib",

	init = function()		
		if not initialized then
			binding.TeSingleton.getInstance():initialize()
			binding.te.plugin.PluginManager.getInstance():clear()		
			binding.te.plugin.PluginManager.getInstance():loadAll()
			initialized = true
		end
	end,

	finalize = function()
		finalize()
	end,
	
	getVersion = function()
		return binding.te.common.Version.asString()
	end,

	createProject = function(self, project, layers)
		if not isValidTviewExt(project.file) then
			customError("Please, the file extension must be '.tview'.")
		end
		
		saveProject(project, layers)
	end,

	openProject = function(self, project, filePath)
		if not isValidTviewExt(project.file) then
			customError("Please, the file extension must be '.tview'.")
		end		
	
		loadProject(project, filePath)		
	end,
	
	getLayerInfo = function(self, project, layer)
		local info = {}		
		info.name = layer:getTitle()	
		info.sid = layer:getDataSourceId()
		
		loadProject(project, project.file)
		local dsInfo = binding.te.da.DataSourceInfoManager.getInstance():getDsInfo(info.sid)
		
		local type = dsInfo:getType()
		info.type = type
		local connInfo = dsInfo:getConnInfo()
		local dseName = ""
		
		if type == "POSTGIS" then
			info.host = connInfo.PG_HOST
			info.port = connInfo.PG_PORT
			info.user = connInfo.PG_USER
			info.password = connInfo.PG_PASSWORD
			info.database = connInfo.PG_DB_NAME
			info.table = connInfo.PG_NEWDB_NAME
			dseName = info.table
		elseif type == "OGR" then
			info.file = connInfo.URI
			dseName = getFileName(info.file)
		elseif type == "GDAL" then
			info.file = connInfo.URI
			dseName = getFileNameWithExtension(info.file)
		end
		
		local ds = makeAndOpenDataSource(connInfo, type)
		local dst = ds:getDataSetType(dseName)

		if dst:hasGeom() then
			info.rep = "geometry"
		else
			info.rep = "raster"
		end
		
		ds:close()
		ds = nil
		dst = nil
		collectgarbage("collect")
		
		releaseProject(project)
		
		return info
	end,
	addShpLayer = function(self, project, name, filePath)
		addFileLayer(project, name, filePath, "OGR")
	end,
	
	addTifLayer = function(self, project, name, filePath)
		addFileLayer(project, name, filePath, "GDAL")
	end,
	
	addPgLayer = function(self, project, name, data)				
		local connInfo = createPgConnInfo(data.host, data.port, data.user, data.password, data.database, data.table, data.encoding)
		
		loadProject(project, project.file)
		
		local layer = nil
		
		if dataSetExists(connInfo, "POSTGIS") then
			layer = createLayer(name, connInfo, "POSTGIS")
		else
			releaseProject(project)
			customError("Is not possible add the Layer. The table '"..data.table.."' does not exists.")
		end
		
		project.layers[layer:getTitle()] = layer		
		saveProject(project, project.layers)		
		releaseProject(project)		
	end,
	
	addShpCellSpaceLayer = function(self, project, inputLayerTitle, name, resolultion, filePath) 
		loadProject(project, project.file)
		
		local inputLayer = project.layers[inputLayerTitle]
		local connInfo = createFileConnInfo(filePath)
		
		createCellSpaceLayer(inputLayer, name, resolultion, connInfo, "OGR")
		
		self:addShpLayer(project, name, filePath)
	end,
	
	addPgCellSpaceLayer = function(self, project, inputLayerTitle, name, resolultion, data) 
		loadProject(project, project.file)

		local inputLayer = project.layers[inputLayerTitle]
		local connInfo = createPgConnInfo(data.host, data.port, data.user, data.password, data.database, data.table, data.encoding)
		
		if not dataSetExists(connInfo, "POSTGIS") then
			createCellSpaceLayer(inputLayer, name, resolultion, connInfo, "POSTGIS")
		else
			releaseProject(project)
			customError("The table '"..data.table.."' already exists.")
		end
		
		self:addPgLayer(project, name, data)	
	end,	
	
	dropPgTable = function(self, data)
		local connInfo = createPgConnInfo(data.host, data.port, data.user, data.password, data.database, data.table)		
		dropDataSet(connInfo, "POSTGIS")
	end,
	
	copyLayer = function(self, project, from, to)
		loadProject(project, project.file)
		
		local fromLayer = project.layers[from]	
		copyLayer(fromLayer, to)
		
		releaseProject(project)	
	end,
	
	attributeFill = function(self, project, from, to, out, property, operation, select, area, default)
		loadProject(project, project.file)

		local fromLayer = project.layers[from]
		local fromDsInfo =  binding.te.da.DataSourceInfoManager.getInstance():getDsInfo(fromLayer:getDataSourceId())
		local toLayer = project.layers[to]
		local toDsInfo = binding.te.da.DataSourceInfoManager.getInstance():getDsInfo(toLayer:getDataSourceId())
		local outDsInfo = binding.te.da.DataSourceInfoManager.getInstance():getDsInfo(toLayer:getDataSourceId())
		
		local outType = outDsInfo:getType()
		
		if outType == "OGR" then
			if string.len(property) > 10 then
				property = getNormalizedName(property)
				customWarning("The 'attribute' lenght is more than 10 characters, it was changed to '"..property.."'.")
			end
		end
		
		if propertyExists(toDsInfo:getConnInfo(), property, toDsInfo:getType()) then
			customError("The attribute '"..property.."' already exists in the CellularLayer.\n"
						.."Please set another name.")
		end		

		if not propertyExists(fromDsInfo:getConnInfo(), select, fromDsInfo:getType()) then
			customError("The attribute selected '"..select.."' not exists in layer '"..from.."'.")
		end
		
		local outDs = nil
		local outConnInfo = outDsInfo:getConnInfo()
		local outDSetName = out
		local propCreatedName = ""
		
		if outType == "POSTGIS" then
			outConnInfo.PG_NEWDB_NAME = string.lower(outDSetName)
		elseif outType == "OGR" then
			local outDir = _Gtme.makePathCompatibleToAllOS(getFileDir(outConnInfo.URI))
			outConnInfo.URI = outDir..out..".shp"
			outConnInfo.DRIVER = "ESRI Shapefile"
		end				
		
		local dseType = fromLayer:getSchema()
		
		if dseType:hasRaster() then
			propCreatedName = rasterToVector(fromLayer, toLayer, operation, select, outConnInfo, outType, out)
		else
			propCreatedName = vectorToVector(fromLayer, toLayer, operation, select, outConnInfo, outType, out)
		end
		
		if (outType == "POSTGIS") and (type(select) == "string")  then
			select = string.lower(select)
		end
		
		outDs = makeAndOpenDataSource(outConnInfo, outType)
		local attrsRenamed = {}
		
		if operation == "percentage" then
			attrsRenamed = renameEachClass(outDs, outDSetName, outType, select, property)
		else
			outDs:renameProperty(outDSetName, propCreatedName, property)
			attrsRenamed[property] = property
		end
		
		if default then
			for key, prop in pairs(attrsRenamed) do
				outDs:updateNullValues(outDSetName, prop, tostring(default))
			end			
		end
		
		-- TODO: RENAME INSTEAD OUTPUT
		-- #875
		-- outDs:renameDataSet(outDSetName, "rename_test")		

		local outLayer = createLayer(out, outConnInfo, outType)
		project.layers[out] = outLayer
		
		loadProject(project, project.file) -- TODO: IT NEED RELOAD (REVIEW)
		saveProject(project, project.layers)
		releaseProject(project)
		
		outDs:close()
		outDs = nil
		dseType = nil
		collectgarbage("collect")		
	end,
	
	getDataSet = function(self, project, layerName)
		loadProject(project, project.file)
		
		local layer = project.layers[layerName]
		
		if layer:getType() == "DATASETLAYER" then
			layer = binding.te.map.DataSetLayer.toDataSetLayer(layer)	
		else
			customError("Unknown Layer '"..layerName.."'.")
		end
		
		local dseName = layer:getDataSetName()
		local dsInfo = binding.te.da.DataSourceInfoManager.getInstance():getDsInfo(layer:getDataSourceId())
		local ds = makeAndOpenDataSource(dsInfo:getConnInfo(), dsInfo:getType())
		local dse = ds:getDataSet(dseName)
		local count = 0
		local numProps = dse:getNumProperties()
		
		local set = createDataSetAdapted(dse)
		
		releaseProject(project)
		ds:close()
		ds = nil
		dse = nil
		collectgarbage("collect")
		
		return set
	end,
	
	saveDataSet = function(self, project, from, to, toName, attrs)
		loadProject(project, project.file)

		local fromLayer = project.layers[from]
		
		if fromLayer:getType() == "DATASETLAYER" then
			fromLayer = binding.te.map.DataSetLayer.toDataSetLayer(fromLayer)	
		else
			customError("Unknown Layer '"..from.."'.")
		end

		local dseName = fromLayer:getDataSetName()
		local dsInfo = binding.te.da.DataSourceInfoManager.getInstance():getDsInfo(fromLayer:getDataSourceId())
		local ds = makeAndOpenDataSource(dsInfo:getConnInfo(), dsInfo:getType())
		local dse = ds:getDataSet(dseName)
		local dst = ds:getDataSetType(dseName)
		local pk = dst:getPrimaryKey()
		local pkName = pk:getPropertyName(0)
		local numProps = dse:getNumProperties()		
		local newDst = binding.te.da.DataSetType(toName)
		local geom = binding.GetFirstGeomProperty(dst)
		local srid = geom:getSRID()	
		
		local attrsToIn = {}
		if attrs then
			for i = 1, #attrs do
				attrsToIn[attrs[i]] = true
			end
		end
		
		local types = getPropertiesTypes(dse)

		-- Config the properties of the new DataSet 
		for k, v in pairs(to[1]) do		
			local isPk = (k == pkName)
			
			if types[k] ~= nil then
				if types[k] == binding.GEOMETRY_TYPE then
					newDst:add(k, srid, geom:getGeometryType(), true)
				else
					newDst:add(k, isPk, types[k], true)
				end
			elseif attrsToIn[k] then
				if type(v) == "number" then
					newDst:add(k, isPk, binding.DOUBLE_TYPE, true)
				elseif type(v) == "string" then
					newDst:add(k, binding.STRING_TYPE)
				elseif type(v) == "boolean" then
					newDst:add(k, binding.BOOLEAN_TYPE)
				end
			end
		end

		-- Create the new DataSet
		local newDse = binding.te.mem.DataSet(newDst)
		numProps = newDse:getNumProperties()
		
		for i = 1, #to do
			local idpos = 0
			local item = binding.te.mem.DataSetItem.create(newDse)

			for j = 0, numProps - 1 do
				local propName = newDse:getPropertyName(j)

				for k, v in pairs(to[i]) do				
					if propName == k then 
						local type = newDse:getPropertyDataType(j)
						
						if type == binding.INT16_TYPE then
							item:setInt16(j, v)
						elseif type == binding.INT32_TYPE then
							item:setInt32(j, v)
						elseif type == binding.INT64_TYPE then
							item:setInt64(j, v)
						elseif type == binding.FLOAT_TYPE then
							item:setFloat(j, v)
						elseif type == binding.DOUBLE_TYPE then
							item:setDouble(j, v)
						elseif type == binding.NUMERIC_TYPE then
							item:setNumeric(j, tostring(v))
						elseif type == binding.BOOLEAN_TYPE then
							item:setBool(j, v)
						elseif type == binding.GEOMETRY_TYPE then
							item:setGeom(j, v)
						else
							item:setString(j, v)
						end

						break
					end
				end
			end
			newDse:add(item)
		end
		
		local newDstName = newDst:getName()

		-- Remove the DataSet if it already exists
		local outConnInfo = dsInfo:getConnInfo()
		local outType = dsInfo:getType()
		local outDs = nil
		if outType == "POSTGIS" then
			outConnInfo.PG_NEWDB_NAME = newDstName
			dropDataSet(outConnInfo, "POSTGIS")
			outDs = makeAndOpenDataSource(outConnInfo, outType)
		elseif outType == "OGR" then
			local outDir = _Gtme.makePathCompatibleToAllOS(getFileDir(outConnInfo.URI))
			outConnInfo.URI = outDir..newDstName..".shp"
			outConnInfo.DRIVER = "ESRI Shapefile"		
			dropDataSet(outConnInfo, "OGR")
			outDs = makeAndOpenDataSource(outConnInfo, outType)
		end
		
		-- Save the new DataSet into the from DataSource
		outDs:createDataSet(newDst)
		newDse:moveBeforeFirst()
		outDs:add(newDstName, newDse)
		
		-- Create the new Layer
		local outLayer = createLayer(toName, outConnInfo, outType)
		project.layers[toName] = outLayer
		
		saveProject(project, project.layers)
		releaseProject(project)
		
		ds:close()
		dst:clear()
		ds = nil
		dse = nil	
		dst = nil
		newDst:clear()
		newDse:clear()		
		newDst = nil
		newDse = nil
		outDs:close()
		outDs = nil		
		collectgarbage("collect")		
	end,
	
	getShpByFilePath = function(self, filePath)
		local connInfo = createFileConnInfo(filePath)
		local ds = makeAndOpenDataSource(connInfo, "OGR")
		local dSetName = getFileName(filePath)
		local dSet = ds:getDataSet(dSetName)
		
		local count = 0
		local numProps = dSet:getNumProperties()
		local set = createDataSetAdapted(dSet)
		
		ds = nil
		dSet = nil
		collectgarbage("collect")
		
		return set	
	end
}

metaTableTerraLib_ = {
	__index = TerraLib_,
}

function TerraLib(data)
	if instance then
		return instance
	else	
		setmetatable(data, metaTableTerraLib_)
		instance = data
		instance:init()
		return data
	end
end
