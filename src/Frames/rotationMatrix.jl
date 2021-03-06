# License for this file: MIT (expat)
# Copyright 2017-2018, DLR Institute of System Dynamics and Control
#
# This file is part of module
#   ModiaMath.Frames (ModiaMath/Frames/_module.jl)
#

@static if VERSION >= v"0.7.0-DEV.2005" @eval using LinearAlgebra end

"""
    const ModiaMath.RotationMatrix = SMatrix{3,3,Float64,9}

Describes the rotation from a frame 1 into a frame 2. An instance `R` of `RotationMatrix`
has the following interpretation:

```julia
R::RotationMatrix = [ex ey ez]   
```

where `ex`, `ey`, `ez` are unit vectors in the direction of the x-axis, y-axis, and z-axis
of frame 1, resolved in frame 2, respectively (for example ex=[1.0, 0.0, 0.0])
Therefore, if `v1` is vector `v` resolved in frame 1 and `v2` is vector `v`
resolved in frame 2, the following relationship holds: 

```julia
v2 = R*v1   
v1 = R'*v2
```
"""
const RotationMatrix = SMatrix{3,3,Float64,9}



"""
@static if VERSION >= v"0.7.0-DEV.2005"
    const ModiaMath.NullRotation = ModiaMath.RotationMatrix(Matrix(1.0I, 3, 3))
else
    const ModiaMath.NullRotation = ModiaMath.RotationMatrix(eye(3))
end

Constant RotationMatrix that defines no rotation from frame 1 to frame 2.
"""
@static if VERSION >= v"0.7.0-DEV.2005"
    const NullRotation = SMatrix{3,3,Float64,9}(Matrix(1.0I, 3, 3))
else
    const NullRotation = SMatrix{3,3,Float64,9}(eye(3))
end


