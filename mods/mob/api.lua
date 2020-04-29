--class 
mobs = {}

mobs.register_mob = function(def)

local mob_register = {}

------------------------------------------------
mob_register.initial_properties = {
	physical = def.physical,
	collide_with_objects = def.collide_with_objects,
	collisionbox = def.collisionbox,
	visual = def.visual,
	visual_size = def.visual_size,
	mesh = def.mesh,
	textures = def.textures,
	is_visible = def.is_visible,
	pointable = def.pointable,
	automatic_face_movement_dir = def.automatic_face_movement_dir,
	automatic_face_movement_max_rotation_per_sec = def.automatic_face_movement_max_rotation_per_sec,
	makes_footstep_sound = def.makes_footstep_sound,
}


mob_register.hp = def.hp
mob_register.speed = def.speed
mob_register.jump_timer = 0

mob_register.hurt_inside_timer = 0
mob_register.death_animation_timer = 0
mob_register.dead = false

mob_register.mob = true
mob_register.hostile = def.hostile

mob_register.hostile_timer = 0
mob_register.timer = 0

mob_register.state = def.state

mob_register.hunger = 200

mob_register.view_distance = def.view_distance

mob_register.punch_timer = 0
mob_register.punched_timer = 0

mob_register.head_mount = def.head_mount


mob_register.on_activate = function(self, staticdata, dtime_s)
	self.object:set_armor_groups({immortal = 1})
	--self.object:set_velocity({x = math.random(-5,5), y = 5, z = math.random(-5,5)})
	self.object:set_acceleration(def.gravity)
	if string.sub(staticdata, 1, string.len("return")) == "return" then
		local data = minetest.deserialize(staticdata)
		if data and type(data) == "table" then
			--self.range = data.range
			self.hp = data.hp
			self.hunger = data.hunger
			self.hostile = data.hostile
			self.hostile_timer = data.hostile_timer
			self.death_animation_timer = data.death_animation_timer
			self.dead = data.dead
		end
	end
	
	--set up mob
	self.object:set_animation({x=0,y=0}, 1, 0, true)
	self.object:set_hp(self.hp)
	self.direction = vector.new(math.random()*math.random(-1,1),0,math.random()*math.random(-1,1))
	
    
	--set the head up
    if def.has_head == true then
        local head = minetest.add_entity(self.object:get_pos(), "mob:head"..def.mobname)
        if head then
            self.child = head
            self.child:get_luaentity().parent = self.object
            self.child:set_attach(self.object, "", self.head_mount, vector.new(0,0,0))
            self.head_rotation = vector.new(0,0,0)
            self.child:set_animation({x=90,y=90}, 15, 0, true)
        end
    end
	self.is_mob = true
	self.object:set_armor_groups({immortal = 1})
	--self.object:set_yaw(math.pi*math.random(-1,1)*math.random())
end

--this controls how fast the mob punches
mob_register.manage_punch_timer = function(self,dtime)
	if self.punch_timer > 0 then
		self.punch_timer = self.punch_timer - dtime
	end
	--this controls how fast you can punch the mob (punched timer reset)
	if self.punched_timer > 0 then
		--print(self.punched_timer)
		self.punched_timer = self.punched_timer - dtime
	end
end

--this controls the hostile state
if def.hostile == false then
    mob_register.manage_hostile_timer = function(self,dtime)
        if self.hostile_timer > 0 then
            self.hostile_timer = self.hostile_timer - dtime
        end
        if self.hostile_timer <= 0 then
            self.hostile = false
        end
    end
end

--this stops the pig from flying into the air
mob_register.manage_jump_timer = function(self,dtime)
	if self.jump_timer > 0 then
		self.jump_timer = self.jump_timer - dtime
	end
end

mob_register.set_animation = function(self)
	if self.speed == 0 or vector.equals(self.direction,vector.new(0,0,0)) then
		self.object:set_animation(def.standing_frame, 1, 0, true)
	else
		self.object:set_animation(def.moving_frame, 1, 0, true)
		local speed = self.object:get_velocity()
		speed.y = 0
		self.object:set_animation_frame_speed(vector.distance(vector.new(0,0,0),speed)*def.animation_multiplier)
	end
