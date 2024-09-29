-- drum_seq
-- imminent gloom


-- in progress:
-- save pattern states, does not work?
-- toggle which rows are randomized
-- screen interface?
-- redo grid drawing to use named values

-- REWRITE set flags, call functions, maybe make a class for sequences,
--         draw grid based on defaults and state-based offsets 

-- notes ################################################################################### --

-- main clock runs at 96 ppqn (384).
-- most keypresses set flags and update variables that are read and triggered each step/substep.
-- data is stored in s/s_16th and p/p_16th/p_state.

-- init #################################################################################### --

persist = true

lattice = require("lattice")
tab = require("tabutil")
nb = include("nb/lib/nb")

g = grid.connect()

-- patterns
local p = {
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}}
}
local p_16th = {
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}},
	{{},{},{},{},{}}
}
local p_state = {"empty","empty","empty","empty","empty","empty","empty","empty","empty","empty"}
local p_num = 1

-- sequence
local s = {{},{},{},{},{}}
local s_16th = {{},{},{},{},{}}
local substep = 1
local step = 1
local s_frame = 1
local s_frame_div = 1
local s_start = 1
local s_end = 16

local voice = {"v1", "v2", "v3", "v4", "v5"}
local note = {1, 2, 3, 4, 5}
local velocity = {1, 1, 1, 1, 1}
local duration = {1, 1, 1, 1, 1}

local k1_held = false
local k2_held = false
local k3_held = false

local held = {false, false, false, false, false}
local shift = false
local fill = false
local erase = false
local rec = true
local randomize = false

local shift_amount
local shift_buf = {}
local fill_buf = {}
local fill_rate
local jump_step = 1
local jump_buf = {}
local loop_buf = {}

local rng_br = 0

function init()
	
	nb:init()
	nb.voice_count = 2
	
	newline() -- fakes a blank space in the prams menu using a nameless toggle
	
	params:add_separator("DRUM_SEQ: GENERAL")
	
	params:add_control("bpm", "tempo:", controlspec.new(1, 300, "lin", 1, 120, "bpm", 1/299))
	params:set_action("bpm", function(x) params:set("clock_tempo", x) end)

	params:add_trigger("load", "load patterns")

	params:add_trigger("save", "save patterns")
	
	newline()
	
	params:add_separator("DRUM_SEQ: VOICE SELECT")
	
	nb:add_param("v1", "track 1:")
	nb:add_param("v2", "track 2:")
	nb:add_param("v3", "track 3:")
	nb:add_param("v4", "track 4:")
	nb:add_param("v5", "track 5:")
	
	newline()
	
	params:add_separator("DRUM_SEQ: VOICE SETTINGS")
	
	nb:add_player_params()
	
	newline()
	
	params:add_separator("DRUM_SEQ: TRACK SETTINGS")
	
	params:add_group("track 1:", 3)
	params:add_number("note1", "note:", 1, 127, 1)
	params:set_action("note1", function(x) note[1] = x end)
	params:add_number("vel1", "velocity:", 1, 127, 1)
	params:set_action("vel1", function(x) velocity[1] = x end)
	params:add_number("dur1", "duration:", 1, 127, 1)
	params:set_action("dur1", function(x) duration[1] = x end)
	
	params:add_group("track 2:", 3)
	params:add_number("note2", "note:", 1, 127, 2)
	params:set_action("note2", function(x) note[2] = x end)
	params:add_number("vel2", "velocity:", 1, 127, 1)
	params:set_action("vel2", function(x) velocity[2] = x end)
	params:add_number("dur2", "duration:", 1, 127, 1)
	params:set_action("dur2", function(x) duration[2] = x end)
	
	params:add_group("track 3:", 3)
	params:add_number("note3", "note:", 1, 127, 3)
	params:set_action("note3", function(x) note[3] = x end)
	params:add_number("vel3", "velocity:", 1, 127, 1)
	params:set_action("vel3", function(x) velocity[3] = x end)
	params:add_number("dur3", "duration:", 1, 127, 1)
	params:set_action("dur3", function(x) duration[3] = x end)
	
	params:add_group("track 4:", 3)
	params:add_number("note4", "note:", 1, 127, 4)
	params:set_action("note4", function(x) note[4] = x end)
	params:add_number("vel4", "velocity:", 1, 127, 1)
	params:set_action("vel4", function(x) velocity[4] = x end)
	params:add_number("dur4", "duration:", 1, 127, 1)
	params:set_action("dur4", function(x) duration[4] = x end)
	
	params:add_group("track 5:", 3)
	params:add_number("note5", "note:", 1, 127, 5)
	params:set_action("note5", function(x) note[5] = x end)
	params:add_number("vel5", "velocity:", 1, 127, 1)
	params:set_action("vel5", function(x) velocity[5] = x end)
	params:add_number("dur5", "duration:", 1, 127, 1)
	params:set_action("dur5", function(x) duration[5] = x end)
	
	newline()
	
	params:add_separator("DRUM_SEQ: EMERGENCY")
	
	params:add_trigger("clear_pset", "clear state")
	params:set_action("clear_pset", function(x) params:delete("/home/we/dust/data/tr/state.pset") end)
	
	newline()
	
	clk = lattice:new{auto = true, ppqn = 96, enabled = true}
	
	-- main clock: 96 ppqn = 16 steps * 24 substeps = 384 substeps
	clk_main = clk:new_sprocket{
		action = function(t) clk_main_tick(t) end,
		division = 1/4/96,
		enabled = true
	}
	
	clk:start()
	clk_main:start()

	-- clear sequence and patterns
	clear_sequence()
	for n = 1, 10 do clear_pattern(n) end
	
	-- restore previous session
	if persist == true then
		nb:stop_all()
		params.action_read = function()
			print("read session data")
			tab.load("/home/we/dust/data/tr/sequence.data")
			tab.load("/home/we/dust/data/tr/sequence_16th.data")
			tab.load("/home/we/dust/data/tr/patterns.data")
			tab.load("/home/we/dust/data/tr/patterns_16th.data")
			tab.load("/home/we/dust/data/tr/patterns_state.data")
		end
		params:read("/home/we/dust/data/tr/state.pset")
	end
