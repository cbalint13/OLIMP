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
import math
import schemdraw
from schemdraw import dsp, logic
from schemdraw import elements as elm
from schemdraw import segments as sgm

# global draw sheet
d = schemdraw.Drawing(fontsize=12)

# accumulator register box
def gen_output_vector(ports=8, xtapto=None, ybellow=None, name=None, desc=None):

  pins = []

  for b in reversed(range(ports)):
    pins.append(elm.IcPin(anchorname='I%i' % b, side='R'))
  pins.append(elm.IcPin(anchorname='SUM', side='L', invert=True))
  dS = elm.Multiplexer(pins=pins, label='Σ', lblsize=32, edgepadH=-d.unit/8,
                       pinspacing=d.unit/4, anchor="I0", slant=3,
                       xy=[xtapto.xy.x, ybellow.xy.y - d.unit/2], demux=True)

  dS.label(label=desc, ofst=-d.unit/3, loc='left')

  return dS

def gen_vector_register(R, nums, pfx, name, desc, ports, after=None):

  # vector register box
  def gen_input_vector(pfx='X', name=None, desc=None, ports=8, after=None):

    xshift = 0
    yshift = 0
    pins = []

    if after:
      yshift = after.xy.y
      xshift = after.bbox.xmax + after.xy.x + d.unit/16

    for b in range(ports):
      pins.append(elm.IcPin(name='%s%02i' % (pfx, b), side='b',
                            slot='%i/%i' % (b+1, ports), lblsize=10))

    dD = elm.Ic(pins=pins, label=name + "\n(" + desc + ")",
                at=[xshift, yshift], pinspacing=d.unit/4,
                edgepadW=0, lsize=12)

    # pin label font color
    for i, s in enumerate(dD.segments):
      if type(s) is sgm.SegmentText:
        dD.segments[i].color = 'blue'

    return dD

  ##
  ## vector registers
  ##
  for i in range(nums):
    a = R[-1] if R else after
    dR = gen_input_vector(pfx, name, desc, ports, a)
    R.append(d.add(dR))

  return R


##
## OLIMP VEC params
##

num_data, vec_data_w, vec_data_t, vec_data_b = [1, 8, 'U', 8]
num_coef, vec_coef_w, vec_coef_t, vec_coef_b = [2, 8, 'I', 8]

# accumulator register width & type
summ_bits = (vec_data_b + vec_coef_b) + vec_coef_w
lane_bits = math.pow(2, math.ceil(math.log(summ_bits)/math.log(2)))
vec_lane_t = 'S' if 'I' in (vec_data_t, vec_coef_t) else 'U'
# infer lanes
num_lane, vec_lane_w, vec_lane_t, vec_lane_b = [num_coef, 1, vec_lane_t, summ_bits]

# assure data types
assert(vec_data_t in ('U', 'I'))
assert(vec_coef_t in ('U', 'I'))
# only one input data register
assert(num_data == 1)
# coef is multiple of data register
assert(vec_coef_w % vec_data_w == 0)

####
#### MAIN
####

# TODOs
# make it a graph class
# add cli arguments

def main():

  # draw flow
  dataFlow = False
  # display graph
  dataDisplay = False

  # element arrays
  D, C, M, S = [], [], [], []
  # bar-bus symbol
  bar = sgm.Segment([(-d.unit/32, d.unit/32),
                     ( d.unit/32,-d.unit/32)])
  bar.color='red'

  # vector registers
  D = gen_vector_register(D, num_data, "D", "data", "%i x %s%i"
                       % (vec_data_w, vec_data_t, vec_data_b), vec_data_w, None )
  C = gen_vector_register(C, num_coef, "W", "coef", "%i x %s%i"
                       % (vec_coef_w, vec_coef_t, vec_coef_b), vec_coef_w, D[-1])

  # data bus anotations
  for x in range(num_data):
    for p in D[x].anchors:
      if (p == 'center' or 'inB' in p): continue
      # data bus annotations
      l = d.add(elm.Line('down', xy=getattr(D[x], p), l=0).label(label='%i' % vec_data_b))
      l.segments.append(bar)

  length = 0
  # multiplier interconnect
  for x in range(num_coef):
    m = []
    for p in C[x].anchors:
      if (p == 'center' or 'inB' in p): continue
      b = int(p[1:])
      length = length + d.unit/4
      # coef bus annotations
      l = d.add(elm.Line('down', xy=getattr(C[x], p), l=0).label(label='%i' % vec_coef_b))
      l.segments.append(bar)
      # line to multiplier
      w = d.add(elm.Line('down', xy=getattr(C[x], p), l=length))
      # palce multiplier
      m.append(d.add(dsp.Mixer(fill='navajowhite')))
      if (dataFlow):
        # data flow arrows
        d.add(dsp.Arrow(color='slateblue', headwidth=d.unit/15).down(d.unit/8).at(m[-1].W))
        d.add(dsp.Arrow(color='slateblue', headwidth=d.unit/15).right(d.unit/8).at(m[-1].S))
        d.add(dsp.Arrow(color='salmon', headwidth=d.unit/10).down(d.unit/1024).at(m[-1].E))
      # C walks times D
      a = b - vec_data_w*(b//vec_data_w)
      d.add(elm.RightLines(xy=m[-1].S, to=getattr(D[0], 'D%02i' % a), n=1))
      # omit last dots
      if not ( (x == num_coef-1) and
               (b > (vec_coef_w - vec_data_w-1)) ):
        d.add(elm.Dot(xy = [getattr(D[0],'D%02i' % a).x, m[-1].S.y]))
    # shift below coef reg
    length = length + d.unit/8

    M.append(m)

  # output accumulators
  for x in range(num_lane):
    s = d.add(gen_output_vector(ports=vec_coef_w, xtapto=M[x][0], ybellow=M[-1][-1], name="acc%i" % x, desc="%i bit" % summ_bits))
    # summ bus annotation
    l = d.add(elm.Line('down', xy=getattr(s, 'SUM'), l=d.unit/8).label(label='%i' % lane_bits))
    l.segments.append(bar)
    # line to accumulator
    for p in C[x].anchors:
      if (p == 'center' or 'inB' in p): continue
      b = int(p[1:])
      l = d.add(elm.Line(xy=getattr(s, 'I%i' % b), to=M[x][b].E, n=1))
      # mult bus annotation
      l = d.add(elm.Line('up', xy=getattr(s, 'I%i' % b), l=0).label(label='%i' % (vec_data_b+vec_coef_b) ))
      l.segments.append(bar)
    S.append(s)

  # draw
  if dataDisplay: d.draw()
  for ext in ['svg','png']:
    outimg = ("imgs/OLIMP-VEC-%ix%i%s%i-%ix%i%s%i-%i%s%i.%s"
           % (num_data, vec_data_w, vec_data_t, vec_data_b,
              num_coef, vec_coef_w, vec_coef_t, vec_coef_b,
              num_lane, vec_lane_t, lane_bits, ext))
    d.save(outimg)
    print("Wrote: [%s]" % outimg)

if __name__ == '__main__':
  main()
