-------------------------------------------------------------------------------------------
-- TerraME - a software platform for multiple scale spatially-explicit dynamic modeling.
-- Copyright (C) 2001-2016 INPE and TerraLAB/UFOP -- www.terrame.org

-- This code is part of the TerraME framework.
-- This framework is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.

-- You should have received a copy of the GNU Lesser General Public
-- License along with this library.

-- The authors reassure the license terms regarding the warranties.
-- They specifically disclaim any warranties, including, but not limited to,
-- the implied warranties of merchantability and fitness for a particular purpose.
-- The framework provided hereunder is on an "as is" basis, and the authors have no
-- obligation to provide maintenance, support, updates, enhancements, or modifications.
-- In no event shall INPE and TerraLAB / UFOP be held liable to any party for direct,
-- indirect, special, incidental, or consequential damages arising out of the use
-- of this software and its documentation.
--
-------------------------------------------------------------------------------------------

return {
	fill = function(unitTest)
		local projName = "cellular_layer_fill_shape.tview"

		local proj = Project {
			file = projName,
			clean = true
		}

		local layerName1 = "limitepa"
		Layer{
			project = proj,
			name = layerName1,
			file = filePath("limitePA_polyc_pol.shp", "terralib")
		}

		local prodes = "prodes"
		Layer{
			project = proj,
			name = prodes,
			file = filePath("prodes_polyc_10k.tif", "terralib")	
			-- value  meaning
			-- 0
			-- 6      deforestation
			-- 7      deforestation
			-- 2      non-forest
			-- 17     deforestation
			-- 18     water
			-- 5      forest
			-- 49
		}
		
		local clName1 = "cells"
		local shp1 = clName1..".shp"

		if isFile(shp1) then
			rmFile(shp1)
		end

		local cl = Layer{
			project = proj,
			source = "shp",
			input = layerName1,
			name = clName1,
			resolution = 20000,
			file = clName1..".shp"
		}

		local shapes = {}

		-- MINIMUM

		local minTifLayerName = clName1.."_"..prodes.."_min"		
		local shp = minTifLayerName..".shp"

		table.insert(shapes, shp)
		
		if isFile(shp) then
			rmFile(shp)
		end

		cl:fill{
			operation = "minimum",
			attribute = "prod_min",
			name = prodes,
			output = minTifLayerName,
			select = 0,
		}

		local cs = CellularSpace{
			project = proj,
			layer = minTifLayerName 
		}

		forEachCell(cs, function(cell)
			unitTest:assertType(cell.prod_min, "number")
			unitTest:assert(cell.prod_min >= 0)
			unitTest:assert(cell.prod_min <= 254)
		end)

		local map = Map{
			target = cs,
			select = "prod_min",
			value = {0, 49, 169, 253, 254},
			color = {"red", "green", "blue", "orange", "purple"}
		}

		unitTest:assertSnapshot(map, "tiff-min.png")

		-- MAXIMUM

		local maxTifLayerName = clName1.."_"..prodes.."_max"		
		local shp = maxTifLayerName..".shp"

		table.insert(shapes, shp)
		
		if isFile(shp) then
			rmFile(shp)
		end

		cl:fill{
			operation = "maximum",
			attribute = "prod_max",
			name = prodes,
			output = maxTifLayerName,
			select = 0,
		}

		local cs = CellularSpace{
			project = proj,
			layer = maxTifLayerName 
		}

		forEachCell(cs, function(cell)
			unitTest:assertType(cell.prod_max, "number")
			unitTest:assert(cell.prod_max >= 0)
			unitTest:assert(cell.prod_max <= 254)
		end)

		local map = Map{
			target = cs,
			select = "prod_max",
			value = {0, 49, 169, 253, 254},
			color = {"red", "green", "blue", "orange", "purple"}
		}

		unitTest:assertSnapshot(map, "tiff-max.png")

		local tl = TerraLib()
		tl:finalize()

		forEachElement(shapes, function(_, value)
			rmFile(value)
		end)

		unitTest:assertFile(projName)
	end
}
