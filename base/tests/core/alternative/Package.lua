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
-- indirect, special, incidental, or consequential damages arising out of the use
-- of this library and its documentation.
--
-- Authors: Tiago Garcia de Senna Carneiro (tiago@dpi.inpe.br)
--          Pedro R. Andrade (pedro.andrade@inpe.br)
-------------------------------------------------------------------------------------------

return{
	customError = function(unitTest)
		local error_func = function()
			customError(2)
		end
		unitTest:assert_error(error_func, incompatibleTypeMsg(1, "string", 2))
	end,
	customWarning = function(unitTest)
		local error_func = function()
			customWarning(2)
		end
		unitTest:assert_error(error_func, incompatibleTypeMsg(1, "string", 2))
	end,
	defaultTableValue = function(unitTest)
		local t = {x = 5}
		local error_func = function()
			defaultTableValue(t, "x", false)
		end
		unitTest:assert_error(error_func, incompatibleTypeMsg("x", "boolean", 5))

		local error_func = function()
			defaultTableValue(t, "x", 5)
		end
		unitTest:assert_error(error_func, defaultValueMsg("x", 5))
	end,
	defaultValueWarning = function(unitTest)
		local error_func = function()
			defaultValueWarning(2)
		end
		unitTest:assert_error(error_func, "#1 should be a string.")
	end,
	deprecatedFunctionWarning = function(unitTest)
		local error_func = function()
			deprecatedFunctionWarning(2)
		end
		unitTest:assert_error(error_func, "#1 should be a string.")

		error_func = function()
			deprecatedFunctionWarning("test.", -1)
		end
		unitTest:assert_error(error_func, "#2 should be a string.")
	end
}

