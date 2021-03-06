-- state
function platforming_state()
    music(1)
    local s={}
    local updateables={}
    local drawables={}
    local bullets={}
    local guards={}
    s.bullets=bullets
    local enemies={}
    local potions={}
    local cam={x=0, y=0}
    s.cam = cam

    local respawned=false
    local showmsg=false
    local showmsgtxt=""
    local rtick=0
    
    local level={}
    level.hs=150 -- house spacing
    level.fw=256 -- forest width
    level.es=128 -- end spacing
    level.hw=48  -- house width
    level.hcnt=5 -- house count
    level.w=(level.hw+level.hs)*level.hcnt+level.fw +level.es

    local deferpos=false
    local pendingmusic=false

    local cabinmsgs={}
    add(cabinmsgs, {used=false, value="eastpass", msg="this password get's you\ninto east city."})
    add(cabinmsgs, {used=false, value="exitpass", msg="this password get's you\nout of this city."})
    add(cabinmsgs, {used=false, value="easthint", msg="to find your murderer\ngo east."})
    add(cabinmsgs, {used=false, value="westhint", msg="to find your murderer\ngo west."})
    add(cabinmsgs, {used=false, value="westpass", msg="this password get's you\ninto west city."})

    function bullet(x,y, dir, spd, bullets, dmg)
        local e=entity({})
        e:setpos(x,y)
        e.dir=dir
        e.spd=spd
        e.dmg=dmg
    
        local bounds_obj=bbox(8,8,0,0,4,6)
        e:set_bounds(bounds_obj)
        -- e.debugbounds=true
    
        function e:update()
            self:setx(self.x+(self.spd*self.dir))

            -- kill the bullet if needed
            if(self.x > cam.x+127)  self:kill()
            if(self.x < cam.x)      self:kill()
        end

        function e:kill()
            del(bullets,self)
        end
        
        function e:draw()
            spr(72, self.x, self.y, 1,1)
            --if(self.debugbounds) self.bounds:printbounds()
        end
    
        return e
    end
    
    function hero(x,y, bullets, platforming_state)
        local anim_obj=anim()
        local e=entity(anim_obj)

        anim_obj:add(1,4,0.3,1,2) -- running
        anim_obj:add(5,1,0.01,1,2) -- idle
        anim_obj:add(6,1,0.01,1,2) -- jumping
        anim_obj:add(7,1,0.5,2,2,true, function() e.shooting=false end) -- shoot

        e:setpos(x,y)
        e:set_anim(2) --idle
    
        local bounds_obj=bbox(8,16)
        e:set_bounds(bounds_obj)
        --e.debugbounds=true

        e.speed=2--1.3
        e.floory=y
        e.jumppw=7
        e.grav=0.01
        e.baseaccel=1
        e.accel=e.baseaccel
        e.grounded=true
        e.shooting=false
        e.wasshooting=false
        e.compensate=false
        e.compensatepx=-8
        e.bulletspd=4
        e.health=20
        e.dmg=1
        e.finalboss=false
        
        e.potions=0
        e.notifyjumpobj={}

        -- this vars are loaded in the vertigo_state
        e.codes={}
        e.codes.dir='none'
        e.codes.exit=false
        e.codes.dircode='none'
        e.btimer=0
        e.prevsh=-6300
        e.memslots={}
        -- 3 mem slots only
        add(e.memslots,"empty")
        add(e.memslots,"empty")
        add(e.memslots,"empty")

        function e:hurt(dmg)
            if(self.flickerer.is_flickering) return
            self:flicker(30)
            self.health-=dmg
            sfx(5)

            if self.potions > 0 and self.health < 15 then
                -- todo:sfx use potion
                self.potions-=1
                self.health+=5
            end
            if self.health <= 0 then
                music(-1)
                sfx(17)
                curstate=s
                pendingmusic=true
                self:reset()
            end
        end

        -- every x jumps the obj spawns a new enemy
        function e:set_notifyjumpobj(obj)
            self.notifyjumpobj=obj
        end

        function e:controlls()
            self.btimer+=1
            if not self.shooting then
                if self.wasshooting then
                    self.wasshooting=false
                    if self.compensate then
                        self.compensate=false
                        self:setx(self.x-self.compensatepx)
                    end
                end

                if btn(0) then     --left
                    self:setx(self.x-self.speed)
                    self.flipx=true
                    self:set_anim(1) --running
                elseif btn(1) then --right
                    self:setx(self.x+self.speed)
                    self.flipx=false
                    self:set_anim(1) --running
                else
                    self:set_anim(2) --idle
                end
                
                -- the up button is taken care on the cabin entity
                
                if btnp(4) and self.grounded then -- "O"
                    -- jump
                    sfx(4)
                    self.notifyjumpobj:tick({x=self.x, y=self.y})
                    self.grav = -self.jumppw
                    self:sety(self.y + self.grav)
                    self.grounded=false
                    self:set_anim(3) --jump
                elseif not self.grounded then
                    self:set_anim(3) --jump
                end
                
                if btnp(5) then -- "X"
                    -- shoot
                    if(self.btimer-self.prevsh < 10) return -- don't allow shooting like machine gun
                    self.prevsh=self.btimer

                    sfx(0)
                    self.shooting=true
                    self.wasshooting=true
                    self:set_anim(4) -- shoot
                    local dir=1     -- not flip
                    if self.flipx then
                        dir=-1      -- flip
                        -- flag compensate true
                        self.compensate=true
                        self:setx(self.x+self.compensatepx)
                        self.bounds.xoff1+=8
                        self.bounds.xoff2+=8
                    end

                    local b=bullet(self.x+4, self.y+4, dir, self.bulletspd, bullets, self.dmg)
                    add(bullets, b)
                end
            end

            
        end
    
        function e:update()
            self:controlls()

            if self.y < self.floory then
                --you're jumping
                self:sety(self.y + self.grav)
                self.grav += self.baseaccel * self.accel
                self.accel+=0.1
            else
                -- not jumping
                self.grav = 0.01
                self.accel = self.baseaccel
                self.grounded=true
            end

            if self.y > self.floory then
                -- compensate gravity
                self:sety(self.floory)
                self.grounded=true
            end
        end

        -- when you gameover and choose continue, everything's the same but your stats, that get resetted
        function e:reset()
            self.respawned=true
            self.speed=2--1.3
            self.floory=y
            self.jumppw=7
            self.grav=0.01
            self.baseaccel=1
            self.accel=e.baseaccel
            self.grounded=true
            self.shooting=false
            self.wasshooting=false
            self.compensate=false
            self.compensatepx=-8
            self.bulletspd=4
            self.health=20
            self.potions=0
            self.codes.dir='none'
            self.codes.exit=false
            self.codes.dircode='none'

            -- make it so that if you loose you don't loose your memory
            -- self.memslots={}
            -- add(self.memslots,"empty")
            -- add(self.memslots,"empty")
            -- add(self.memslots,"empty")

            
            if self.finalboss then
                self.finalboss=false
                deferpos=750 -- lo mando al forest
            end
            
        end
    
        return e
    end

    function cabin(x,y, hero)
        local e=entity({})
        e:setpos(x,y)
        
        local bounds_obj=bbox(12,32, 6, 26, -13, -26)
        e:set_bounds(bounds_obj)
        --e.debugbounds=true
        e.h = hero

        local idx=flr(rnd(4))+1
        if cabinmsgs[idx].used then
            for i=1,5 do
                if(not cabinmsgs[i].used) idx=i break
            end
        end
        cabinmsgs[idx].used=true
        e.cabinmsg=cabinmsgs[idx]


        function e:update()
            if collides(self,self.h) and btnp(2) then -- up btn
                -- *************
                --  enter cabin
                -- *************
                sfx(8)
                -- sorry bro, the pseudo 3d state has to be taken out due to high token consumption D:
                -- curstate=cabin_state(s)
                
                curstate=gfight_state(s, s, self.cabinmsg.msg, self.cabinmsg.value)
            end            
        end
        
        function e:draw()
            spr(32, x,y, 6, 5)
            -- if(self.debugbounds) self.bounds:printbounds()
        end

        return e
    end

    -- dir = west, east, north, south
    function guard(x,y,hero,dir)
        local anim_obj=anim()
        anim_obj:add(38,1,0.01,1,2) -- idle
        anim_obj:add(39,1,0.01,1,2) -- blocking
        anim_obj:add(40,1,0.01,1,2) -- allowing
    
        local e=entity(anim_obj)
        e:setpos(x,y)
        e:set_anim(1)
        e.sfxfuse=true
    
        local bounds_obj=bbox(16,16, 0,-30,0,0)
        if(x > 300) bounds_obj=bbox(16,16, -8,-30,8,0)
        e:set_bounds(bounds_obj)
        -- e.debugbounds=true
    
        function e:update()
            if collides(self, hero) then
                local exitcity=false
                local dirpass=false
                local hint=false

                local thispass=dir..'pass'
                local dirhint=dir..'hint'
                for m in all(hero.memslots) do
                    if(m == 'exitpass') exitcity=true
                    if(m == thispass)   dirpass=true
                    if(m == dirhint)    hint=true
                end

                if(exitcity and dirpass and hint) self:set_anim(3) return -- you shall pass

                -- block hero movement
                if(self.x < 200 and hero.x < self.x+16) hero:setx(self.x+16)
                if(self.x > 200 and hero.x > self.x-16) hero:setx(self.x-16)

                if(self.sfxfuse) sfx(6) self.sfxfuse=false
                if(not hint)    self:set_anim(2) showmsg=true showmsgtxt="I'LL ONLY LEAVE WITH A HINT\nOF MY MURDERED BEING THERE" return
                if(not exitcity)self:set_anim(2) showmsg=true showmsgtxt="YOU DON'T HAVE THE PASSWORD\nTO LEAVE" return
                if(not dirpass) self:set_anim(2) showmsg=true showmsgtxt="YOU DON'T HAVE THE PASSWORD\nTO ENTER THIS CITY" return
            else
                self:set_anim(1) --idle
                self.sfxfuse=true
            end
        end
        
        return e
    end

    function potion(x,y,potions)
        local e=entity(anim_obj)
        e:setpos(x,y)
    
        local bounds_obj=bbox(8,8)
        e:set_bounds(bounds_obj)
        -- e.debugbounds=true

        sfx(3)
        function e:pickup(hero)
            del(potions, self)
            sfx(2)
            -- i'm limiting the potions counter to 10
            if(hero.potions >= 10) return
            hero.potions +=1
        end
    
        function e:draw()
            spr(9, self.x, self.y, 1,1)
        end
    
        return e
    end

    function priest(x,y,hero,enemies,potioncreator)
        local anim_obj=anim()
        local e=entity(anim_obj)
        
        y=y+8
        anim_obj:add(119,4,0.2,1,1,true,function() e:set_anim(2) e:sety(e.y-8) e.justborn=10 sfx(7) end)     -- spawn
        anim_obj:add(86,4,0.2,2,2) -- walk
        anim_obj:add(135,6,0.3,1,2,true,function() del(enemies, e) end) -- die

        e:setpos(x,y)
        e:set_anim(1)
        e.spd=0.8
        e.justborn=-1 -- throwing a timing before chasing hero after spawn
        e.born=false
        e.dying=false
        e.prevflipx=false
        e.dmg=1
  
        local bounds_obj=bbox(8,8)
        e:set_bounds(bounds_obj)
        -- e.debugbounds=true

        sfx(1)
    
        function e:update()
            if(self.dying) return

            if self.born then
                if self.x > hero.x + 1 then
                    if(not self.prevflipx) self:setx(self.x-8)
                    self.prevflipx=true
                    self.flipx=true
                    self:setx(self.x-self.spd)
                elseif self.x < hero.x-8 then
                    self.prevflipx=false
                    self.flipx=false
                    self:setx(self.x+self.spd)
                else
                    hero:hurt(self.dmg)
                end
            elseif self.justborn != -1 then
                -- enters here when spawning anim is done
                if self.justborn > 0 then
                    self.justborn-=1
                end

                if self.justborn == 0 then
                    self.born = true
                end
            end
        end

        function e:hurt(dmg)
            self.dying = true
            if(self.flipx) self:setx(self.x+8) -- compensate width change
            self:set_anim(3) --die
            potioncreator:tick({x=self.x, y=self.y})
            sfx(6)
        end

        return e
    end

    -- the potioncreator creates a potion every threshold kills of enemies
    function potioncreator(potions)
        local p={}

        p.ticks=0
        p.threshold=3
        p.lastpos={}
        p.lastpos.x = 60
        p.lastpos.y = 60

        function p:tick(pos)
            self.ticks+=1
            self.lastpos.x=pos.x
            self.lastpos.y=pos.y
        end

        function p:update()
            if self.ticks >= self.threshold then
                self.ticks=0
                local p=potion(self.lastpos.x, self.lastpos.y-14, potions)
                add(potions, p)
            end
        end

        return p
    end

    function enemycreator(enemies,hero,potioncreator)
        local e={}

        e.ticks=1
        e.threshold=2
        e.lastpos={}
        e.lastpos.x = 60
        e.lastpos.y = 70

        e.timetick=0
        e.timethreshold=100

        function e:tick(pos)
            self.ticks+=1
            self.lastpos.x=pos.x
            --self.lastpos.y=pos.y
        end

        function e:update()
            self.timetick+=1

            local cenemy = false
            if self.timetick > self.timethreshold and hero.x > 130 then
                local side=1
                if(flr(rnd(2))%2==0) side=-1
                self.lastpos.x = hero.x + ((flr(rnd(4))+16) *side)
                
                self.timetick=0
                cenemy = true
            end

            local jenemy=false
            if self.ticks >= self.threshold then 
                self.ticks=0
                self.timetick+=10
                jenemy=true
            end

            if  jenemy or cenemy then
                local e=priest(self.lastpos.x, self.lastpos.y, hero, enemies,potioncreator)
                add(enemies, e)
            end
        end

        return e
    end
    
    -- receives a level config as argument
    function mapbuild(l, hero,this_state)
        local xx=128    -- starting x for first house
        local hy=36     -- house y position (doesn't change)

        -- *************************
        --      Setup forest
        -- *************************
        function sf()
            function tree(sp, x, y, w, h)
                local t={}
                function t:draw()
                    spr(sp,x,y,w,h)
                end
                return t
            end

            local fx=xx+((l.hs+l.hw)*3)-64 -- forest starting x    

            -- paint pines
            local fe= fx+l.fw-16  -- forest end
            for i=fx,fe,16 do
                add(drawables, tree(115,i,hy,2,5))
            end

            -- paint small trees
            fx=xx+((l.hs+l.hw)*3)-64 -- forest starting x
            fx+=8 -- make this trees out of phase with the pines
            for i=fx,fe,16 do
                if(flr(rnd(2))==1) add(drawables, tree(133,i,hy+17,2,3))
            end

            -- paint bright trees
            fx=xx+((l.hs+l.hw)*3)-64 -- forest starting x
            fx+=10 -- make this trees out of phase with the pines
            for i=fx,fe,24 do
                if(flr(rnd(2))==1) add(drawables, tree(112,i,hy+10,3,4))
            end
        end
        sf()

        -- *************************
        --      Setup houses
        -- *************************
        for i=1,l.hcnt do
            local c = cabin(xx,hy,hero)
            add(drawables, c)
            add(updateables, c)
            xx+=l.hw+l.hs       -- setup x for the next house
            if(i==3) xx+=l.fw   -- put 3 houses, then the forest, and then the rest
        end

        -- *************************
        --      Setup guards
        -- *************************
        local npcy=70

        -- guard on the left side
        local g = guard(64, npcy, hero, 'west')
        local t=teleport(58,npcy-16, hero)
        add(guards, g)
        add(updateables, t)

        add(drawables, g)
        add(updateables, g)
        

        -- guard on the right side
        g = guard(l.w-68, npcy, hero, 'east')
        local t=teleport(l.w-58,npcy-16, hero)
        add(guards, g)
        add(updateables, t)

        g.flipx=true
        add(drawables, g)
        add(updateables, g)

    end

    function teleport(x,y,hero)
        local e=entity({})
        e:setpos(x,y)
    
        local bounds_obj=bbox(8,24)
        e:set_bounds(bounds_obj)
        e.debugbounds=true
    
        function e:update()
            if collides(self, hero) then
                for g in all(guards) do
                    del(updateables, g)
                    del(drawables, g)
                    del(guards,g)
                end
                curstate=vertigo_state(s,s) 
                return 
            end
        end
    
        function e:draw()
            if(self.debugbounds) self.bounds:printbounds()
        end
    
        return e
    end

    local hero = hero(120,70, bullets, s)
    s.hero = hero
    
    local pc = potioncreator(potions)
    add(updateables, pc)

    local ec = enemycreator(enemies, hero,pc)
    add(updateables, ec)
    hero:set_notifyjumpobj(ec)

    mapbuild(level, hero, s)
    
    add(updateables, hero)
    add(drawables, hero)


    s.update=function()
        if(deferpos) hero.shooting=false hero.wasshooting=false hero:setx(deferpos) deferpos=false
        if(pendingmusic) music(1) pendingmusic=false

        -- *****************
        --  Updating camera
        -- *****************
        if not hero.shooting and not hero.wasshooting then
            if hero.flipx then
                if((hero.x-cam.x) < 55) cam.x=hero.x-55
            else
                if((hero.x-cam.x) > 70) cam.x=hero.x-70
            end
        end
        camera(cam.x, cam.y)


        for u in all(updateables) do
            u:update()
        end

        s.updateblts(bullets, enemies, true)

        for e in all(enemies) do
            e:update()
        end

        for p in all(potions) do
            if collides(p, hero) then
                p:pickup(hero)
                break
            end
        end

        --disable texts
        if (hero.x > level.es*2 and hero.x < 500) or (hero.x > 256 and hero.x < level.w-level.es) then
            showmsg=false
            showmsgtxt=""
            rtick=0
        end
    end

    s.draw=function()
        cls()
        
        -- *****************
        --        Level
        -- *****************
        -- sky
        fillp(0)
        rectfill(0,0,level.w,127, 12) 

        -- grass
        --fillp(0b0000001010000000)
        rectfill(0,47,level.w,127, 3) 
        
        -- land
        --fillp(0b0000010000000001)
        rectfill(0,77,level.w,94, 4) 


        
        -- *****************
        --      Objects
        -- *****************
        for d in all(drawables) do
            d:draw()
        end

        for b in all(bullets) do
            b:draw()
        end

        for e in all(enemies) do
            e:draw()
        end

        for p in all(potions) do
            p:draw()
        end

        
        -- *****************
        --        hud
        -- *****************
        s.drawhud()

        

        if hero.respawned or showmsg then
            camera(0,0)
            rtick+=1
            if hero.respawned then
                print("your friends where killed", 15,28, 7)
                print("you've been respawned", 21,34, 7)
                if(rtick>100) hero.respawned=false rtick=0
                showmsg=false
            elseif showmsg then
                print(showmsgtxt, 15,28, 7)
                if(rtick>40) rtick=0
            end
        end
    end

    s.updateblts=function(bullets, enemies, priest)
        for b in all(bullets) do
            b:update()

            -- check collisions between bullets and enemies
            for e in all(enemies) do
                
                if not priest or (not e.dying and e.born) then
                    if collides(b, e) then
                        b:kill()
                        e:hurt(b.dmg)
                        break
                    end
                end
            end
        end
    end

    s.drawhud=function()
        camera(0,0)
        fillp(0)
        rectfill(0,0,127,20, 0) -- top banner
        rect(2,2,125,18, 7) -- white frame top

        rectfill(0,110,127,127, 0) -- bottom banner
        rect(2,112,125,125, 7) -- white frame top

        rectfill(50,110, 74, 115, 7)    -- memory bkg
        print("MEMORY", 51, 110, 0)

        local sx=5
        local sy=6
        local hgt=4
        local wdt=58
        rectfill(sx,sy, sx+wdt, sy+hgt, 8)
        rectfill(sx,sy+1, sx+wdt, sy+hgt-1, 0)

        local h=hero.health
        local hx=22
        rectfill(hx,16, hx+24,21, 7)
        print("HEALTH", hx+1, 16, 0)
        for i=1,h do
            -- draw each life bar
            rectfill(sx,sy+2, sx+1, sy+hgt-2, 7)
            sx+=3
        end

        local p=hero.potions
        local px=88
        rectfill(px,16, px+28,21, 7)
        print("POTIONS", px+1, 16, 0)
        
        sx=px
        wdt=28
        rectfill(sx,sy, sx+wdt, sy+hgt, 8)
        rectfill(sx,sy+1, sx+wdt, sy+hgt-1, 0)
        for i=1,p do
            -- draw each potion bar
            rectfill(px,sy+2, px+1, sy+hgt-2, 7)
            px+=3
        end


        local sxt=4
        local syt=116
        local ttw=38
        local tth=7
        local tsp=2
        for i=1,3 do
            local c=8
            if(hero.memslots[i] == "empty") c=5

            local onepx=0
            if(i==2)onepx=1

            rectfill(sxt,syt,  sxt+ttw+onepx, syt+tth, c)
            sxt+=ttw+tsp+onepx
        end
    end

    return s
end