"""
    ModiaMath.assertRotationMatrix(R::AbstractMatrix)

Assert that matrix R has the properties of a rotation matrix
(is 3x3 and R'*R - eye(3) = zeros(3,3))
"""
function assertRotationMatrix(R::AbstractMatrix)
   @assert(size(R,1)==3, size(R,2)==3)
   @assert(norm(R'*R - NullRotation) <= 1e-10)
end


"""
    R = ModiaMath.rot1(angle)

Return RotationMatrix R that rotates with angle `angle` along the x-axis of frame 1. 
"""
@inline function rot1(angle::Number)::RotationMatrix
   s = sin(angle)
   c = cos(angle)
   R = @SMatrix [1.0  0.0  0.0;
                 0.0   c    s ;
                 0.0  -s    c ]
end


"""
    R = ModiaMath.rot2(angle)

Return RotationMatrix R that rotates with angle `angle` in [radian] along the y-axis of frame 1. 
"""
@inline function rot2(angle::Number)::RotationMatrix
   s = sin(angle)
   c = cos(angle)
   R = @SMatrix [ c  0.0 -s ;
                 0.0 1.0 0.0;
                  s  0.0  c ]
end


"""
    R = ModiaMath.rot3(angle)

Return RotationMatrix R that rotates with angle `angle` in [radian] along the z-axis of frame 1. 
"""
@inline function rot3(angle::Number)::RotationMatrix
   s = sin(angle)
   c = cos(angle)
   R = @SMatrix [ c   s  0.0;
                 -s   c  0.0;
                 0.0 0.0 1.0]
end


"""
    R = ModiaMath.rot123(angle1, angle2, angle3)

Return RotationMatrix R by rotating with angle1 along the x-axis of frame 1,
then with angle2 along the y-axis of this frame and then with angle3 along
the z-axis of this frame.
"""
rot123(angle1::Number, angle2::Number, angle3::Number)::RotationMatrix = rot3(angle3)*rot2(angle2)*rot1(angle1)


"""
    R = ModiaMath.rot_e(e, angle)

Return RotationMatrix that rotates around angle `angle` along unit axis `e`.
This function assumes that `norm(e) == 1`.
"""
rot_e(e::Vector3D,angle::Number)::RotationMatrix = e*e' + (NullRotation - e*e')*cos(angle) - skew(e)*sin(angle)
rot_e(e::AbstractVector, angle::Number)::RotationMatrix    = rot_e( Vector3D(e), convert(Float64,angle) )


"""
    R = ModiaMath.rot_nxy(nx, ny)

It is assumed that the two input vectors `nx` and `ny` are resolved in frame 1 and
are directed along the x and y axis of frame 2.
The function returns the RotationMatrix R to rotate from frame 1 to frame 2. 

The function is robust in the sense that it returns always a RotationMatrix R,
even if `ny` is not orthogonal to `nx` or if one or both vectors have zero length.
This is performed in the following way: 
If `nx` and `ny` are not orthogonal to each other, first a unit vector `ey` is 
determined that is orthogonal to `nx` and is lying in the plane spanned by 
`nx` and `ny`. If `nx` and `ny` are parallel or nearly parallel to each other 
or `ny` is a vector with zero or nearly zero length, a vector `ey` is selected
arbitrarily such that `ex` and `ey` are orthogonal to each other. 
If both `nx` and `ny` are vectors with zero or nearly zero length, an
arbitrary rotation matrix is returned.

# Example

```julia
using Unitful
import ModiaMath

R1 = ModiaMath.rot1(90u"°")
R2 = ModiaMath.rot_nxy([1  , 0, 0], [0  , 0, 1  ])
R3 = ModiaMath.rot_nxy([0.9, 0, 0], [1.1, 0, 1.1])
isapprox(R1,R2)   # returns true
isapprox(R1,R3)   # returns true
```
"""
function rot_nxy(nx::Vector3D, ny::Vector3D)::RotationMatrix
  abs_nx  = norm(nx)
  e1      = abs_nx < 1e-10 ?  Vector3D(1.0, 0.0, 0.0) : nx/abs_nx
  n3_aux  = cross(e1, ny)
  e2_aux  = dot(n3_aux,n3_aux) > 1e-6 ? ny : ( abs(e1[1]) > 1e-6 ? Vector3D(0.0,1.0,0.0)
                                                                 : Vector3D(1.0,0.0,0.0))
  n3_aux2 = cross(e1, e2_aux)
  e3      = normalize(n3_aux2)
  R       = vcat(e1', cross(e3,e1)', e3')
end
rot_nxy(nx::AbstractVector, ny::AbstractVector) = rot_nxy(Vector3D(nx), Vector3D(ny))



"""
    v1 = ModiaMath.resolve1([R|q], v2)

Transform vector v2 (v resolved in frame 2) to vector v1 (v resolved in frame 1)
given either [`ModiaMath.RotationMatrix`](@ref) ` R` or 
[`ModiaMath.Quaternion`](@ref) ` q` (to rotate a frame 1 into a frame 2).
"""
resolve1(R::RotationMatrix, v2::Vector3D)::Vector3D = R'*v2
resolve1(R::RotationMatrix, v2::AbstractVector)::Vector3D     = R'*Vector3D(v2)



"""
    v2 = ModiaMath.resolve2([R|q], v1)

Transform vector v1 (v resolved in frame 1) to vector v2 (v resolved in frame 2)
given either [`ModiaMath.RotationMatrix`](@ref) ` R` or 
[`ModiaMath.Quaternion`](@ref) ` q` (to rotate a frame 1 into a frame 2).
"""
resolve2(R::RotationMatrix, v1::Vector3D)::Vector3D = R*v1
resolve2(R::RotationMatrix, v1::AbstractVector)::Vector3D     = R*Vector3D(v1)


"""
     R2 = ModiaMath.absoluteRotation(R1, R_rel) 
     q2 = ModiaMath.absoluteRotation(q1, q_rel)   

Return [`ModiaMath.RotationMatrix`](@ref)` R2` or [`ModiaMath.Quaternion`](@ref)` q2`
defining the rotation from frame 0 to frame 2 from RotationMatrix `R1` or Quaternion `q1`that define the
rotation from frame 0 to frame 1 and the relative RotationMatrix `R_rel` or the
relative Quaternion `q_rel` that define the rotation from frame 1 to frame 2.
"""
absoluteRotation(R1::RotationMatrix, R_rel::RotationMatrix)::RotationMatrix = R_rel*R1 



"""
     R_rel = ModiaMath.relativeRotation(R1, R2) 
     q_rel = ModiaMath.relativeRotation(q1, q2)   

Return relative [`ModiaMath.RotationMatrix`](@ref)` R_rel` or relative
[`ModiaMath.Quaternion`](@ref)` q_rel` defining the rotation from frame 1 to frame 2 
from absolute RotationMatrix `R1` or absolute Quaternion `q1`that define the
rotation from frame 0 to frame 1 and the absolute RotationMatrix `R2` or the
absolute Quaternion `q2` that define the rotation from frame 0 to frame 2.
"""
relativeRotation(R1::RotationMatrix, R2::RotationMatrix)::RotationMatrix = R2*R1'


"""
     R_inv = ModiaMath.inverseRotation(R) 
     q_inv = ModiaMath.inverseRotation(q)   

Return inverse [`ModiaMath.RotationMatrix`](@ref)` R_inv` or inverse
[`ModiaMath.Quaternion`](@ref)` q_inv` defining the rotation from frame 1 to frame 0 
from RotationMatrix `R` or Quaternion `q`that define the
rotation from frame 0 to frame 1.
"""
inverseRotation(R::RotationMatrix)::RotationMatrix = R'


""" 
    angle = planarRotationAngle(e, v1, v2; angle_guess = 0.0)

Return `angle` of a planar rotation, given the normalized axis of
rotation to rotate frame 1 around `e` into frame 2 (norm(e) == 1 required),
and the representations of a vector in frame 1 (`v1`) and frame 2 (`v2`).
Hereby, it is required that `v1` is not parallel to `e`.
The returned angle is in the range `-pi <= angle - angle_guess <= pi`
(from the infinite many solutions, the one is returned that is closest to `angle_guess`).

# Example

```julia
import ModiaMath
using Unitful

angle1 = 45u"°"
e      = normalize([1.0, 1.0, 1.0])
R      = ModiaMath.rot_e(e, angle1)

v1 = [1.0, 2.0, 3.0]
v2 = ModiaMath.resolve2(R, v1)

angle2 = planarRotationAngle(e, v1, v2)
isapprox(angle1, angle2)
```
"""
@inline function planarRotationAngle(e::AbstractVector, v1::AbstractVector, v2::AbstractVector; angle_guess::Number=0.0)::Number
   @static if VERSION >= v"0.7.0-DEV.2005"
      angle1 = atan( dot(-cross(e,v1), v2), dot(v1,v2) - dot(e,v1)*dot(e,v2) )
   else
      angle1 = atan2( dot(-cross(e,v1), v2), dot(v1,v2) - dot(e,v1)*dot(e,v2) )
   end

   pi2    = 2*pi
   return angle1 + pi2*round(Int, (pi+angle_guess-angle1)/(pi2), RoundDown)
end


#=
Derivation of algorithm for planarRotaionAngle:

Vector v is resolved in frame 1 and frame 2 according to:
   (1)  v2 = (e*e' + (NullRotation - e*e')*cos(angle) - skew(e)*sin(angle))*v1
           = e*(e'*v1) + (v1 - e*(e'*v1))*cos(angle) - cross(e,v1)*sin(angle)

