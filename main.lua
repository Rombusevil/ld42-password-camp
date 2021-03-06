pico-8 cartridge // http://www.pico-8.com
version 15
__lua__
-- made with super-fast-framework

------------------------- start imports
--<*sff/entity.lua
--<*sff/tutils.lua
--<*sff/collision.lua

--<*visual.lua
--<*menu_state.lua
--<*story_state.lua
--<*platforming_state.lua
--<*gameover_state.lua
--<*win_state.lua
--<*gfight_state.lua
--<*memory_state.lua 

-- sadly, the cabin "3d" state takes too many tokens :\ so i'm cutting it off
--  --<*cabin_state.lua
--<*vertigo_state.lua
--------------------------- end imports

-- to enable mouse support uncomment all of the following commented lines:
-- poke(0x5f2d, 1) -- enables mouse support
function _init()
    curstate=menu_state()
    --curstate=cabin_state()
    --curstate=platforming_state()
    --curstate=memory_state(platforming_state(), "go east to find your murderer")
end

function _update()
    -- mouse utility global variables
    -- mousex=stat(32)
    -- mousey=stat(33)
    -- lclick=stat(34)==1
    -- rclick=stat(34)==2
    -- mclick=stat(34)==4
	curstate.update()
end

function _draw()
    curstate.draw()
    -- pset(mousex,mousey, 12) -- draw your pointer here
end
