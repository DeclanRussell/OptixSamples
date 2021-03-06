
/*
 * Copyright (c) 2008 - 2009 NVIDIA Corporation.  All rights reserved.
 *
 * NVIDIA Corporation and its licensors retain all intellectual property and proprietary
 * rights in and to this software, related documentation and any modifications thereto.
 * Any use, reproduction, disclosure or distribution of this software and related
 * documentation without an express license agreement from NVIDIA Corporation is strictly
 * prohibited.
 *
 * TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THIS SOFTWARE IS PROVIDED *AS IS*
 * AND NVIDIA AND ITS SUPPLIERS DISCLAIM ALL WARRANTIES, EITHER EXPRESS OR IMPLIED,
 * INCLUDING, BUT NOT LIMITED TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE.  IN NO EVENT SHALL NVIDIA OR ITS SUPPLIERS BE LIABLE FOR ANY
 * SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES WHATSOEVER (INCLUDING, WITHOUT
 * LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS, BUSINESS INTERRUPTION, LOSS OF
 * BUSINESS INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE USE OF OR
 * INABILITY TO USE THIS SOFTWARE, EVEN IF NVIDIA HAS BEEN ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGES
 */

#include <optix_world.h>

using namespace optix;

rtDeclareVariable(float4, plane, , );
rtDeclareVariable(float3, v1, , );
rtDeclareVariable(float3, v2, , );
rtDeclareVariable(float3, anchor, , );
rtDeclareVariable(int, lgt_instance, , ) = {0};

rtDeclareVariable(float4, sphere, , );

rtDeclareVariable(float3, texcoord, attribute texcoord, ); 
rtDeclareVariable(float3, geometric_normal, attribute geometric_normal, ); 
rtDeclareVariable(float3, shading_normal, attribute shading_normal, ); 
rtDeclareVariable(int, lgt_idx, attribute lgt_idx, ); 
rtDeclareVariable(optix::Ray, ray, rtCurrentRay, );

RT_PROGRAM void intersect(int primIdx)
{
  float3 n = make_float3( plane );
  float dt = dot(ray.direction, n );
  float t = (plane.w - dot(n, ray.origin))/dt;
  if( t > ray.tmin && t < ray.tmax ) {
    float3 p = ray.origin + ray.direction * t;
    float3 vi = p - anchor;
    float a1 = dot(v1, vi);
    if(a1 >= 0 && a1 <= 1){
      float a2 = dot(v2, vi);
      if(a2 >= 0 && a2 <= 1){
        if( rtPotentialIntersection( t ) ) {
          shading_normal = geometric_normal = n;
          texcoord = make_float3(a1,a2,0);
          lgt_idx = lgt_instance;
          rtReportIntersection( 0 );
        }
      }
    }
  }
}

RT_PROGRAM void intersect_sphere( int primIdx )
{
  float3 center = make_float3( sphere.x, sphere.y, sphere.z );
  float radius = sphere.w;
  float3 O = ray.origin - center;
  float b = dot( O, ray.direction );
  float c = dot( O, O ) - radius*radius;
  float disc = b*b - c;
  if( disc > 0.0f ) {
    float sdisc = sqrtf( disc );
    float root1 = (-b - sdisc);
    bool check_second = true;
    if( rtPotentialIntersection( root1 ) ) {
      shading_normal = geometric_normal = (O + root1*ray.direction) / radius;
      if( rtReportIntersection( 0 ) ) check_second = false;
    }
    if( check_second ) {
      float root2 = (-b + sdisc);
      if( rtPotentialIntersection( root2 ) ) {
        shading_normal = geometric_normal = (O + root2*ray.direction) / radius;
        rtReportIntersection( 0 );
      }
    }
  }
}

RT_PROGRAM void bounds_sphere (int, float result[6])
{
  float3 center = make_float3(sphere.x,sphere.y,sphere.z);
  float3 radiusV3 = make_float3(sphere.w,sphere.w,sphere.w);
  float3 mmin = center - radiusV3;
  float3 mmax = center + radiusV3;

  result[0] = mmin.x;
  result[1] = mmin.y;
  result[2] = mmin.z;
  result[3] = mmax.x;
  result[4] = mmax.y;
  result[5] = mmax.z;
}

RT_PROGRAM void bounds (int, float result[6])
{
  // v1 and v2 are scaled by 1./length^2.  Rescale back to normal for the bounds computation.
  const float3 tv1  = v1 / dot( v1, v1 );
  const float3 tv2  = v2 / dot( v2, v2 );
  const float3 p00  = anchor;
  const float3 p01  = anchor + tv1;
  const float3 p10  = anchor + tv2;
  const float3 p11  = anchor + tv1 + tv2;
  const float  area = length(cross(tv1, tv2));
  
  optix::Aabb* aabb = (optix::Aabb*)result;
  
  if(area > 0.0f && !isinf(area)) {
    aabb->m_min = fminf( fminf( p00, p01 ), fminf( p10, p11 ) );
    aabb->m_max = fmaxf( fmaxf( p00, p01 ), fmaxf( p10, p11 ) );
  } else {
    aabb->invalidate();
  }
}

