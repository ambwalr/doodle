WIDTH = 1280
HEIGHT = 600

body = $ 'body'

stage = new PIXI.Stage 0xEEFFFF

penAPI = () -> document.getElementById('wtPlugin').penAPI

transparent = true
antialias = true
renderer = PIXI.autoDetectRenderer WIDTH, HEIGHT, undefined, transparent, antialias

$(renderer.view).css border: '1px solid black'

now = -> new Date().getTime()

boundboxofpoints = ( ptarr ) ->
  xs=ptarr.map( (n) -> n.x )
  ys=ptarr.map( (n) -> n.y )
  left = xs.reduce (a,b) -> Math.min a,b
  top = ys.reduce (a,b) -> Math.min a,b
  right = xs.reduce (a,b) -> Math.max a,b
  bottom = ys.reduce (a,b) -> Math.max a,b
  return left: left, top: top, right: right, bottom: bottom

drawstroke = ( thestroke ) ->
  strokegraf = new PIXI.DisplayObjectContainer()
  for segment in thestroke
    grafic = new PIXI.Graphics()
    grafic.beginFill 0xFF0000, 0.25
    grafic.drawCircle segment.x, segment.y, segment.r
    strokegraf.addChild grafic
  prevseg = false
  for segment in thestroke
    if not prevseg
      prevseg = x: segment.x, y: segment.y
      continue
    grafic = new PIXI.Graphics()
    grafic.lineStyle 1, 0x000000, 1
    grafic.moveTo prevseg.x, prevseg.y
    grafic.lineTo segment.x, segment.y
    strokegraf.addChild grafic
    prevseg = x: segment.x, y: segment.y
  # 
  box=boundboxofpoints thestroke
  grafic = new PIXI.Graphics()
  grafic.lineStyle 1, 0x00FF00, 0.5
  grafic.drawRect box.left, box.top, box.right-box.left, box.bottom-box.top
  strokegraf.addChild grafic
  return strokegraf

newstroke = []
tmpdraw = new PIXI.DisplayObjectContainer()

doodling=false
prev = false
$(renderer.view).mousedown (e) ->
  mpos = mouseadjust e, renderer.view
  prev = x: mpos.x, y: mpos.y
  doodling = true
  newstroke = []
  newthing mpos.x, mpos.y
  stage.addChild tmpdraw
mup = (e) ->
  prev= false
  doodling = false
  stage.addChild drawstroke newstroke
  requestAnimFrame renderframe
  cacherender()


sq = (n) -> Math.pow n, 2
vdist = ( a, b ) ->
  dx=Math.abs b.x-a.x
  dy=Math.abs b.y-a.y
  return Math.sqrt sq(dx)+sq(dy)

interpolatestroke = ( thestroke ) ->
  freshstroke = []
  prevseg = false
  for segment in thestroke
    if not prevseg
      prevseg = segment
      freshstroke.push segment
      continue
    dist = vdist segment, prevseg
    #Math.sqrt( Math.pow(x-prev.x,2), Math.pow(y-prev.y,2) )
    n= Math.round dist/10
    n= Math.min n, 100
    xs=linearInterpolation prevseg.x, segment.x, n
    ys=linearInterpolation prevseg.y, segment.y, n
    rs=linearInterpolation prevseg.r, segment.r, n
    [0...n].forEach (i) ->
      freshstroke.push x: xs[i], y: ys[i], r: rs[i]
    if n > 1
      prevseg = segment
  return freshstroke

$(renderer.view).mouseup mup
$(window).mouseup mup

mouseadjust = (e, domelem) ->
  offs = $(domelem).offset()
  return x: e.pageX-offs.left, y: e.pageY-offs.top

$(renderer.view).mousemove (e) ->
  if doodling
    mpos = mouseadjust e, renderer.view
    if prev
      newthing mpos.x, mpos.y
    requestAnimFrame renderframe
    prev = x: mpos.x, y: mpos.y

body.append renderer.view

linearInterpolation = (from, to, steps) ->
  steps--
  offs = (to-from)/steps
  [0..steps].map (n) -> from+n*offs

subnewthing = (x,y,r) ->
  grafic = new PIXI.Graphics()
  grafic.beginFill 0xFF0000, 0.25
  grafic.drawCircle x, y, r
  stage.addChild grafic

dabcount = 0
newthing = (x,y) ->
  pressure=penAPI()?.pressure or 1
  r = 2+ pressure * 10
  timedelta = now()
  newstroke.push x: x, y: y, r: r, t: timedelta
  dabcount++
  prev = x: x, y: y


cacherender = ->
  console.log renderer.view
  bgtex = new PIXI.RenderTexture WIDTH, HEIGHT
  bgtex.render stage
  newstage = new PIXI.Stage 0xEEFFFF
  bg = new PIXI.Sprite bgtex
  bg.position.x = 0
  bg.position.y = 0
  newstage.addChild bg
  stage= newstage

renderframe = ->
  renderer.render stage
  #if dabcount > 100
  #  dabcount = 0
  #  cacherender()


