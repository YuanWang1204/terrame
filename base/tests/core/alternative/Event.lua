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
	Event = function(unitTest)
		local error_func = function()
			event = Event{time = "time", period = 2, priority = -1, action = function(event) end}
		end
		unitTest:assert_error(error_func, incompatibleTypeMsg("time", "number", "time"))

		error_func = function()
			event = Event{period = "1", priority = 1, action = function(event) end}
		end
		unitTest:assert_error(error_func, incompatibleTypeMsg("period", "number", "1"))

		error_func = function()
			event = Event{period = -1, priority = 1, action = function(event) end}
		end
		unitTest:assert_error(error_func, incompatibleValueMsg("period", "positive number (except zero)", -1))

		error_func = function()
			event = Event{period = 2, priority = true, action = function(event) end}
		end
		unitTest:assert_error(error_func, incompatibleTypeMsg("priority", "number", true))

		error_func = function()
			event = Event{period = 2, priority = "aaa", action = function(event) end}
		end
		unitTest:assert_error(error_func, "'aaa' is an invalid value for parameter 'priority'. It must be a string from the set ['high', 'low', 'medium', 'veryhigh', 'verylow'].")

		error_func = function()
			event = Event{period = 0, priority = 1, action = function() end}
		end
		unitTest:assert_error(error_func, incompatibleValueMsg("period", "positive number (except zero)", 0))

		error_func = function()
			event = Event{period = 2, priority = 1, action = -5.5}
		end
		unitTest:assert_error(error_func, incompatibleTypeMsg("action", "one of the types from the set [Agent, Automaton, Cell, CellularSpace, function, Group, Society, Timer, Trajectory]", -5.5))

		error_func = function()
			event = Event{message = function() end}
		end
		unitTest:assert_error(error_func, "Parameter 'message' is deprecated, use 'action' instead.")

		error_func = function()
			event = Event{myaction = function() end}
		end
		unitTest:assert_error(error_func, unnecessaryParameterMsg("myaction"))
	end,
	config = function(unitTest)
		local event = Event{action = function(event) end}
		local error_func = function()
			event:config(1, -2, 1)
		end
		unitTest:assert_error(error_func, incompatibleValueMsg(2, "positive number", -2))

		event = Event{action = function(event) end}
		error_func = function()
			event:config(1, 0, 1)
		end
		unitTest:assert_error(error_func, incompatibleValueMsg(2, "positive number", 0))

		event = Event{action = function(event) end}
		error_func = function()
			event:config(1, "5")
		end
		unitTest:assert_error(error_func, incompatibleTypeMsg(2, "number", "5"))

		event = Event{action = function(event) end}
		error_func = function()
			event:config(1, 1, "aa")
		end
		unitTest:assert_error(error_func, incompatibleTypeMsg(3, "number", "aa"))
	end
}

