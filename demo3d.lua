-- textured 3d demo
-- by freds72

-- globals
local cam

-- helper functions
function lerp(a,b,t)
	return a*(1-t)+b*t
end

-- vector helpers
function v_normz(v)
	local d=sqrt(v[0]*v[0]+v[1]*v[1]+v[2]*v[2])
	if d>0 then
		return vec(v.x/d,v.y/d,v.z/d,0)
	end
	return vec(0,0,0,0)
end

function m_print(m,xx,yy,c)
	for j=0,3 do
	 local x,y,z,w=m:get(0,j,4)
	 print(string.format("%.3f\t%.3f\t%.3f\t%.3f",x,y,z,w),xx,yy,c)
	 yy+=8
	end
end

function v_print(v,xx,yy,c)
 local x,y,z,w=v:get(0,4)
 print(string.format("%.3f\t%.3f\t%.3f\t%.3f",x,y,z,w),xx,yy,c)  
end

function make_m()
	local m = userdata("f64",4,4)
	set(m, 0, 0,
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1 
	)
	return m
end

function m_translate(v)
	local m = userdata("f64",4,4)
	local x,y,z=v:get(0,3)
	set(m, 0, 0,
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		x, y, z, 1 
	)
	return m
end

function m_rotation(axis,angle)
	local c,s=cos(angle),-sin(angle)
	local m = userdata("f64",4,4)
	if axis=="x" then
		set(m, 0, 0,
			1, 0, 0, 0,
			0, c, -s, 0,
			0, s, c, 0,
			0, 0, 0, 1)		
	elseif axis=="y" then
		set(m, 0, 0,
			c, 0, s,  0,
			0, 1, 0,  0,
			-s, 0, c, 0,
			0, 0, 0, 1)
	else
		set(m,   0, 0,
			c, -s, 0, 0,
			s, c,  0, 0,
			0, 0,  1, 0,
			0, 0,  0, 1 
		)		
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
		-- NOTE: pure vector without w component
		f.n=v_normz((f[4]-f[1]):cross(f[2]-f[1]))
		-- fast viz check
		f.cp=f.n:dot(f[1])
	end
	return model
end

