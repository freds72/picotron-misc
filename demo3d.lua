-- textured 3d demo
-- by freds72

-- globals
local cam
local _textures={}

-- helper functions
function lerp(a,b,t)
	return a*(1-t)+b*t
end

-- vector helpers
function v_normz(v)
	local d=v:magnitude()
	if d>0 then
		return vec(v.x/d,v.y/d,v.z/d)
	end
	return vec(0,0,0)
end

function m_print(m,xx,yy,c)
	for j=0,3 do
	 local x,y,z=m:get(0,j,3)
	 print(string.format("%.3f\t%.3f\t%.3f",x,y,z),xx,yy,c)
	 yy+=8
	end
end

function v_print(v,xx,yy,c)
 local x,y,z=v:get(0,4)
 print(string.format("%.3f\t%.3f\t%.3f",x,y,z),xx,yy,c)  
end

function make_m()
	local m = userdata("f64",3,4)
	set(m, 0, 0,
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
		0, 0, 0)
	return m
end

function m_transpose(m)
	m[1],m[3]=m[3],m[1]
	m[2],m[6]=m[6],m[2]
	m[5],m[7]=m[7],m[5]
end

function m_translate(v)
	local m = userdata("f64",3,4)
	local x,y,z=v:get(0,3)
	set(m, 0, 0,
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
		x, y, z)
	return m
end

function m_rotation(axis,angle)
	local c,s=cos(angle),-sin(angle)
	local m = userdata("f64",3,4)
	if axis=="x" then
		set(m, 0, 0,
			1, 0,  0,  
			0, c, -s,
			0, s,  c, 
			0, 0,  0)		
	elseif axis=="y" then
		set(m, 0, 0,
			c,  0, s, 
			0,  1, 0, 
			-s, 0, c,
			0, 0, 0)
	else
		set(m,   0, 0,
			c, -s, 0,
			s, c,  0,
			0, 0,  1,
			0, 0,  0)		
	end
	return m
end

function m_fwd(m)
	return vec(m[2],m[6],m[10],0)
end

function prepare_model(model)
	for _,f in pairs(model.f) do
		-- de-reference vertex indices
		for i=1,4 do
			f[i]=model.v[f[i]]
		end

		-- normal
		f.n=v_normz((f[4]-f[1]):cross(f[2]-f[1]))
		-- fast viz check
		f.cp=f.n:dot(f[1])
	end
	return model
end

-- models
local cube_model=prepare_model({
		v={
			vec(0,0,0),
			vec(1,0,0),
			vec(1,0,1),
			vec(0,0,1),
			vec(0,1,0),
			vec(1,1,0),
			vec(1,1,1),
			vec(0,1,1),
		},
		-- faces + vertex uv's
		-- NOTE: must use <4 to avoid texture spilling
		f={
			{1,4,3,2,uv={0,0,3.99,0,3.99,3.99,0,3.99}},
			{1,2,6,5,uv={0,0,3.99,0,3.99,3.99,0,3.99}},
			{2,3,7,6,uv={0,0,3.99,0,3.99,3.99,0,3.99}},
			{3,4,8,7,uv={0,0,3.99,0,3.99,3.99,0,3.99}},
			{4,1,5,8,uv={0,0,3.99,0,3.99,3.99,0,3.99}},
			{5,6,7,8,uv={0,0,3.99,0,3.99,3.99,0,3.99}},
		}
	})


local conf={
	fov=110
}
local fov = cos(conf.fov/360/2)
local h_ratio,v_ratio=(480-480/2)/270/fov,(270-270/2)/270/fov

function make_cam(x0,y0,focal)
	local yangle,zangle=0,0.25
	local dyangle,dzangle=0,0

	return {
		pos=vec(0,0,0),
		control=function(self,dist)
			if btn(0) then dyangle+=1 end
			if btn(1) then dyangle+=-1 end
			if btn(2) then dzangle+=1 end
			if btn(3) then dzangle+=-1 end
			yangle+=dyangle/256--+0.01
			zangle+=dzangle/256--+0.005
			-- friction
			dyangle*=0.8
			dzangle*=0.8
			
			local m=m_rotation("x",zangle):matmul3d(m_rotation("z",yangle))
			local pos=vec(0,0,-dist):matmul3d(m)

			-- inverse view matrix
			--m:transpose(m)
			m[1],m[3]=m[3],m[1]
			m[2],m[6]=m[6],m[2]
			m[5],m[7]=m[7],m[5]

			self.m=m_translate(pos*-1):matmul3d(m)
			self.pos=pos			
		end,
		project=function(self,verts)
			local out={}
			--for i,vert in pairs(verts) do
			for i=1,#verts do
			  local vert=verts[i]
				local v=vert.pos
				local x,y,z=v:get(0,3)
				local w=fov/z
				out[i]={x=x0+270*x*w,y=y0-270*y*w,w=w,u=vert.u,v=vert.v}
			end
			return out
		end
	}