end

--makes the mob swim
mob_register.swim = function(self,dtime)
	local pos = self.object:getpos()
	pos.y = pos.y + 0.3
	local node = minetest.get_node(pos).name
	self.swimming = false
	if node == "main:water" or node =="main:waterflow" then
		local vel = self.object:getvelocity()
		local goal = 3
		local acceleration = vector.new(0,goal-vel.y,0)
		--jump out of the water
		if (vel.x == 0 and self.direction.x ~= 0) or (vel.z == 0 and self.direction.z ~= 0) then
			self.object:set_velocity(vector.new(vel.x,5,vel.z))
		--else swim
		else
			self.object:add_velocity(acceleration)
		end
		self.swimming = true
	end
end

local get_group = minetest.get_node_group
local get_node = minetest.get_node
mob_register.hurt_inside = function(self,dtime)
	if self.hp > 0 and self.hurt_inside_timer <= 0 then
		local pos = self.object:getpos()
		local hurty = get_group(get_node(pos).name, "hurt_inside")
		if hurty > 0 then
			self.object:punch(self.object, 2, 
				{
				full_punch_interval=1.5,
				damage_groups = {damage=hurty},
			})
		end
	else
		self.hurt_inside_timer = self.hurt_inside_timer - dtime
	end
end

--This makes the mob walk at a certain speed and jump
if def.movement_type == "walk" then
    mob_register.move = function(self,dtime)
        self.manage_jump_timer(self,dtime)
        self.timer = self.timer - dtime
        
        --jump
        self.jump(self)
        
        --swim
        self.swim(self,dtime)
        
        --print(self.timer)
        --direction state change
        if self.timer <= 0 and not self.following == true then
            --print("changing direction")
            self.timer = math.random(2,7)
            self.direction = vector.new(math.random()*math.random(-1,1),0,math.random()*math.random(-1,1))
            --local yaw = self.object:get_yaw() + dtime
            self.speed = math.random(0,6)
            --self.object:set_yaw(yaw)
        end

        self.hurt_inside(self,dtime)

        local currentvel = self.object:getvelocity()
        local goal = vector.multiply(self.direction,self.speed)
        local acceleration = vector.new(goal.x-currentvel.x,0,goal.z-currentvel.z)
        acceleration = vector.multiply(acceleration, 0.05)
        self.object:add_velocity(acceleration)
    end
    --use raycasting to jump
    mob_register.jump = function(self)
        if self.jump_timer <= 0 then
            local vel = self.object:get_velocity()
            if (self.direction.x ~= 0 and vel.x == 0) or (self.direction.z ~= 0 and vel.z == 0) then
                local pos = self.object:get_pos()
                local ground_distance = self.object:get_properties().collisionbox[2]
                local ray = minetest.raycast(pos, vector.add(pos, vector.new(0,ground_distance*1.1,0)), false, false)	
                if ray then
                    for pointed_thing in ray do
                        local collision_point = pointed_thing.under
                        if collision_point then
                            local walkable = minetest.registered_nodes[minetest.get_node(collision_point).name].walkable
                            if walkable then
                                local distance = vector.subtract(collision_point,pos).y-self.object:get_properties().collisionbox[2]+0.4
                                if distance >= -0.11 then
                                    local vel = self.object:get_velocity()
                                    self.jump_timer = 0.5
                                    self.object:add_velocity(vector.new(vel.x,5,vel.z))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