Equation (1) is multiplied with "v1'" resulting in (note: e'*e = 1)

   (2)  v1'*v2 = (v1'*e)*(e'*v2) + (v1'*v1 - (v1'*e)*(e'*v1))*cos(angle)

and therefore

   (3)  cos(angle) = ( v1'*v2 - (v1'*e)*(e'*v2)) / (v1'*v1 - (v1'*e)*(e'*v1))

Similarly, equation (1) is multiplied with cross(e,v1), that is a
a vector that is orthogonal to e and to v1:

   (4)  cross(e,v1)'*v2 = -cross(e,v1)'*cross(e,v1)*sin(angle)

and therefore:

   (5) sin(angle) = -cross(e,v1)'*v2/(cross(e,v1)'*cross(e,v1))

We have e'*e=1. Therefore

   (6) v1'*v1 - (e*v1)'*(e*v1) = |v1|^2 - (|v1|*cos(e,v1))^2

and

   (7) cross(e,v1)'*cross(e,v1) = (|v1|*sin(e,v1))^2
                                 = |v1|^2*(1 - cos(e,v1)^2)
                                 = |v1|^2 - (|v1|*cos(e,v1))^2

The denominators of (3) and (5) are identical, according to (6) and (7).
Furthermore, the denominators are always positive according to (7).
Therefore, in the equation "angle = atan2(sin(angle), cos(angle))" the
denominators of sin(angle) and cos(angle) can be removed, resulting in:

   (8) angle1 = atan2(-cross(e,v1)'*v2, v1'*v2 - (e'*v1)*(e'*v2));

This angle is in the range -pi <= angle1 <= pi. The returned angle should be
as close to angle_guess. If angle_guess = 0, angle1 is just returned. Otherwise:

       -pi < angle - angle_guess <= pi
       -pi < angle1 + 2*pi*N - angle_guess <= pi
       (-pi+angle_guess-angle1)/(2*pi) < N <= (pi+angle_guess-angle1)/(2*pi)
       -> N := round(Int, (pi+angle_guess-angle1)/(2*pi), RoundDown )
    
resulting in 

    (9) angle = angle1 + 2*pi*round(Int, (pi+angle_guess-angle1)/(2*pi))
=#


""" 
    e = eAxis(axis::Int)

Return unit vector `e` in direction of axis `axis` (`axis` = 1,2,3 or -1,-2-,3).


# Example

```julia
import ModiaMath

e1 = ModiMath.eAxis(1)    # e1 = Vector3D(1.0,  0.0, 0.0)
e2 = ModiMath.eAxis(-2)   # d2 = Vector3D(0.0, -1.0, 0.0)
```
"""
eAxis(axis::Int) = axis ==  1 ? Vector3D(  1.0,  0.0,  0.0) :
                   axis ==  2 ? Vector3D(  0.0,  1.0,  0.0) :
                   axis ==  3 ? Vector3D(  0.0,  0.0,  1.0) : 
                   axis == -1 ? Vector3D( -1.0,  0.0,  0.0) :
                   axis == -2 ? Vector3D(  0.0, -1.0,  0.0) :
                   axis == -3 ? Vector3D(  0.0,  0.0, -1.0) :
                   error("ModiaMath.eAxis(axis): axis = ", axis, " but must be 1, 2, 3, -1, -2, or -3.")
