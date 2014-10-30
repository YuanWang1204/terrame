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
-- Authors: Pedro R. Andrade
--          Rodrigo Reis Pereira
-------------------------------------------------------------------------------------------

return{
	getLatency = function(unitTest)
		unitTest:assert(true)
	end,
	build = function(unitTest)
		unitTest:assert(true)
	end,
	getStateName = function(unitTest)
		unitTest:assert(true)
	end,
	getTrajectoryStatus = function(unitTest)
		unitTest:assert(true)
	end,
	Agent = function(unitTest)
		local singleFooAgent = Agent{
			id = "singleFoo",
			size = 10,
			execute = function(self)
				self.size = self.size + 1	
				self:walk()
			end}

		unitTest:assert_type(singleFooAgent, "Agent")
		unitTest:assert_equal(10, singleFooAgent.size)
		unitTest:assert_equal("singleFoo", singleFooAgent.id)

		local cs = CellularSpace{xdim = 10}

		cs:createNeighborhood()

		local e = Environment{
			cs,
			singleFooAgent
		}

		e:createPlacement{strategy = "random"}
		unitTest:assert_type(singleFooAgent:getCell(), "Cell")
		unitTest:assert_equal(1, #singleFooAgent:getCell().placement)

		local t = Timer{
			Event{action = singleFooAgent}
		}

		t:execute(10)
		unitTest:assert_equal(20,singleFooAgent.size)

		unitTest:assert_type(singleFooAgent:getCell(), "Cell")
		unitTest:assert_equal(1, #singleFooAgent:getCell().placement)

		local count = 0
		forEachCell(cs, function(cell)
			count = count + #cell.placement
		end)
		unitTest:assert_equal(1, count)
	end,
	addSocialNetwork = function(unitTest)
		local ag1 = Agent{}
		local sn = SocialNetwork{}
		ag1:addSocialNetwork(sn)
		unitTest:assert_type(ag1:getSocialNetwork(), "SocialNetwork")
		unitTest:assert_equal(#ag1:getSocialNetwork(), 0)

		local ag = Agent{}

		local sc = Society{instance = ag, quantity = 5}

		sn = SocialNetwork{}
		forEachAgent(sc, function(agent)
			sn:add(agent)
		end)

		ag:addSocialNetwork(sn)
		unitTest:assert(#ag:getSocialNetwork() == 5)
	end,
	getCell = function(unitTest)
		local ag1 = Agent{}
		local cs = CellularSpace{xdim = 3}
		cs:createNeighborhood()
		local myEnv = Environment{cs, ag1}

		myEnv:createPlacement{}

		unitTest:assert_type(ag1:getCell(), "Cell")
	end,
	getCells = function(unitTest)
		local ag1 = Agent{}
		local cs = CellularSpace{xdim = 3}
		cs:createNeighborhood()
		local myEnv = Environment{cs, ag1}

		myEnv:createPlacement{}

		unitTest:assert_type(ag1:getCells(), "table")
		unitTest:assert_type(ag1:getCells()[1], "Cell")
	end,
	getSocialNetwork = function(unitTest)
		local ag1 = Agent{}
		local sn = SocialNetwork{}
		ag1:addSocialNetwork(sn)
		local sn2 = ag1:getSocialNetwork()
		unitTest:assert_equal(sn2, sn)
	end,
	init = function(unitTest)
		local ag1 = Agent{
			init = function(self)
				self.value = 2
			end
		}

		unitTest:assert_nil(ag1.value)
		ag1:init()
		unitTest:assert_equal(2, ag1.value)
	end,
	leave = function(unitTest)
		local ag1 = Agent{}
		local cs = CellularSpace{xdim = 3}
		local myEnv = Environment{cs, ag1}

		myEnv:createPlacement{strategy = "void", name = "placement"}
		local cell = cs.cells[1]
		ag1:enter(cell, "placement")
		ag1:leave(nil, "placement")

		unitTest:assert_nil(ag1:getCell("placement"))

		local ag1 = Agent{}
		local cs = CellularSpace{xdim = 3}
		local myEnv = Environment{cs, ag1}

		myEnv:createPlacement{strategy = "void", name = "placement"}
		cell = cs.cells[1]
		ag1:enter(cell, "placement")
		ag1:leave(cell, "placement")

		unitTest:assert_nil(ag1:getCell("placement"))
	end,
	die = function(unitTest)
		local predator = Agent{
			energy = 40,
			name = "predator",
			execute = function(self) return self.energy end
		}

		local predators = Society{
			instance = predator, 
			quantity = 5
		}

		unitTest:assert_equal(5, #predators)
		local dead = predators.agents[2]
		predators.agents[2]:die()
		unitTest:assert_equal(4, #predators)

		local test_function = function()
			print(dead.a)
		end
		unitTest:assert_error(test_function, "Trying to use a function or an attribute of a dead Agent.")
	end,
	reproduce = function(unitTest)
		local predator = Agent{
			energy = 40,
			name = "predator",
			execute = function(self) return self.energy end
		}

		local predators = Society{
			instance = predator, 
			quantity = 5
		}

		predators.agents[2]:die()
		-- TODO: also test
		-- predators.agents[4]:reproduce()
		predators.agents[4]:reproduce{age = 0}
		unitTest:assert_equal(5, #predators)

		local cont = 3
		local sum = 0
		forEachAgent(predators, function(agent)
			sum = sum + agent:execute()
			if cont == 3 then predators.agents[3]:die() end
			if cont == 1 then predators.agents[4]:die() end
			cont = cont - 1
		end)
		unitTest:assert_equal(120, sum)
		unitTest:assert_equal(3, #predators)

		forEachAgent(predators, function(agent)
			agent:reproduce{age = 0}
		end)
		unitTest:assert_equal(6, #predators)
	end,
	message = function(unitTest)
		local ag = Agent{
			money = 0,
			on_message = function(self,	m)
				self.money = self.money + m.value
			end
		}

		local sc = Society{instance = ag, quantity = 2}
		local ag1 = sc.agents[1]		
		local ag2 = sc.agents[2]		

		ag1:message{
			receiver = ag2,
			value = 5
		}

		unitTest:assert(ag2.money == 5)
	end,
	on_message = function(unitTest)
		local ag = Agent{
			money = 0,
			on_message = function(self,	m)
				self.money = self.money + m.value
			end
		}

		local sc = Society{instance = ag, quantity = 2}
		local ag1 = sc.agents[1]		
		local ag2 = sc.agents[2]		

		ag1:message{
			receiver = ag2,
			delay = 1.5,
			value = 5
		}

		unitTest:assert(ag2.money == 0)
		sc:synchronize(0.5)
		unitTest:assert(ag2.money == 0)
		sc:synchronize(1)
		unitTest:assert(ag2.money == 5)
	end,
	sample = function(unitTest)
		local ag = Agent{}
		local sc = Society{instance = ag, quantity = 5}

		local sn = SocialNetwork{}
		forEachAgent(sc, function(agent)
			sn:add(agent)
		end)

		ag:addSocialNetwork(sn)
		unitTest:assert_type(ag:sample(), "Agent")
	end,
	setTrajectoryStatus = function(unitTest)
		local ag1 = Agent{
			energy = 5,
			hungry = false,
			counter = 0,
		}
		local cs = CellularSpace{xdim = 3}
		forEachCell(cs, function(cell) 
			cell.soilType = 0 
		end)

		local myEnv = Environment{cs, ag1}
		myEnv:createPlacement{strategy = "void", name = "placement"}
		local c1 = cs.cells[1]
		ag1:enter(c1)
		ag1:setTrajectoryStatus(nil)

		ag1 = Agent{
			energy = 5,
			hungry = false,
			counter = 0,
		}
		cs = CellularSpace{xdim = 3}
		forEachCell(cs, function(cell) 
			cell.soilType = 0 
		end)

		local myEnv = Environment{cs, ag1}
		myEnv:createPlacement{strategy = "void", name = "placement"}
		local c1 = cs.cells[1]
		ag1:enter(c1, "placement")
		ag1:setTrajectoryStatus(3)
		unitTest:assert(true)
	end,
	walk = function(unitTest)
		local ag1 = Agent{}
		local cs = CellularSpace{xdim = 3}
		cs:createNeighborhood()
		local myEnv = Environment{cs, ag1}

		myEnv:createPlacement{strategy = "void", name = "placement"}
		local c1 = cs.cells[1]
		ag1:enter(c1,"placement")

		ag1:walk()
		unitTest:assert_type(ag1:getCell(), "Cell")
	end,
	__tostring = function(unitTest)
		local ag1 = Agent{
			name = "nonfoo",
			init = function() end,
			execute = function() end
		}
		unitTest:assert_equal(tostring(ag1), [[cObj_           userdata
execute         function
init            function
name            string [nonfoo]
socialnetworks  table of size 0
]])
	end
}