elseif def.movement_type == "jump" then
    mob_register.move = function(self,dtime)
        self.manage_jump_timer(self,dtime)
        self.timer = self.timer - dtime
        
        --jump
        self.jump(self)
        
        --swim
        self.swim(self,dtime)
        
        --print(self.timer)
        --direction state change
        if self.timer <= 0 and not self.following == true then
            --print("changing direction")
            self.timer = math.random(2,7)
            self.direction = vector.new(math.random()*math.random(-1,1),0,math.random()*math.random(-1,1))
            --local yaw = self.object:get_yaw() + dtime
            self.speed = math.random(0,6)
            --self.object:set_yaw(yaw)
        end

        self.hurt_inside(self,dtime)	
        
        local currentvel = self.object:getvelocity()
        if currentvel.y ~= 0 then
            local goal = vector.multiply(self.direction,self.speed)
            local acceleration = vector.new(goal.x-currentvel.x,0,goal.z-currentvel.z)
            acceleration = vector.multiply(acceleration, 0.05)
            self.object:add_velocity(acceleration)
        end
    end
    
    mob_register.jump = function(self)
        local vel = self.object:get_velocity()
        if self.jump_timer <= 0 then
            if vel.y == 0 and self.oldvely and self.oldvely <= 0 then --use <= on self.oldvely to make slime make landing sound
                minetest.sound_play("slime_splat", {object=self.object, gain = 1.0, max_hear_distance = 10,pitch = math.random(80,100)/100})
                local vel = self.object:get_velocity()
                self.jump_timer = 1+math.random()
                if self.hostile == true then
                    self.jump_timer = 0.5
                end
                local goal = vector.multiply(self.direction,self.speed)
                self.object:set_velocity(vector.new(goal.x,5,goal.z))
            end
        end
        if vel.y == 0 and self.oldvely and self.oldvely < 0 then
            self.object:set_velocity(vector.new(0,0,0))
        end
        self.oldvely = vel.y
    end
end

mob_register.look_around = nil
if def.has_head then
    --the pig will look for and at players
    mob_register.look_around = function(self,dtime)
        local pos = self.object:get_pos()
        
        --STARE O_O
        --and follow!
        self.following = false
        local player_found = false
        for _,object in ipairs(minetest.get_objects_inside_radius(pos, 6)) do
            if object:is_player() and player_found == false and object:get_hp() > 0 then
                --look at player's camera
                local pos2 = object:get_pos()
                pos2.y = pos2.y + 1.625
                
                player_found = true
                
                self.move_head(self,pos2,dtime)
                
                if self.hostile == true then
                    self.direction = vector.direction(pos,pos2)
                    local distance = vector.distance(pos,pos2)-2
                    if distance < 0 then
                        distance = 0
                    end
                    
                    --punch the player
                    if distance < 1 and self.punch_timer <= 0 and object:get_hp() > 0 then
                        local line_of_sight = minetest.line_of_sight(pos, pos2)
                        if line_of_sight == true then
                            self.punch_timer = 1
                            object:punch(self.object, 2, 
                                {
                                full_punch_interval=1.5,
                                damage_groups = {fleshy=2},
                            },vector.direction(pos,pos2))
                        end
                    end
                    self.speed = distance * 4
                    if self.speed > 6 then
                        self.speed = 6
                    end
                    self.following = true
                end
                --only look at one player
                break
            end
        end
        --stare straight if not found
        if player_found == false then
            self.move_head(self,nil,dtime)
            if self.manage_hostile_timer then
                self.manage_hostile_timer(self,dtime)
            end
        end
    end

end

--converts the degrees to radians
local degrees_to_radians = function(degrees)
	--print(d)
	return(degrees/180.0*math.pi)
end

--converts yaw to degrees
local degrees = function(yaw)
	return(yaw*180.0/math.pi)
end

--rounds it up to an integer
local degree_round = function(degree)
	return(degree + 0.5 - (degree + 0.5) % 1)
end
--turns radians into degrees - not redundant
--doesn't add math.pi
local radians_to_degrees = function(radians)
	return(radians*180.0/math.pi)
end


--make sure this is redefined as shown below aka
--don't run mob_rotation_degree_to_radians(rotation)
--run local radians = mob_rotation_degree_to_radians(rotation)
--or the mobs head rotation will become overwritten
local head_rotation_to_radians = function(rotation)
	return{
		x = 0, --roll should never be changed
		y = degrees_to_radians(180 - rotation.y)*-1,
		z = degrees_to_radians(90 - rotation.z)
	}
