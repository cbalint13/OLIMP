#!/usr/bin/python3

"""
/*
 *
 *  OLIMP VEC (Vector Multiply Accumulate) Diagram Generator
 *
 *  Copyright (C) 2021  Cristian Balint <cristian dot balint at gmail dot com>
 *
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */
"""

import sys
import schemdraw
from schemdraw import dsp, logic
from schemdraw import elements as elm

# vector register box
def gen_input_vector(vtype='data', name=None, desc=None, bits=8, after=None):

  pfx = 'X'
  xshift = 0
  yshift = 0
  pins = []

  if   vtype == 'data': pfx = 'D'
  elif vtype == 'coef': pfx = 'W'

  if after:
    yshift = after.xy.y
    xshift = after.bbox.xmax + after.xy.x + d.unit/16

  for b in range(bits):
    pins.append(elm.IcPin(name='%s%i' % (pfx,b), side='b', slot='%i/%i' % (b+1,bits)))

  dD = elm.Ic(pins = pins,
              label = name + " (" + desc + ")",
              at = [xshift, yshift],
              pinspacing = d.unit/4,
              edgepadW = 0, lsize = 12)

  return dD

# accumulator register box
def gen_output_vector(bits=8, xtapto=None, ybellow=None, name=None, desc=None):

  pins = []

  for b in range(bits):
    pins.append(elm.IcPin(anchorname='I%i' % b, side='L'))
  pins.append(elm.IcPin(anchorname='SUM', side='R', invert=True))

  dS = elm.Multiplexer(pins = pins,
              label = 'Σ',
              lblsize = 32,
              edgepadH = -d.unit/8,
              pinspacing = d.unit/4,
              anchor = "I0", slant = 3,
              xy = [xtapto.xy.x, ybellow.xy.y - d.unit/2])

  return dS


####
#### MAIN
####

d = schemdraw.Drawing(fontsize=12)


##
## OLIMP VEC params
##

num_U8_data = 1 * 8
num_I8_coef = 2 * 8
n_S32_lanes = 2



# element arrays
D, M, S = [], [], []

# data vector register
for i in range(num_U8_data//8):
  a = D[-1] if D else None
  dD = gen_input_vector(vtype='data', name="data", desc="8 x i8", bits=8, after=a)
  D.append(d.add(dD))

# coeff vector register
for i in range(num_I8_coef//8):
  dD = gen_input_vector(vtype='coef', name="coef", desc="8 x  u8", bits=8, after=D[-1])
  D.append(d.add(dD))

length = 0

# multiplier interconnect
for x in range(num_U8_data//8, len(D)):
  m = []

  for p in D[1].anchors:
    if (p == 'center' or 'inB' in p): continue
    b = int(p[1:])
    length = length + d.unit/4
    l = d.add(dsp.Line('down', xy = getattr(D[x], p), l = length))
    m.append(d.add(dsp.Mixer(fill = 'navajowhite')))
    d.add(elm.RightLines(xy = m[-1].S, to = getattr(D[0], 'D%i' % b), n = 1))
    if M:
      d.add(elm.Dot(xy = [getattr(D[0],'D%i' % b).x, M[0][b].S.y]))
  M.append(m)

# output accumulators
for i in range(n_S32_lanes):
  s = d.add(gen_output_vector(bits=8, xtapto=M[i][0], ybellow=M[-1][-1], name="acc%i" % i, desc="16bit"))
  for p in D[i+num_U8_data//8].anchors:
    if (p == 'center' or 'inB' in p): continue
    b = int(p[1:])
    l = d.add(elm.RightLines(xy=M[i][b].E, to=getattr(s,'I%i' % b), n=1))
  S.append(s)

d.draw()
d.save('imgs/OLIMP-VEC-%iU8-%iI8-%iS32.png' % (num_U8_data, num_I8_coef, n_S32_lanes))
