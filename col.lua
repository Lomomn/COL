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

local pprint = require('pprint')
local Col = Class{__name = 'Col'}

local Circle = Class{__name = 'Circle'}
function Circle.init(self, x,y,r, scene)
    if not(x and y and r and scene) then error('Missing arg to Circle') end
    self.x,self.y,self.r,self.scene = x,y,r,scene
end
function Circle.draw(self)
    love.graphics.circle('fill',self.x,self.y,self.r)
end
function Circle.move(self,x,y)
    self.scene:remove(self)
    self.x,self.y = self.x+x,self.y+y
    self.scene:insert(self)
end
function Circle.center(self)
    return self.x,self.y
end


local Rectangle = Class{__name = 'Rectangle'}
function Rectangle.init(self, x,y,w,h, scene)
    if not(x and y and w and h and scene) then error('Missing arg to Rectangle') end
    self.x,self.y,self.w,self.h,self.scene = x,y,w,h,scene
end
function Rectangle.draw(self)
    love.graphics.rectangle('fill',self.x,self.y,self.w,self.h)
end
function Rectangle.move(self,x,y)
    self.scene:remove(self)
    self.x,self.y = self.x+x,self.y+y
    self.scene:insert(self)
end

local abs = math.abs

function Col.init(self, size)
    self.size = size or 128 -- 128 units wide and high
    self.cells = getAutoTable()
end
function Col.getObjectBounds(self, object)
    if object.parents[Circle] then
        return math.floor(object.y/self.size), math.floor(object.x/self.size),
            math.floor((object.y+object.r)/self.size), math.floor((object.x+object.r)/self.size)
    else
        return math.floor(object.y/self.size), math.floor(object.x/self.size),
            math.floor((object.y+object.h)/self.size), math.floor((object.x+object.w)/self.size)
    end
end
function Col.alterCell(self, object, value)
    local cy,cx,cy2,cx2 = self:getObjectBounds(object)
    self.cells[cy][cx][object] = value
    self.cells[cy2][cx2][object] = value
    self.cells[cy][cx2][object] = value
    self.cells[cy2][cx][object] = value
end
function Col.remove(self, object)
    self:alterCell(object, nil)
end
function Col.insert(self, object)
    self:alterCell(object, true)
end
function Col.overlaps(self, o1, o2)
    if o1.parents[Circle] and o2.parents[Circle] then
        return (math.abs(o1.x-o2.x)<(o1.r+o2.r)) and (math.abs(o1.y-o2.y)<(o1.r+o2.r))
    elseif o1.parents[Rectangle] and o2.parents[Rectangle] then
        
    elseif (o1.parents[Rectangle] or o2.parents[Circle]) or (o1.parents[Circle] or o2.parents[Rectangle]) then
        if o1.parents[Rectangle] then
            -- Make o1 the circle and o2 the rectangle
            o1,o2 = o2,o1
        end
        return (math.abs(o1.x-(o2.x+o2.w/2))<(o1.r+o2.w/2)) and (math.abs(o1.y-(o2.y+o2.h/2))<(o1.r+o2.h/2))
    end
end

function Col.collideSingle(self, object)
    local cy,cx,cy2,cx2 = self:getObjectBounds(object)
    local cells = {}
    -- Automatically removes duplicates
    cells[self.cells[cy][cx]] = true
    cells[self.cells[cy2][cx2]] = true
    cells[self.cells[cy][cx2]] = true
    cells[self.cells[cy2][cx]] = true
    
    local candidates = {}
    for cell,_ in pairs(cells) do
        for other in pairs(cell) do
            if not(object == other) then
                if Col:overlaps(object, other) then
                    candidates[other] = true
                end
            end
        end
    end
end
function Col.collideList(self, object, list, callback)
    local cy,cx,cy2,cx2 = self:getObjectBounds(object)
    local cells = {}
    -- Automatically removes duplicates
    cells[self.cells[cy][cx]] = true
    cells[self.cells[cy2][cx2]] = true
    cells[self.cells[cy][cx2]] = true
    cells[self.cells[cy2][cx]] = true
    
    local candidates = {}
    for cell,_ in pairs(cells) do
        for other in pairs(cell) do
            if not(object == other) then
                if Col:overlaps(object, other) then
                    candidates[other] = true
                end
            end
        end
    end
end
function Col.collideTwoLists(self, list1, list2, callback, hitboxName)
    for shape,_ in pairs(list2) do
        local cy,cx,cy2,cx2 = self:getObjectBounds(shape)
        local cells = {}
        -- Automatically removes duplicates
        cells[self.cells[cy][cx]] = true
        cells[self.cells[cy2][cx2]] = true
        cells[self.cells[cy][cx2]] = true
        cells[self.cells[cy2][cx]] = true
        
        local candidates = {}
        for cell,_ in pairs(cells) do
            for other in pairs(cell) do
                if not(shape == other) then
                    if Col:overlaps(shape, other) then
                        candidates[other] = true
                    end
                end
            end
        end
    end
end

function Col.collisions(self, object1, object2)
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