end

--a movement test to move the head
mob_register.move_head = function(self,pos2,dtime)
	if self.child then
		--print(self.head_rotation.y)
		--if passed a direction to look
		local pos = self.object:get_pos()
		local body_yaw = self.object:get_yaw()
		local dir = vector.multiply(minetest.yaw_to_dir(body_yaw),0.58)
		local body_yaw = minetest.dir_to_yaw(dir)
		--save the yaw for debug
		
		--pos is where the head actually is
		pos = vector.add(pos,dir)
		pos.y = pos.y + 0.36
		--use this to literally look around
		self.head_pos = pos
				
		--if the function was given a pos
		if pos2 then

			local pitch = 0
			--compare the head yaw to the body
			local head_yaw = minetest.dir_to_yaw(vector.direction(pos,pos2))
			local goal_yaw = body_yaw-head_yaw
			
			--if within range then do calculations
			if goal_yaw <= math.pi/2 and goal_yaw >= -math.pi/2 then
				
				local current_yaw = self.head_rotation.y
				--smoothly move head using dtime
				if current_yaw > goal_yaw then
					current_yaw = current_yaw - (dtime*5)
				elseif current_yaw < goal_yaw then
					current_yaw = current_yaw + (dtime*5)
				end
				
				--stop jittering
				if math.abs(goal_yaw - current_yaw) <= (dtime*5) then
					current_yaw = goal_yaw
				end
				
				---begin pitch calculation
				
				--feed a 2D coordinate flipped into dir to yaw to calculate pitch
				local goal_pitch = (minetest.dir_to_yaw(vector.new(vector.distance(vector.new(pos.x,0,pos.z),vector.new(pos2.x,0,pos2.z)),0,pos.y-pos2.y))+(math.pi/2))*-1
				
				local current_pitch = self.head_rotation.z
								
				--smoothly move head using dtime
				if goal_pitch > current_pitch then
					current_pitch = current_pitch + (dtime*5)
				elseif goal_pitch < current_pitch then
					current_pitch = current_pitch - (dtime*5)
				end
				
				--stop jittering
				if math.abs(goal_pitch - current_pitch) <= (dtime*5) then
					current_pitch = goal_pitch
				end
				
				--convert this into degrees for the attach code
				local deg_yaw = degrees(current_yaw)
				--this is rounded because it uses animation frames baked into the head model
				local deg_pitch = math.floor(degrees(current_pitch) + 0.5)+90


				self.child:set_attach(self.object, "", self.head_mount, vector.new(0,   deg_yaw , 0))
				self.child:set_animation({x=deg_pitch,y=deg_pitch}, 15, 0, true)	
				self.head_rotation = vector.new(0,    current_yaw,    current_pitch)
				
				return(true)
			--nothing to look at
			else
				self.return_head_to_origin(self,dtime)
				return(false)
			end
			
		--if nothing to look at
		else
			self.return_head_to_origin(self,dtime)
			return(false)
		end
	end
end


--this sets the mob to move it's head back to pointing forwards
mob_register.return_head_to_origin = function(self,dtime)
	local current_yaw = self.head_rotation.y
	local current_pitch = self.head_rotation.z
	
	--make the head yaw move back
	if current_yaw > 0 then
		current_yaw = current_yaw - (dtime*5)
	elseif current_yaw < 0 then
		current_yaw = current_yaw + (dtime*5)
	end
	
	--finish rotation
	if math.abs(current_yaw) <= (dtime*5) then
		current_yaw = 0
	end
	
	--move up down (pitch) back to center
	if current_pitch > 0 then
		current_pitch = current_pitch - (dtime*5)
	elseif current_pitch < 0 then
		current_pitch = current_pitch + (dtime*5)
	end
	
	--finish rotation
	if math.abs(current_pitch) <= (dtime*5) then
		current_pitch = 0
	end
	
	--convert this into degrees for the attach code
	local deg_yaw = degrees(current_yaw)
	--this is rounded because it uses animation frames baked into the head model
	local deg_pitch = math.floor(degrees(current_pitch) + 0.5)+90
	
	self.child:set_attach(self.object, "", self.head_mount, vector.new(0,   deg_yaw , 0))
	self.child:set_animation({x=deg_pitch,y=deg_pitch}, 15, 0, true)	
	self.head_rotation = vector.new(0,    current_yaw,    current_pitch)