-- models
local cube_model=prepare_model({
		-- NOTE: must have w=1 to work with translation matrix
		v={
			vec(0,0,0,1),
			vec(1,0,0,1),
			vec(1,0,1,1),
			vec(0,0,1,1),
			vec(0,1,0,1),
			vec(1,1,0,1),
			vec(1,1,1,1),
			vec(0,1,1,1),
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

function make_cam(x0,y0,focal)
	local yangle,zangle=0,0
	local dyangle,dzangle=0,0

	return {
		pos={0,0,0},
		focal=focal,
		control=function(self,dist)
			if btn(0) then dyangle+=1 end
			if btn(1) then dyangle+=-1 end
			if btn(2) then dzangle+=1 end
			if btn(3) then dzangle+=-1 end
			yangle+=dyangle/128--+0.01
			zangle+=dzangle/128--+0.005
			-- friction
			dyangle*=0.8
			dzangle*=0.8
			
			local m=m_rotation("y",yangle):matmul(m_rotation("x",zangle))
			local pos=vec(0,0,-dist,0):matmul(m)
			-- NOTE: needed to make it "translation" compatible
			set(pos,3,1)
			
			-- inverse view matrix
			m:transpose(m)

			self.m=m_translate(pos*-1):matmul(m)
			self.pos=pos			
		end,
		project=function(self,verts)
			local out={}
			--for i,vert in pairs(verts) do
			for i=1,#verts do
			  local vert=verts[i]
				local v=vert.pos
				local x,y,z=v.x,v.y,v.z
				local w=focal/z
				out[i]={x=x0+x*w,y=y0-y*w,w=w,u=vert.u,v=vert.v}
			end
			return out
		end
	}
end

function draw_model(model,m_obj,cam)
	-- cam pos in object space
	local m_inv=make_m()
	m_obj:transpose(m_inv)
	-- NOTE: needed to kill the translation part
	m_inv[12],m_inv[13],m_inv[14]=0,0,0
	local cam_pos=cam.pos:matmul(m_translate(vec(-m_obj[12],-m_obj[13],-m_obj[14])):matmul(m_inv))
	
	-- object to world
	-- world to cam
	local m=m_obj:matmul(cam.m)

	for i,face in pairs(model.f) do
		-- is face visible?
		if face.n:dot(cam_pos)>face.cp then
			local avg=vec(0,0,0,0)
			local verts,outcode,nearclip={},0xffffffff,0
			for k,v in ipairs(face) do
				-- transform to cam
				local code,a=2,v:matmul(m)
				avg+=a
				if(a.z>1) code=0
				local w=cam.focal/a.z
				-- attach u/v coords to output
				verts[k]={pos=a,x=480/2+w*a.x,y=270/2-w*a.y,w=w,u=face.uv[2*k-1]*8,v=face.uv[2*k]*8}	
				outcode&=code
				nearclip+=code&2
			end
			-- out of screen?
			if outcode==0 then
				if nearclip!=0 then                
					-- near clipping required?
					local res,v0={},verts[#verts]
					local d0=v0.pos.z-1
					for i,v1 in ipairs(verts) do
						local side=d0>0
						if(side) add(res,v0)
						local d1=v1.pos.z-1
						if (d1>0)!=side then
							-- clip!
							local t=d0/(d0-d1)
							-- project
							-- z is clipped to near plane
							add(res,{
								x=480/2+lerp(v0.pos.x,v1.pos.x,t)*cam.focal,
								y=270/2-lerp(v0.pos.y,v1.pos.y,t)*cam.focal,
								w=cam.focal, -- 32/1
								u=lerp(v0.u,v1.u,t),
								v=lerp(v0.v,v1.v,t)})
						end
						v0,d0=v1,d1
					end
					verts=res
				end			
				polytex(verts,#verts,ss,i)
				polyline(verts,#verts,7)

				-- debug: draw normals
				avg/=4
				avg[3]=1
				local tmp=cam:project({{pos=avg},{pos=avg+(face.n*0.25):matmul(m)}})
				line(tmp[1].x,tmp[1].y,tmp[2].x,tmp[2].y,8)
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
	ss = userdata("u8",32,32)
	for i=0,32*32-1 do
		local x,y=i%32,flr(i/32)
		local c=7
		if (x<16 and y<16) or (x>=16 and y>=16) then
			c=8
		end
		set(ss,x,y,c)
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

	local m = m_translate(vec(-0.5+4*cos(time()/8),-0.5,-0.5))
	draw_model(cube_model,m,cam)

	local m = m_rotation("y",time()/16):matmul(m_translate(vec(2.5,-0.5,-0.5)))
	draw_model(cube_model,m,cam)
	
	local t1=time()
	print(string.format("tline3d DEMO\nfps: %.i\ncpu: %.3f",flr(1/(t1-_t)),100*stat(1)),2,2,8)
	_t = t1
end

-->8 {}
function polytex(p,np,texture,color)
	local miny,maxy,mini=32000,-32000
	-- find extent
	for i=1,np do
		local pi=p[i]
		local y=pi.y
		if y<miny then
			mini,miny=i,y
		end
		if y>maxy then
			maxy=y
		end
	end

	--data for left & right edges:
	local lj,rj,ly,ry,lx,lu,lv,lw,ldx,ldu,ldv,ldw,rx,ru,rv,rw,rdx,rdu,rdv,rdw=mini,mini,miny,miny
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
			local p0,p1=v0,v1
			local y0,y1=p0.y,p1.y
			local dy=y1-y0
			ly=flr(y1)
			lx=p0.x
			lw=p0.w
			lu=p0.u*lw
			lv=p0.v*lw
			ldx=(p1.x-lx)/dy
			local w1=p1.w
			ldu=(p1.u * w1 - lu)/dy
			ldv=(p1.v * w1 - lv)/dy
			ldw=(w1-lw)/dy
			--sub-pixel correction
			local cy=y-y0
			lx+=cy*ldx
			lu+=cy*ldu
			lv+=cy*ldv
			lw+=cy*ldw
		end   
		while ry<y do
			local v0=p[rj]
			rj=rj-1
			if rj<1 then rj=np end
			local v1=p[rj]
			local p0,p1=v0,v1
			local y0,y1=p0.y,p1.y
			local dy=y1-y0
			ry=flr(y1)
			rx=p0.x
			rw=p0.w
			ru=p0.u*rw 
			rv=p0.v*rw 
			rdx=(p1.x-rx)/dy
			local w1=p1.w
			rdu=(p1.u*w1 - ru)/dy
			rdv=(p1.v*w1 - rv)/dy
			rdw=(w1-rw)/dy
			--sub-pixel correction
			local cy=y-y0
			rx+=cy*rdx
			ru+=cy*rdu
			rv+=cy*rdv
			rw+=cy*rdw
		end
		 
	  tline3d(texture,lx,y,rx,y,lu,lv,ru,rv,lw,rw)
	
		lx+=ldx
		lu+=ldu
		lv+=ldv
		lw+=ldw
		rx+=rdx
		ru+=rdu
		rv+=rdv
		rw+=rdw
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