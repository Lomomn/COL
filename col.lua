--[[
    The shapes should have a parent object like so:

    function GameObject.init(self)
        ...

        self.bounds = {}
        self.bounds['hitbox'] = scene:Circle(0,0,16)
        self.bounds['hitbox'].parent = self

        ...
    end
--]]

function getAutoTable()
    return setmetatable({}, {
        __index = function(self, k)
            rawset(self,k,setmetatable({}, {
                __index = function(self, k)
                    rawset(self,k,{})
                    return self[k]
                end,
                __newindex = function(self, k,v)end}))
            return self[k]
        end,
        __newindex = function(self, k,v)end})
end

local Col = Class{__name = 'Col'}

local abs = math.abs
local floor = math.floor


local Circle = Class{__name = 'Circle'}
function Circle.init(self, x,y,r, scene)
    if not(x and y and r and scene) then error('Missing arg to Circle') end
    self.x,self.y,self.r,self.scene = x,y,r,scene
    self.w,self.h = self.r*2, self.r*2
end
function Circle.draw(self)
    love.graphics.circle('fill',self.x,self.y,self.r)
end
function Circle.move(self,x,y)
    self.scene:remove(self)
    self.x,self.y = self.x+x,self.y+y
    self.scene:insert(self)
end
function Circle.moveTo(self, x,y)
    self.scene:remove(self)
    self.x,self.y = x,y
    self.scene:insert(self)
end
function Circle.center(self)
    return self.x,self.y
end
function Circle.bbox(self)
    return self.x-self.r, self.y-self.r, self.x+self.r, self.y+self.r
end


local Rectangle = Class{__name = 'Rectangle'}
function Rectangle.init(self, x,y,w,h, scene)
    if not(x and y and w and h and scene) then error('Missing arg to Rectangle') end
    self.x,self.y,self.w,self.h,self.scene = x,y,w,h,scene
end
function Rectangle.draw(self)
    love.graphics.rectangle('line',self.x,self.y,self.w,self.h)
end
function Rectangle.move(self, x,y)
    self.scene:remove(self)
    self.x,self.y = self.x+x,self.y+y
    self.scene:insert(self)
end
function Rectangle.moveTo(self, x,y)
    self.scene:remove(self)
    self.x,self.y = x-self.w/2,y-self.h/2
    self.scene:insert(self)
end
function Rectangle.center(self)
    return self.x+self.w/2,self.y+self.h/2
end
function Rectangle.bbox(self)
    return self.x, self.y, self.x+self.w, self.y+self.h
end


function Col.init(self, size)
    self.size = size or 128 -- 128 units wide and high
    self.cells = getAutoTable()
end
function Col.alterCell(self, object, value)
    local cells = self:getObjectCells(object)

    for cell,_ in pairs(cells) do
        cell[object] = value
    end
end
function Col.remove(self, object)
    self:alterCell(object, nil)
end
function Col.insert(self, object)
    self:alterCell(object, true)
end
function Col.overlaps(self, o1, o2)
    if o1.parents[Circle] and o2.parents[Circle] then
        return (abs(o1.x-o2.x)<(o1.r+o2.r)) and (abs(o1.y-o2.y)<(o1.r+o2.r))
    elseif o1.parents[Rectangle] and o2.parents[Rectangle] then
        return (o1.x < o2.x + o2.w and
            o1.x + o1.w > o2.x and
            o1.y < o2.y + o2.h and
            o1.h + o1.y > o2.y)
    elseif (o1.parents[Rectangle] or o2.parents[Circle]) or (o1.parents[Circle] or o2.parents[Rectangle]) then
        -- Make o1 the circle and o2 the rectangle
        if o1.parents[Rectangle] then
            o1,o2 = o2,o1
        end
        return (abs(o1.x-(o2.x+o2.w/2))<(o1.r+o2.w/2)) and (abs(o1.y-(o2.y+o2.h/2))<(o1.r+o2.h/2))
    end
end

function Col.getObjectCells(self, object)
    -- Return all the cells the object is present in
    local cells = {}

    local y = floor(object.y/self.size)
    local x = floor(object.x/self.size)
    local hPoints = floor((object.y+object.h)/self.size)
    local wPoints = floor((object.x+object.w)/self.size)
    for cy=y,hPoints do
        for cx=x,wPoints do
            cells[self.cells[cy][cx]] = true
        end
    end

    return cells
end

function Col.neighbors(self, object)
    local cells = self:getObjectCells(object)
    
    local others = {}
    for cell,_ in pairs(cells) do
        for other in pairs(cell) do
            if not(object == other) then
                others[other] = true
            end
        end
    end
    return others
end


function Col.collideSingle(self, object)
    local candidates = self:neighbors(object)
    
    for other in pairs(candidates) do
        if not(object==other) then
            if Col:overlaps(object, other) then
                candidates[other] = true
            else
                candidates[other] = nil
            end
        end
    end
    return candidates
end
function Col.collideList(self, object, list, callback)
    local hitboxName = hitboxName or 'hitbox'
    local shape = object.bounds[hitboxName]

    local cells = self:getObjectCells(shape)

    for cell,_ in pairs(cells) do
        for other in pairs(cell) do
            if not(object == other.parent) and list[other.parent] then
                if Col:overlaps(shape, other) then
                    callback(object, other.parent)
                end
            end
        end
    end
end
function Col.collideTwoLists(self, list1, list2, callback, hitboxName)
    for object,_ in pairs(list1) do
        local hitboxName = hitboxName or 'hitbox'
        local shape = object.bounds[hitboxName]

        local cells = self:getObjectCells(shape)

        for cell,_ in pairs(cells) do
            for other in pairs(cell) do
                if not(object == other.parent) and list2[other.parent] then
                    if Col:overlaps(shape, other) then
                        callback(object, other.parent)
                    end
                end
            end
        end
    end
end

function Col.collisions(self, object1, object2, callback, hitboxName)
    if object1 and not(object2) then
		return self:collideSingle(object1)
	elseif object1.__name and not(object2.__name) then
		-- object1 is an entity and object2 is a list. object1 should be a bound, object2 should be parent set
		-- returns the object parent
		if next(object2) then
			self:collideList(object1, object2, callback)
		end
	else
		-- assumes both objects are lists
		-- a hitbox name is required as the first object is of parent entities
		if next(object1) and next(object2) then
			self:collideTwoLists(object1, object2, callback, hitboxName)
		end
	end

    return candidates
end

function Col.circle(self, x,y,r)
    local circ = Circle(x,y,r,self)
    self:insert(circ)
    return circ
end

function Col.rectangle(self, x,y,w,h)
    local rect = Rectangle(x,y,w,h,self)
    self:insert(rect)
    return rect
end


function Col.draw(self)
    local lastX,lastY = 0,0
    for y,row in pairs(self.cells) do
        for x,cell in pairs(row) do
            lastX, lastY = x*self.size, y*self.size
            love.graphics.rectangle('line', lastX, lastY, self.size, self.size)
            love.graphics.print((function()
                local c = 0
                for _,_ in pairs(cell) do c = c + 1 end
                return c
            end)(), lastX, lastY)
        end
    end
end


return Col