end


mob_register.on_step = function(self, dtime)
    
    
	if self.dead == false and self.death_animation_timer == 0 then
		self.move(self,dtime)
		self.set_animation(self)
        
        if self.look_around then
            self.look_around(self,dtime)
        end
        
		self.manage_punch_timer(self,dtime)
		--self.debug_nametag(self,dtime)
	else
		self.manage_death_animation(self,dtime)
	end
	--fix zombie state again
	if self.dead == true and self.death_animation_timer <= 0 then
		self.on_death(self)
	end
end

minetest.register_entity("mob:"..def.mobname, mob_register)


if def.has_head == true then
    mob_register.head = {}
    mob_register.head.initial_properties = {
        hp_max = 1,
        physical = false,
        collide_with_objects = false,
        collisionbox = {0, 0, 0, 0, 0, 0},
        visual =  def.head_visual,
        visual_size = def.head_visual_size,
        mesh = def.head_mesh,
        textures = def.head_textures,
        is_visible = true,
        pointable = false,
        --automatic_face_movement_dir = 0.0,
        --automatic_face_movement_max_rotation_per_sec = 600,
    }

    --remove the head if no body
    mob_register.head.on_step = function(self, dtime)
        if self.parent == nil then
            self.object:remove()
        end
    end
    minetest.register_entity("mob:head"..def.mobname, mob_register.head) 
end
------------------------------------------------

end


mobs.register_mob(
    {
    mobname = "pig",
	physical = true,
	collide_with_objects = false,
	collisionbox = {-0.37, -0.4, -0.37, 0.37, 0.5, 0.37},
	visual = "mesh",
	visual_size = {x = 3, y = 3},
	mesh = "pig.x",
	textures = {
		"body.png","leg.png","leg.png","leg.png","leg.png"
	},
	is_visible = true,
	pointable = true,
	automatic_face_movement_dir = -90.0,
	automatic_face_movement_max_rotation_per_sec = 300,
	makes_footstep_sound = false,
    hp = 10,
    gravity = {x = 0, y = -9.81, z = 0},
    movement_type = "walk",
    speed = 5,
    hostile = false,
    state = 0,
    view_distance = 20,
     
     
    standing_frame = {x=0,y=0},
    moving_frame = {x=5,y=15},
    animation_multiplier = 5,
    ----
     
    has_head = true, --remove this when mesh based head rotation is implemented
    head_visual = "mesh",
    head_visual_size = {x = 1.1, y = 1.1},
    head_mesh = "pig_head.x",
    head_textures ={"head.png","nose.png"},
    head_mount = vector.new(0,1.2,1.9),
    }
)


mobs.register_mob(
    {
    mobname = "slime",
	physical = true,
	collide_with_objects = false,
	collisionbox = {-0.37, -0.4, -0.37, 0.37, 0.5, 0.37},
	visual = "mesh",
	visual_size = {x = 3, y = 3},
	mesh = "slime.x",
	textures = {
		"slimecore.png","slimeeye.png","slimeeye.png","slimeeye.png","slimeoutside.png"
	},
	is_visible = true,
	pointable = true,
	automatic_face_movement_dir = 180,
	automatic_face_movement_max_rotation_per_sec = 300,
	makes_footstep_sound = false,
    hp = 10,
    gravity = {x = 0, y = -9.81, z = 0},
    movement_type = "jump",
    speed = 5,
    hostile = true,
    state = 0,
    view_distance = 40,
     
     
    standing_frame = {x=0,y=0},
    moving_frame = {x=0,y=0},
    animation_multiplier = 5,
    ----
    has_head = false, --remove this when mesh based head rotation is implemented
    }
)