end

-- utility ################################################################################# --

-- nameless trigger to fake linebreak in the params menu, uniqe id to avoid errors
local line_count = 1
function newline()
	params:add_trigger(tostring("void_" .. line_count), "")
	params:set_action(tostring("void_" .. line_count), function() print("the void whispers back") end)
	line_count = line_count + 1
end

-- conversion
function step_2_substep(val)
	return (val - 1) * 24 + 1
end

function substep_2_step(val)
	return math.floor((val - 1) / 24) + 1
end

-- set loop start and end
function set_loop()
	if #loop_buf > 1 then
		if loop_buf[1] < loop_buf[#loop_buf] then
			s_start = loop_buf[1]
			s_end = loop_buf[#loop_buf]
		elseif loop_buf[1] > loop_buf[#loop_buf] then
			s_start = loop_buf[#loop_buf]
			s_end = loop_buf[1]
		end
	end
end

-- clear sequence/pattern
function clear_sequence()
	for track = 1, 5 do
		for step = 1, 16 do s_16th[track][step] = 0 end
		for substep = 1, 384 do s[track][substep] = 0 end
	end
end	

function clear_pattern(pattern)
	for track = 1, 5 do
		for step = 1, 16 do p_16th[pattern][track][step] = 0 end
		for substep = 1, 384 do p[pattern][track][substep] = 0 end
	end
	p_state[pattern] = "empty"
end	

-- copy sequence/pattern
function s_2_p(pattern)
	for track = 1, 5 do
		for step = 1, 16 do
			p_16th[pattern][track][step] = s_16th[track][step]
		end
		for substep = 1, 384 do
			p[pattern][track][substep] = s[track][substep]
		end
	end
	p_state[pattern] = "full"
end

function p_2_s(pattern)
	for track = 1, 5 do
		for step = 1, 16 do
			s_16th[track][step] = p_16th[pattern][track][step]
		end
		for substep = 1, 384 do
			s[track][substep] = p[pattern][track][substep]
		end
	end
end

-- are there active substeps?
function get_step_state(track, step)
	local sum = 0
	for substep = 1, 24 do
		if s[track][(step - 1) * 24 + substep] == 1 then
			sum = sum + 1
		end
	end
	if sum == 0 then
		return 0
	else
		return 1
	end
end

-- randomize sequence, more shift = higher chance
function s_randomize()
	if #shift_buf < 4 then
		for track = 1, 5 do
			for step = 1, 16 do
				if math.random() < shift_amount/32 then 
					s[track][step_2_substep(step)] = (s[track][step_2_substep(step)] + 1) % 2
				end
				s_16th[track][step] = get_step_state(track, step)
			end
		end
	elseif #shift_buf == 4 then
		for track = 1, 5 do
			for substep = 1, 384 do
				if math.random() < shift_amount/4096 then 
					s[track][substep] = (s[track][substep] + 1) % 2
				end
			end
			for step = 1, 16 do
				s_16th[track][step] = get_step_state(track, step)
			end
		end		
	end
end


-- sketches for later ###################################################################### --
function shift_action()
	
end

function shift_action()

end

function shift_action()

end

function shift_action()

end

function shift_action()

end






-- main #################################################################################### --

-- trigger drum hit!
function hit(n)
	player = params:lookup_param(voice[n]):get_player()
	player:play_note(note[n], velocity[n], duration[n])
end

-- reset
function s_reset()
	substep = 1
	step = 1
end

-- clock
function clk_main_tick(t)

	-- step through sequence (in loop window)
	substep = substep + 1
	if substep > step_2_substep(s_end) + 23 then substep = step_2_substep(s_start) end

	-- every 24th substep, increment step
	if ((substep - 1) % 24) + 1 == 1 then 
		step = step + 1
		clk_16th_tick()
		if step > s_end then step = s_start end
	end
	
	-- every 24th substep, increment the frame count (for s-locked animation)
	if ((substep - 1) % 24) + 1 == 1 then 
		s_frame = s_frame + 1
		if s_frame > 16 then s_frame = 1 end
	end
	
	-- erase steps
	for n = 1, 5 do
		if held[n] == true and erase == true then
			s[n][substep] = 0
			s_16th[n][step] = 0
		end
	end
	
	-- fill steps
	for n = 1, 5 do 
		if fill == true then
			if ((substep - 1) % fill_rate) + 1 == 1 then
				for n = 1, 5 do
					if held[n] == true then 
						if rec == true then
							s[n][substep] = 1
							s_16th[n][step] = 1
						elseif rec == false then
							hit(n)
						end
					end
				end
			end
		end	
	end
	
	-- play steps
	for n = 1, 5 do
		if s[n][substep] == 1 then
			hit(n)
		end
	end
	
	redraw()
	grid_redraw()
end

function clk_16th_tick()
	-- randomize steps
	if randomize == true and shift == true then
		s_randomize()
	end

	-- if buttons on the tracer line are held, step through them in order (in loop window)
	if shift == false then
		if #jump_buf == 1 then
			step = util.clamp(jump_buf[1], s_start, s_end)
			substep = step_2_substep(util.clamp(jump_buf[1], s_start, s_end))
		elseif #jump_buf > 1 then
			jump_step = jump_step + 1
			if jump_step > #jump_buf then jump_step = 1 end
			step = util.clamp(jump_buf[jump_step], s_start, s_end)
			substep = step_2_substep(util.clamp(jump_buf[jump_step], s_start, s_end))
		end
	end
end

-- physical interface ###################################################################### --

function g.key(x, y, z)

	if z == 1 then key_down = true else key_down = false end

	-- triggers
	for n = 1, 5 do
		if x == n and y == 7 or x == n and y == 8 then
			-- set held flags
			if z == 1 then held[n] = true else held[n] = false end
			-- bang on hit and add to s
			if z == 1 then
				if erase == true then -- erase steps
					s[n][substep] = 0
					s_16th[n][step] = 0
				else
					if fill == false then -- add to s if rec is on, play note
						if rec == true then						
							s[n][substep] = 1
							s_16th[n][step] = 1
							hit(n)
						elseif rec == false then
							hit(n)
						end
					end
				end
			end
		end
	end
	
	-- sequence
	if z == 1 and y <= 5 then
		if erase == true then -- clear all steps (and substeps) touched
			for n = 0, 23 do s[y][step_2_substep(x) + n] = 0 end
			s_16th[y][x] = 0
		elseif s_16th[y][x] == 0 then -- if empty add a hit to the first substep
			s[y][step_2_substep(x)] = 1
			s_16th[y][x] = 1
		elseif s_16th[y][x] == 1 then -- if not empty clear all hits on step
			for n = 0, 23 do s[y][step_2_substep(x) + n] = 0 end 
			s_16th[y][x] = 0
		end
	end
	
	-- rec flag
	if y == 8 and (x == 6 or x == 11) then
		if z == 1 then
			if rec == false then rec = true else rec = false end
		end
	end

	-- erase flag
	if x == 16 and y == 8 then
		if z == 1 then erase = true else erase = false end
	end
	
	-- randomize flag
	if x == 6 and y == 7 then
		if z == 1 then randomize = true else randomize = false end
	end
	
	-- clear sequence
	if erase == true and shift == true then
		clear_sequence()
	end
	
	-- shift flag and magnitude
	if y == 8 and (x >= 7 and x <= 10) then
		if z == 1 then
			-- add all held fills to a table in order
			table.insert(shift_buf, x)
		else
			-- remove each step as it is released
			for i, v in pairs(shift_buf) do
				if v == x then
					table.remove(shift_buf, i)
				end
			end
		end
		
		-- set flag
		if #shift_buf > 0 then shift = true else shift = false end
		
		local amount = {1, 2, 4, 8} -- set values for number of held buttons
		
		if #shift_buf > 0 then
			shift_amount = amount[#shift_buf]
		end
	end
	
	-- fill flag and magnitude
	if y == 8 and (x >= 12 and x <= 15) then
		if z == 1 then
			-- add all held fills to a table in order
			table.insert(fill_buf, x)
		else
			-- remove each step as it is released
			for i, v in pairs(fill_buf) do
				if v == x then
					table.remove(fill_buf, i)
				end
			end
		end
		
		-- set flag
		if #fill_buf > 0 then fill = true else fill = false end
		
		local rate = {24, 12, 6, 3} -- hit every nth substep, 16th = 24 etc, 32nd = 12 etc.
		
		if #fill_buf > 0 then
			fill_rate = rate[#fill_buf]
		end
	end
	
	-- loop points
	if y == 6 then
		if z == 1 then
			-- add all held buttons to a table in order
			table.insert(loop_buf, x)
		else
			-- remove each step as it is released
			for i, v in pairs(loop_buf) do
				if v == x then table.remove(loop_buf, i) end
			end
		end
	end
	
	-- sets start and end based on min/max based on first and last button held
	if shift == true then
		set_loop()
	end

	-- jump between held steps
	if y == 6 then
		if z == 1 then
			-- add all held steps to a table in order
			table.insert(jump_buf, x)
		else
			-- remove each step as it is released
			for i, v in pairs(jump_buf) do
				if v == x then
					table.remove(jump_buf, i)
				end
			end		
		end
	end
	
	-- patterns
	if y == 7 and (x >= 7 and x<= 16) then
		p_num = x - 6
		if z == 1 then
			if shift == true then -- save to choosen slot
				s_2_p(p_num)
				p_state[p_num] = "full"
			elseif erase == true then -- clear
				clear_pattern(p_num)
				p_state[p_num] = "empty"
			else -- load
				p_2_s(p_num)
			end			
		end
	end
	
	-- randomize sequence
	if y == 7 and x == 6 and z == 1 then
		if shift == true then
			s_randomize()
		end
	end

	grid_redraw()
end

-- encoders ################################################################################ --

function enc(n, d)
	if n == 1 then
		params:delta("bpm", d)
	end
end

-- keys #################################################################################### --

function key(n, z)
	if z == 1 then
		if n == 1 then k1_held = true end 
		if n == 2 then k2_held = true end
		if n == 3 then k3_held = true end
	else
		if n == 1 then k1_held = false end
		if n == 2 then k2_held = false end
		if n == 3 then k3_held = false end
	end
	
	if k1_held then
		
	else
		
	end
	
end

-- draw interface ########################################################################## --

function redraw()
	screen.clear()
	
	screen.move(10, 10)
	screen.text(step.."/"..substep)
	
	screen.update()
end

-- draw grid ############################################################################### --

function grid_redraw()
	-- clear
	g:all(0)
	
	-- loop
	for n = s_start, s_end do g:led(n, 6, 5) end
	
	-- sequence
	for y = 1, 5 do
		for x = 1, 16 do
			if s_16th[y][x] == 1 then
				g:led(x, y, 8)
			else
				g:led(x, y, 0)
			end
		end
		if s_16th[y][step] == 1 then
			g:led(step, y, 12)
		else
			g:led(step, y, 0)
		end
	end
	
	-- controls
	if erase == true then -- turn down erase and shift
		g:led(16, 8, 2)
		for n = 7, 10 do g:led(n, 8, 2) end
	elseif shift == true then -- turn down erase, turn up loop
		for n = 7, 10 do g:led(n, 8, #shift_buf * 2 + 5) end
		g:led(16, 8, 2)
		for n = s_start, s_end do g:led(n, 6, 7) end
	elseif erase == true and shift == true then
		for n = 7, 10 do g:led(n, 8, 0) end
		g:led(16, 8, 0)
	else
		for n = 7, 10 do g:led(n, 8, 5) end
		g:led(16, 8, 10)
	end
	
	if #loop_buf > 0 then
		for n = 7, 10 do g:led(n, 8, 7) end
	end

	if fill == true then
		for n = 12, 15 do g:led(n, 8, #fill_buf * 2 + 5) end
	else
		for n = 12, 15 do g:led(n, 8, 5) end
	end
	
	for n = 1, 5 do
		if held[n] == true then 
			g:led(n, 7, 15)
			g:led(n, 8, 15)
		elseif fill == true then
			g:led(n, 7, #fill_buf + 3)
			g:led(n, 8, #fill_buf + 3)
		else
			g:led(n, 7, 3)
			g:led(n, 8, 3)
		end
		
		if s[n][substep] == 1 then 
			g:led(n, 7, 12)
			g:led(n, 8, 12)
		end
	end
	
	if rec == true then
		local br = {1, 2, 3, 4, 5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 2}
		g:led(6, 8, br[s_frame])
		g:led(11, 8, br[s_frame])
	end
	
	-- patterns
	for n = 1, 10 do
		if p_state[n] == "full" then
			g:led(n + 6, 7, 4)
		elseif shift == true then
			g:led(n + 6, 7, 4)
		else
			g:led(n + 6, 7, 2)
		end
	end
	
	if p_state[p_num] == "full" then
		g:led(p_num + 6, 7, 15)
	elseif shift == true then
		g:led(p_num + 6, 7, 12)
	else
		g:led(p_num + 6, 7, 10)
	end
	
	-- randomize
	if shift == true then
		if substep % 24 == 1 then
			rng_br = math.random(shift_amount * 3)
		end
		g:led(6, 7, rng_br)
	end
	
	-- tracer
	g:led(step, 6, 15)

	-- draw
	g:refresh()
end

-- ######################################################################################### --

-- save state on exit
function cleanup()
	-- save session
	if persist == true then
		nb:stop_all()
		params.action_write = function()
			print("save session data")
			tab.save(s, "/home/we/dust/data/tr/sequence.data")
			tab.save(s_16th, "/home/we/dust/data/tr/sequence_16th.data")
			tab.save(p, "/home/we/dust/data/tr/patterns.data")
			tab.save(p_16th, "/home/we/dust/data/tr/patterns_16th.data")
			tab.save(p_state, "/home/we/dust/data/tr/patterns_state.data")
		end
		params:write("/home/we/dust/data/tr/state.pset")
	end
end