end

local _m_inv=userdata("f64",3,4)
function draw_model(model,m_obj,cam,id)
	-- cam pos in object space
	set(_m_inv,0,0,get(m_obj,0,0,9))
	m_transpose(_m_inv)
	--m_obj:transpose(m_inv)
	local cam_pos=cam.pos:matmul3d(m_translate(vec(-m_obj[9],-m_obj[10],-m_obj[11])):matmul3d(_m_inv))
	
	-- object to world
	-- world to cam
	local m=m_obj:matmul3d(cam.m)
	local m_n=make_m()
	set(m_n,0,0,get(m,0,0,9))

	for i,face in pairs(model.f) do
		-- is face visible?
		if face.n:dot(cam_pos)>face.cp then
			local avg=vec(0,0,0)
			local verts,outcode,nearclip={},0xffffffff,0
			for k,v in ipairs(face) do
				-- transform to cam
				local code,a=2,v:matmul3d(m)
				avg:add(a,true)
				if(a.z>1) code=0
				local w=fov/a.z
				-- attach u/v coords to output
				verts[k]=vec(480/2+270*w*a.x,270/2-270*w*a.y,a.z,w,face.uv[2*k-1]*16*w,face.uv[2*k]*16*w)
				outcode&=code
				nearclip+=code&2
			end
			-- out of screen?
			if outcode==0 then
				if nearclip!=0 then                
					-- near clipping required?
					local w,res,v0=cam.focal,{},verts[#verts]
					local d0=v0.z-1
					for i,v1 in ipairs(verts) do
						local side=d0>0
						if(side) add(res,v0)
						local d1=v1.z-1
						if (d1>0)!=side then
							-- clip!
							-- project
							-- z is clipped to near plane
							add(res,lerp(v0,v1,d0/(d0-d1)))
						end
						v0,d0=v1,d1
					end
					verts=res
				end			
				polytex(verts,#verts,_textures[id%16],i)
				--polyline(verts,#verts,7)

				-- debug: draw normals
				--avg/=4
				--local tmp=cam:project({{pos=avg},{pos=avg+(face.n*0.25):matmul3d(m_n)}})
				--line(tmp[1].x,tmp[1].y,tmp[2].x,tmp[2].y,8)
			end
		end
	end
	--v_print(cam_pos,0,64,7)
	--m_print(m_inv,0,96,7)
	   
  --line(480/2,270/2,480/2+64*cam.pos.x,270/2-64*cam.pos.z,7)
end

function _init()
	cam=make_cam(480/2,270/2,480/2)
	
	-- create a texture bitmap and draw something on it
	for k=0,15 do
		local ss = userdata("u8",32,32)
		for i=0,32*32-1 do
			local x,y=i%32,flr(i/32)
			local c=k
			if (x<16 and y<16) or (x>=16 and y>=16) then
				c=k+1
			end
			set(ss,x,y,c)
		end
		_textures[k]=ss
	end

	-- set_draw_target(ss)
	-- circ(16,16,4,7)
	set_draw_target()
end

function _update()
	cam:control(4.5)
end

local _t=time()
function _draw()
	cls()

   srand(42)
	local r={"x","y","z"}
	for i=-2,3 do
		for j=-2,3 do			
			local m = m_translate(vec(-0.5,-0.5,-0.5)):matmul3d(m_rotation(rnd(r),(0.125*i*j))):matmul3d(m_translate(vec(2*i,2*j,0)))
			draw_model(cube_model,m,cam,(i+5*j))
		end
	end

	--local m = m_translate(vec(-0.5,-0.5,-0.5)):matmul3d(m_rotation("y",time()/16)):matmul3d(m_translate(vec(2.5,0,0)))
	--draw_model(cube_model,m,cam)
	
	local t1=time()
	local s=string.format("tline3d DEMO\nfps: %.i\ncpu: %.3f",flr(1/(t1-_t)),100*stat(1))
	for i=-1,1 do
		for j=-1,1 do
			print(s,2+i,2+j,0)
		end
	end
	print(s,2,2,7)
	_t = t1
end

-->8 {}
function polytex(p,np,texture,color)
	local miny,maxy,mini=32000,-32000
	-- find extent
	for i=1,np do
		local y=p[i].y
		if y<miny then
			mini,miny=i,y
		end
		if y>maxy then
			maxy=y
		end
	end

	--data for left & right edges:
	local lj,rj,ly,ry,l,r,dl,dr=mini,mini,miny,miny,vec(0,0,0,0,0,0),vec(0,0,0,0,0,0),vec(0,0,0,0,0,0),vec(0,0,0,0,0,0)
	if maxy>=270 then
		maxy=270-1
	end
	if miny<0 then
		miny=-1
	end
	for y=flr(miny)+1,maxy do
		--maybe update to next vert
		while ly<y do
			local v0=p[lj]
			lj=lj+1
			if lj>np then lj=1 end
			local v1=p[lj]
			local y0,y1=v0.y,v1.y
			ly=y1\1
			set(l,0,get(v0,0,6))
			set(dl,0,get(v1,0,6))
			dl:sub(v0,true):div(y1-y0,true)
			--sub-pixel correction
			l:add(dl * (y-y0),true)
		end   
		while ry<y do
			local v0=p[rj]
			rj=rj-1
			if rj<1 then rj=np end
			local v1=p[rj]
			local y0,y1=v0.y,v1.y
			ry=y1\1
			set(r,0,get(v0,0,6))
			set(dr,0,get(v1,0,6))
			dr:sub(v0,true):div(y1-y0,true)
			--sub-pixel correction
			r:add(dr * (y-y0),true)
		end
		
		local lx,_,_,lw,lu,lv=get(l,0,6)
		local rx,_,_,rw,ru,rv=get(r,0,6)
		if rx>=0 and lx<480 then
			local dx=rx-lx
			local du,dv,dw=(ru-lu)/dx,(rv-lv)/dx,(rw-lw)/dx
			if lx<0 then
				lu-=lx*du
				lv-=lx*dv
				lw-=lx*dw
				lx=0
			end
			-- sub-pixel correction
			local sx=1-lx%1
			lu+=sx*du
			lv+=sx*dv
			lw+=sx*dw
			--tline3d(texture,lx\1,y,rx,y,lu,lv,ru,rv,lw,rw)
			spanfill(lx\1,rx\1-1,y,lu,lv,lw,ru,rv,rw,function(...)
			 tline3d(...)
			 if(btn(4)) flip()
			end,texture)
		end

		l:add(dl,true)
		r:add(dr,true)
  end
end

function polyline(p,np,c)
 local p0=p[np]
 for i=1,np do
		local p1=p[i]
		line(p0.x,p0.y,p1.x,p1.y,c)
		p0=p1
 end
end

-- basic pool
local PoolCls=function(name,stride,size)
	local cursor,total=0,size*stride
	local pool=userdata("f64",total)
	return setmetatable({
			-- reserve an entry in pool
			pop=function(self,...)
					-- init values
					local idx=cursor
					cursor += stride
					if cursor>=total then
							assert(false,"Pool: "..name.." full: "..cursor.."/"..total)
					end
					set(pool,idx,...)
					return idx
			end,
			-- returns the underlying userdata array
			ptr=function() return pool end,
			-- reclaim everything
			reset=function(self)
					cursor = 0
			end,
			stats=function(self)   
					return "pool:"..name.." free: "..((total-cursor)/stride).." size: "..(total/stride)
			end
		},{
			-- redirect get/set to underlying array
			__index = function(self,k)
					return get(pool,k)
			end,
			__newindex = function(self, key, value)
					set(pool,key,value)
			end
	})
end


-- span buffer
local _pool=PoolCls("spans",5,25000)
local _spans={}
function spanfill(x0,x1,y,u0,v0,w0,u1,v1,w1,fn,texture)	
	if x1<0 or x0>480 or x1-x0<0 then
		return
	end
	local _spans,span,_pool,_ptr,old=_spans,_spans[y],_pool,_pool:ptr()
	-- fn = overdrawfill

	local dx=x1-x0
	local du,dv,dw=(u1-u0)/dx,(v1-v0)/dx,(w1-w0)/dx
	local au,av,aw=u0-x0*du,v0-x0*dv,w0-x0*dw
	-- empty scanline?
	if not span then
		fn(texture,x0,y,x1,y,u0,v0,u1,v1,w0,w1)
		_spans[y]=_pool:pop(x0,x1,w0,dw,-1)
		return
	end

	-- loop while valid address
	while span>=0 do		
		local s0,s1=get(_ptr,span,2)

		if s0>x0 then
			if s0>x1 then
				-- nnnn
				--       xxxxxx	
				-- fully visible
				fn(texture,x0,y,x1,y,u0,v0,u1,v1,w0,w1)
				local n=_pool:pop(x0,x1,w0,dw,span)
				if old then
					-- chain to previous
					set(_ptr,old+4,n)
				else
					-- new first
					_spans[y]=n
				end
				return
			end

			-- nnnn?????????
			--     xxxxxxx
			-- clip + display left
			local x2=s0-1
			local dx=x2-x0
			fn(texture,x0,y,x2,y,u0,v0,au+x2*du,av+x2*dv,w0,aw+x2*dw)
			local n=_pool:pop(x0,x2,w0,dw,span)
			if old then 
				set(_ptr,old+4,n)
			else
				_spans[y]=n
			end
			old=n

			x0=s0
			--assert(x1-x0>=0,"empty right seg")
			u0+=dx*du
			v0+=dx*dv
			w0+=dx*dw
			-- check remaining segment
			goto continue
		elseif s1>=x0 then
			--     ??nnnn????
			--     xxxxxxx	

			--     ??nnnn?
			--     xxxxxxx	
			-- totally hidden (or not!)
			local dx,sdw=x0-s0,get(_ptr,span+3)
			local sw=get(_ptr,span+2)+dx*sdw		
			
			-- use scaled precision for abutting spans (see Christer Ericson)
			-- use absolute distance for other planes
			if sw-w0<-0.00001 or (abs(sw-w0)<=1e-5*max(abs(sw),max(abs(w0),1)) and dw>sdw) then
				--printh(sw.."("..dx..") "..w.." w:"..span.dw.."<="..dw)	
				-- insert (left) clipped existing span as a "new" span
				if dx>0 then
					local n=_pool:pop(
						s0,
						x0-1,
						get(_ptr,span+2),
						sdw,
						span)
					if old then
						set(_ptr,old+4,n)
					else
						-- new first
						_spans[y]=n
					end
					old=n
				end
				-- middle ("new")
				--     ??nnnnn???
				--     xxxxxxx			
				-- draw only up to s1
				local x2=s1<x1 and s1 or x1
				fn(texture,x0,y,x2,y,u0,v0,au+x2*du,av+x2*dv,w0,aw+x2*dw)					
				local n=_pool:pop(x0,x2,w0,dw,span)
				if old then 
					set(_ptr,old+4,n)
				else
					-- new first
					_spans[y]=n
				end
				old=n

				-- any remaining "right" from current span?
				local dx=s1-x1-1
				if dx>0 then
					-- "shrink" current span
					set(_ptr,span,x1+1)
					set(_ptr,span+2,get(_ptr,span+2)+(x1+1-s0)*sdw)
				else
					-- drop current span
					set(_ptr,old+4,get(_ptr,span+4))
					span=old
				end					
			end

			if s1>=x1 then
				--     ///////
				--     xxxxxxx	
				return
			end
			--         ///nnn
			--     xxxxxxx
			-- clip incomping segment
			--assert(dx>=0,"empty right (incoming) seg")
			-- 
			local dx=s1+1-x0
			x0=s1+1
			u0+=dx*du
			v0+=dx*dv
			w0+=dx*dw

			--            nnnn
			--     xxxxxxx	
			-- continue + test against other spans
		end
		old=span	
		span=get(_ptr,span+4)
::continue::
	end
	-- new last?
	if x1-x0>=0 then
		fn(texture,x0,y,x1,y,u0,v0,u1,v1,w0,w1)
		-- end of spans		
		set(_ptr,old+4,_pool:pop(x0,x1,w0,dw,-1))
	end
end

local draw=_draw
function _draw()
	draw()
	print(_pool:stats(),2,36,7)

	_pool:reset()
	_spans={}
end