# doodle
# a creatively named javascript app for multi user online doodling
# by ambwalr at gmail

NETWORKED = true

CANVASWIDTH = 1200
CANVASHEIGHT = 600

ABSMINRADIUS = 1
ABSMAXRADIUS = 100

paused = false
currentbrush = 'default'

canvasobj = false

contain = $ "<div>"
contain.resizable handles: 's' # grid: 50
canvascontainer = $ "<div id=canvascontainer>"
contain.css resize: 'vertical', 'border-bottom': '2px solid gray', 'padding-bottom': 1
contain.height 500
#overflow: 'hidden'
canvascontainer.css overflow: 'auto', 'min-height': 200
canvascontainer.css height: '100%'

body = $ "body"
displaycanvaselem = $ "<canvas id=doodlecanvas>"
#id=doodlecanvas width=1000 height=600>"
body.append contain
contain.append canvascontainer

displaycanvaselem.attr height: CANVASHEIGHT
displaycanvaselem.attr width: CANVASWIDTH

displaycanvasctx = displaycanvaselem[0].getContext "2d"
displaycanvasctx.fillStyle ='white'
displaycanvasctx.fillRect 0, 0, CANVASWIDTH, CANVASHEIGHT
canvascontainer.append displaycanvaselem

tag = ( type="div", body="" ) -> "<#{type}>#{body}</#{type}>"
dataurl = (data) -> "data:image/svg+xml;base64,"+btoa data

wacom = -> document.getElementById 'wtPlugin'
tabletaffectsradius = false
tabletaffectsopacity = false

isdrawing = false
holdingright = false

nocache = false
cache = []

V2d = (x,y) -> x: x, y: y
mpos = V2d 0,0

rgba = ( r, g, b, a ) -> r: r, g: g, b: b, a: a
adjustalpha = ( col, alpha ) ->
  rgba col.r, col.g, col.b, alpha

recentcolors = [ rgba(0,0,0,1), rgba(255,255,255,1), rgba(255,0,0,1), rgba(255,130,110,1) ]

socket = undefined

stage = new PIXI.Stage 0xFFFFFF, true
#stage.setInteractive true

transparent = true
antialias = true

renderer = new PIXI.autoDetectRenderer CANVASWIDTH, CANVASHEIGHT, null, transparent, antialias

canvascontainer.append renderer.view

displaycanvaselem.hide()
displaycanvaselem = $(renderer.view)

canvasobj = renderer.view.getContext '2d'

displaycanvaselem.mousedown (e) ->
  if e.button == 0
    mpos = correctpos e
    isdrawing = true
  if e.button == 2
    holdingright = true
    rdown e
  draw mpos

cancel = (e) ->
  if e.button == 0
    isdrawing = false
  if e.button == 2
    holdingright = false

displaycanvaselem.mouseup cancel
body.mouseup cancel

correctpos = (e) ->
  screenpageoffset = V2d e.screenX-e.pageX, e.screenY-e.pageY
  x=e.pageX
  y=e.pageY
  #penapi = wacom().penAPI
  #console.log penapi
  ##don't really need subpixel precision currently
  #if penapi and penapi.isInProximity
  #  x = penapi.sysX
  #  y = penapi.sysY
  #  x -= screenpageoffset.x
  #  y -= screenpageoffset.y
  offset = displaycanvaselem.offset()
  x-=offset.left
  y-=offset.top
  if flipped then x = displaycanvaselem.width()-x
  return V2d x,y

color = rgba 0,0,0,1

displaycanvaselem.bind 'contextmenu', (e) -> false

pickcolor = ( ctx, pos ) ->
  #TODO FIXME
  return rgba 0, 0, 0, 1

rdown = (e) ->
  mpos = correctpos e
  coleur = pickcolor canvasobj, mpos
  coleur = adjustalpha coleur, color.a
  updatecolor coleur

prev = undefined

minradius = 1
maxradius = 10
lastdab = undefined

vnmul = ( v,n ) ->
  return V2d v.x*n, v.y*n
vadd = ( a,b ) ->
  return V2d a.x+b.x, a.y+b.y
vsub = ( a,b ) ->
  return V2d a.x-b.x, a.y-b.y

vmag = ( v ) ->
  Math.sqrt( Math.pow(v.x,2)+Math.pow(v.y,2) )

vdist = ( a, b ) -> vmag vsub a,b


cancelright = (e) ->
  if e.button == 2
    holdingright = false
displaycanvaselem.mouseup cancelright

updaterecentcolors = () ->
  if color in recentcolors
    i=recentcolors.indexOf color
    recentcolors.splice i, 1
    recentcolors.unshift color
    updateswatches()
  if color not in recentcolors
    recentcolors.unshift color
    updateswatches()
  if recentcolors.length > 8
    recentcolors.pop()
    updateswatches()

switchcolor = () ->
  #c = recentcolors.shift()
  #recentcolors.push c
  updatecolor recentcolors[1]
  updaterecentcolors()

bindings = {}
keytapbind = ( key, func ) ->
  k=key.toUpperCase().charCodeAt 0
  bindings[k]=func
  body.append "<a accesskey=#{key}></a>"

keytapbind 'x', switchcolor

$(document).bind 'keydown', (e) ->
  if not e.altKey then return
  key = e.which
  if bindings.hasOwnProperty key
    bindings[key]()

tabletmodifier = ( st ) ->
  penapi = wacom().penAPI
  pressure = penapi.pressure
  adjustedradiuspressure = Math.pow pressure, 2
  adjustedopacitypressure = Math.pow pressure, 3
  c = st.color
  if penapi.isEraser
    c = rgba 255, 255, 255, 1
    pressure = 1
  w=st.width
  f=st.from
  t=st.to
  #c=st.color
  radiusrange = maxradius-minradius
  if tabletaffectsradius then w = minradius+radiusrange*adjustedradiuspressure
  if tabletaffectsopacity
    newalpha = c.a * adjustedopacitypressure
    c = adjustalpha c, newalpha
  newst= $.extend {}, st, from: f, to: t, width: w, color: c, brush: st.brush
  if penapi.isEraser
    newst.brush = 'eraser'
  return newst

draw = (mpos) ->
  if ( not isdrawing ) or displaycanvaselem.hasClass "disabled"
    prev = undefined
    lastdab = undefined
    return
  penapi = wacom().penAPI
  if not prev then prev = mpos
  if prev
    st = from: prev, to: mpos, width: maxradius, color: color, brush: currentbrush
    if penapi #and penapi.isInProximity
      st=tabletmodifier st
    makestroke st

  prev = V2d mpos.x, mpos.y

displaycanvaselem.mousedown (e) ->
  updaterecentcolors()

displaycanvaselem.mousemove (e) ->
  if holdingright
    rdown e
body.mousemove (e) ->
  mpos = correctpos e
  draw mpos

csscolor = ( col ) ->
  "rgba(#{col.r},#{col.g},#{col.b},#{col.a})"

clumps = ( arr, n ) ->
  (arr[i...i+n] for x,i in arr[0..arr.length-n])

degstorads = (deg) -> (deg*Math.PI)/180

vmag = (v) -> Math.sqrt Math.pow(v.x,2)+Math.pow(v.y,2)
vndiv = (v,n) -> V2d v.x/n, v.y/n
vnorm = (v) -> vndiv v, vmag(v)

rfloat = () ->  -1+Math.random()*2
randdir = () -> vnorm V2d rfloat(), rfloat()
randvector = () -> vnmul randdir(), Math.random()

brushpresets = {}

brushpresets.default = {
  adjust: (st, pos, angle ) ->
    jitter = 0
    pos = vadd pos, vnmul randvector(), jitter*st.width
    ellipseratio = 1
    return pos: pos, radius: st.width/2, angle: angle, ellipseratio: ellipseratio, color: st.color
}
brushpresets.eraser = {
  adjust: (st, pos, angle ) ->
    color = rgba 0,0,0,1
    ellipseratio = 1
    return pos: pos, radius: st.width/2, angle: angle, ellipseratio: ellipseratio, color: color, erase: true
}
brushpresets.chalk = {
  adjust: (st, pos, angle ) ->
    jitter = 1/8
    radius = st.width / 8
    pos = vadd pos, vnmul randvector(), jitter*st.width
    ellipseratio = 1
    return pos: pos, radius: radius, angle: angle, ellipseratio: ellipseratio, color: st.color
}
brushpresets.spatter = {
  adjust: (st, pos, angle ) ->
    jitter = 1
    radius = st.width*Math.random()/10
    tmpcolor = st.color
    pos = vadd pos, vnmul randvector(), jitter*st.width
    ellipseratio = 1
    return pos: pos, radius: radius, angle: angle, ellipseratio: ellipseratio, color: tmpcolor
}
brushpresets.bristles = {
  adjust: (st, pos, angle ) ->
    speed = vmag vsub st.to, st.from
    jitter = 1/2
    tmpcolor = st.color
    pos = vadd pos, vnmul randvector(), jitter*st.width
    ellipseratio = 0.1
    radius=st.width*2/3
    angle += Math.PI/2
    return pos: pos, radius: radius, angle: angle, ellipseratio: ellipseratio, color: tmpcolor
}
brushpresets.directionalbrush = {
  adjust: (st, pos, angle ) ->
    tmpcolor = st.color
    ellipseratio = 0.1
    return pos: pos, radius: st.width/2, angle: angle, ellipseratio: ellipseratio, color: tmpcolor
}
brushpresets.noise = {
  adjust: (st, pos, angle ) ->
    jitter = 1
    radius = st.width*Math.random()/10
    tmpcolor = pickcolor canvasobj, pos
    tmpcolor = adjustalpha tmpcolor, 1
    pos = vadd pos, vnmul randvector(), jitter*st.width
    ellipseratio = 1
    return pos: pos, radius: radius, angle: angle, ellipseratio: ellipseratio, color: tmpcolor
}
brushpresets.smudge = {
  adjust: (st, pos, angle ) ->
    jitter = 0
    tmpcolor = pickcolor canvasobj, pos
    tmpcolor = adjustalpha tmpcolor, 0.1
    pos = vadd pos, vnmul randvector(), jitter*st.width
    ellipseratio = 1
    return pos: pos, radius: st.width/2, angle: angle, ellipseratio: ellipseratio, color: tmpcolor
}
brushpresets.wetpaint = {
  adjust: (st, pos, angle ) ->
    jitter = 0
    tmpcolor = pickcolor canvasobj, pos
    tmpcolor = adjustalpha tmpcolor, 0.5
    pos = vadd pos, vnmul randvector(), jitter*st.width
    ellipseratio = 0.4
    return pos: pos, radius: st.width/2, angle: angle, ellipseratio: ellipseratio, color: tmpcolor
}

pixicolor = (rgba) ->
  return rgba.r*256*256+rgba.g*256+rgba.b
  #*0x000001

jqbrush = $ "<canvas>"
jqbrush.attr width: 32, height: 32
brushcanvas = jqbrush.get(0)
context=brushcanvas.getContext '2d'
context.beginPath()
rad=16
context.arc 0, 0, rad, 0, 2*Math.PI, false
context.fillStyle = 'orange'
context.fill()


brushtexture = PIXI.Texture.fromCanvas brushcanvas

drawstroke = ( st ) ->
  #stage = new PIXI.Stage 0xFFFFFF, true
  radiusperdab = 1/3
  threshold = st.width*radiusperdab
  FRAC=vdist( st.from, st.to )/(st.width)
  dabcount=Math.ceil vdist( st.from, st.to )/threshold
  dabcount = Math.max 2,dabcount
  #fuck
  #auhgh tihs is too slow
  #Math.seedrandom st.brush+String(st.to.x)+String(st.to.y)+String(st.from.x)+String(st.from.y)+String(dabcount)
  dir=vsub st.to, st.from
  dabz=[1..dabcount].map (n) ->
    c=n/dabcount
    offs = vnmul dir,c
    return vadd st.from, offs
  strokediff=vsub st.from, st.to
  strokedirection = Math.atan2 strokediff.y, strokediff.x
  brush = brushpresets[st.brush] or brushpresets.default
  dabz.forEach (dab) ->
    newdab = brush.adjust( st, dab, strokedirection )
    #if newdab.erase then
    #huhh
    #pixi
    alpha = newdab.color.a
    stage.addChild grof = new PIXI.Graphics()
    grof.beginFill pixicolor( newdab.color ), alpha
    tmprad = newdab.radius*newdab.ellipseratio
    grof.drawElipse 0,0, newdab.radius*newdab.ellipseratio, newdab.radius
    grof.rotation = newdab.angle
    grof.position = new PIXI.Point newdab.pos.x, newdab.pos.y
    #sprite = new PIXI.Sprite brushtexture
    #sprite.position.x = newdab.pos.x
    #sprite.position.y = newdab.pos.y
    #stage.addChild sprite
    #

makestroke = ( st ) ->
  from = st.from
  to = st.to
  r = st.width
  col = st.color
  #drawstroke( from, to, r, col )
  #strokedata = color: col, width: r, from: from, to: to,
  strokedata = st
  cache.push strokedata
  #replaytick()
  if socket
    socket.emit 'stroke', strokedata
  #renderer.render stage

toolbar = $ "<div id=toolbar>"
toolbar.css position: 'relative', overflow: 'auto', height: '100%'
contain.append toolbar

header = (str) -> $ tag "h3", str
label = (str) -> $ tag "label", str

toolbar.append header "brush"
toolbar.append container = $ "<div>"

container.append brushselection= $ "<select>"
for k,v of brushpresets
  brushselection.append tag "option", k
brushselection.change (e) ->
  currentbrush = this.value
brushselection.css 'display': 'block'

container.append lab= label "size"
lab.attr 'for': 'radiusslider'
radiusslider = $ "<div id=radiusslider></div>"
radiusslider.slider min: ABSMINRADIUS, max: ABSMAXRADIUS, range: true, slide: (e,ui) ->
  minradius = ui.values[0]
  maxradius = ui.values[1]
container.append radiusslider

brushsizedelta = ( delta ) ->
  maxradius = maxradius + delta
  maxradius = Math.max maxradius, ABSMINRADIUS
  maxradius = Math.min maxradius, ABSMAXRADIUS
  radiusslider.slider 'values', minradius, maxradius

brushsizeup = ->
  brushsizedelta 1
brushsizedown = ->
  brushsizedelta -1

keytapbind 'z', brushsizedown
keytapbind 'a', brushsizeup

container.append label 'opacity'

alphaslider = $ "<div>"
alphaslider.slider min: 0, max: 1, step: 0.01, value: 1, slide: (e,ui) ->
  updatecolor rgba color.r, color.g, color.b, ui.value
container.append alphaslider

toolbar.append header "color"
toolbar.append colorpicker = $ "<div>"
colorpicker.addClass 'colorpicker'

colorslider = ->
  sliderelem = $ "<div>"
  sliderelem.slider min: 1, max: 255, range: 'min'
  sliderelem.css height: 50, display: 'inline-block'
  return sliderelem

redslider = colorslider().slider orientation: 'vertical', slide: (e,ui) ->
  updatecolor rgba ui.value, color.g, color.b, color.a
greenslider = colorslider().slider orientation: 'vertical', slide: (e,ui) ->
  updatecolor rgba color.r, ui.value, color.b, color.a
blueslider = colorslider().slider orientation: 'vertical', slide: (e,ui) ->
  updatecolor rgba color.r, color.g, ui.value, color.a
redslider.addClass 'red'
greenslider.addClass 'green'
blueslider.addClass 'blue'

colorbox = $ "<div>&nbsp;</div>"
colorbox.css height: 32, width: 32, float: 'right'


colorpicker.append "<ul><li><a href='#rgbpick'>rgb</a></li><li><a href='#wheelpick'>wheel</a></li></ul>"

colorpicker.append rgbpicker = $ "<div id=rgbpick>"
rgbpicker.append colorbox
colorpicker.addClass 'colorpicker'
rgbpicker.append redslider, greenslider, blueslider


colorpicker.append colorwheeldom = $ "<div id=wheelpick>"
colorwheel = Raphael.colorwheel colorwheeldom, 128

colorpicker.tabs()

updatecolor = ( col ) ->
  #color = r: r, g: g, b: b, a: a
  color = col
  redslider.slider value: color.r
  greenslider.slider value: color.g
  blueslider.slider value: color.b
  alphaslider.slider value: color.a
  colorbox.css "background", csscolor color
  colorwheel.color csscolor color
spuncolorwheel = ( col ) ->
  color = col
  redslider.slider value: color.r
  greenslider.slider value: color.g
  blueslider.slider value: color.b
  alphaslider.slider value: color.a
  colorbox.css "background", csscolor color

round=Math.round
colorwheel.onchange (rcol) ->
  nc = rgba round(rcol.r), round(rcol.g), round(rcol.b), color.a
  spuncolorwheel nc

swatches = $ "<div></div>"
colorpicker.append swatches


updateswatches = ->
 x = recentcolors.map (col) ->
   but= $ tag "button"
   but.css "background": csscolor col
   but.button()
   but.css width: 20, height: 20
   but.click -> updatecolor col
 swatches.html ''
 swatches.append x

clearctx = (ctx) ->
  ctx.clearRect 0, 0, CANVASWIDTH, CANVASHEIGHT

clearcanvas = ->
  #TODO FIX

lastframe = 0

startreplay = ->
  clearcanvas()
  lastframe = 0
  return false

strokespertick = 1

disablecanvas  = ->
  displaycanvaselem.addClass "disabled"
enablecanvas = ->
  displaycanvaselem.removeClass "disabled"

timecall = (func) ->
  starttime = Date.now()
  func()
  Date.now()-starttime

stagecount = 0
replaytick = ->
  if lastframe == cache.length
    if nocache and cache.length > 100 then clearlocalcache()
    enablecanvas()
    return
  if stagecount > 100
    stagecount=0
    tex = new PIXI.RenderTexture CANVASWIDTH, CANVASHEIGHT
    tex.render stage
    #tex= PIXI.Texture.fromCanvas renderer.view
    base= new PIXI.Sprite tex
    stage = new PIXI.Stage 0xFFFFFF, true
    stage.addChild base
  displaycanvasctx.drawImage renderer.view, 0, 0
  if lastframe == 0 and cache.length > 3
    disablecanvas()
  starttime = Date.now()
  if cache.length > lastframe
    for x in [0..strokespertick]
      stagecount++
      if lastframe is cache.length then break
      curr = cache[lastframe]
      drawstroke curr
      lastframe++
  timebar.progressbar value: lastframe, max: cache.length

luup = ->
  replaytick()
  requestAnimFrame -> renderer.render stage
  #requestAnimFrame luup
  setTimeout luup, 5

#requestAnimFrame luup
luup()

cursoroncanvas=false
displaycanvaselem.mouseenter -> cursoroncanvas=true
displaycanvaselem.mouseout -> cursoroncanvas=false

networkcursors = []

assembleimg = () ->
  clearctx displaycanvasctx
  displaycanvasctx.fillStyle='white'
  displaycanvasctx.fillRect 0, 0, CANVASWIDTH, CANVASHEIGHT

drawloop = ->
  idealms=1
  if not paused
    replaytick lastframe
  #assembleimg()
  if cursoroncanvas
    drawcursor mpos, color, maxradius
    drawcursor mpos, color, minradius
  networkcursors.forEach (c) -> c()
  networkcursors=[]

  setTimeout drawloop, idealms
  #PIXI

drawcursor = ( pos, col, rad ) ->
  dcc=displaycanvasctx
  dcc.beginPath()
  dcc.arc pos.x, pos.y, rad/2, 0, 2*Math.PI, false
  dcc.lineWidth = 1
  dcc.fillStyle = 'none'
  dcc.strokeStyle = csscolor adjustalpha col, 1/2
  dcc.stroke()

skipreplay = ->
  tolast()
  return false
keytapbind 'k', skipreplay

tolast = ->
  while cache.length > lastframe
    replaytick()

skipbutton = $ "<button>\"skip\" replay (may cause a huge delay)</button>"
skipbutton.click skipreplay
skipbutton.button icons: { primary: "ui-icon-seek-end" }, text: true

#loadbutton = $ "<button>(re)load session</button>"
#loadbutton.click -> loadsession()
#loadbutton.button()

archiveurl="./files/archive/20130904.json.txt"
loadarchivedsession = (url) ->
  log "downloading session..."
  $.get url,
    ( (data, textstatus, jqxhr ) ->
      cache = data
      #size=jqxhr.getResponseHeader 'Content-Length'
      fcount = cache.length
      log "cache loaded, #{fcount} strokes."
      startreplay()
    )
    , 'json'
archivebutton = $ tag "button", "view an archived session"
archivebutton.click ->
  alert "keep in mind this just affects your local replay, any new doodling that happens wll be sent to the current active session \n  TODO: fix this"
  loadarchivedsession archiveurl
archivebutton.button()


replayspeed = $ "<div>"
replayspeed.css 'width': 100
replayspeed.slider min: 1, max: 200, slide: ( (e, ui) -> strokespertick = ui.value )

loadsession = ->
  log "downloading session..."
  $.get '/getsession',
    ( (data, textstatus, jqxhr ) ->
      cache = data
      #size=jqxhr.getResponseHeader 'Content-Length'
      fcount = cache.length
      log "cache loaded, #{fcount} strokes."
      startreplay()
    )
    , 'json'

toolbar.append header "tablet (wacom driver)"
toolbar.append container = $ "<div>"
container.append label "pressure affects..."
container.append $ "<input type=checkbox id=pressure /><label for=pressure>size</label>"
container.append $ "<input type=checkbox id=opacity /><label for=opacity>opacity</label>"

$('#pressure').change ->
  tabletaffectsradius = this.checked
$('#opacity').change -> tabletaffectsopacity = this.checked


toolbar.append header "misc"
toolbar.append container = $ "<div>"


container.append label "export "
exportpng = ->
  assembleimg()
  url=displaycanvaselem.get(0).toDataURL("image/png")

  window.open url

keytapbind 'p', exportpng
keytapbind 'r', startreplay


savebutton = $ tag "button", ".png snapshot"

savebutton.click -> exportpng()
savebutton.button()
container.append savebutton

exportsvg = ->
  #TODO don't hardcode these
  data=""
  data+= "<svg xmlns='http://www.w3.org/2000/svg' version='1.1' viewbox='0 0 1000 600'>"
  data+=cache.map( (s) -> "<line x1='#{s.from.x}' y1='#{s.from.y}' x2='#{s.to.x}' y2='#{s.to.y}' stroke='#{csscolor s.color}' stroke-width='#{s.width}' stroke-linecap='round' />" ).join()
  data+="</svg>"
  window.open dataurl data
  return false
savebutton= $ tag "button", ".svg"
savebutton.click -> exportsvg()
savebutton.button()
container.append savebutton

exportjson = -> window.open "/getsession"
savebutton = $ tag "button", ".json"
savebutton.click -> exportjson()
savebutton.button()
container.append savebutton

flipped = false
toggleflip = () ->
  flipped = not flipped
  if flipped
    displaycanvaselem.addClass 'flipped'
  else
    displaycanvaselem.removeClass 'flipped'

flipbutton = $ tag "button", "flip canvas view"
flipbutton.click toggleflip
flipbutton.button()
container.append flipbutton

keytapbind 'i', toggleflip

bombsahoy = () ->
  cache = []
  startreplay()
  log "BOMBS AHOY"

bombbutton = $ tag "button", "BOMB"
bombbutton.click ->
  if not ( confirm('really?') and confirm "are you super sure? this will nuke the contents of the canvas straight off the face of the earth" ) then return false
  bombsahoy()
  socket.emit 'bomb'
  return false
bombbutton.button()
bombbutton.css 'font-size': 10, 'margin-top': 20, color: 'darkred', display: 'block'
container.append bombbutton
container.append ll=label "big friendly global thermonuclear annihilation button, pressing it will destroy the canvas contents"
ll.css color: 'gray'

# wee woo copy pasted code alert
$.fn.togglepanels = ->
  return this.each( ->
    $(this).addClass("ui-accordion ui-accordion-icons ui-widget ui-helper-reset")
    .find("h3")
      .addClass("ui-accordion-header ui-helper-reset ui-state-default ui-corner-top ui-corner-bottom")
      .hover( -> $(this).toggleClass("ui-state-hover") )
      .prepend('<span class="ui-icon ui-icon-triangle-1-e"></span>')
      .click( ->
        $(this)
          .toggleClass("ui-accordion-header-active ui-state-active ui-state-default ui-corner-bottom")
          .find("> .ui-icon").toggleClass("ui-icon-triangle-1-e ui-icon-triangle-1-s").end()
          .next().slideToggle()
        return false
      )
      .next()
        .addClass("ui-accordion-content ui-helper-reset ui-widget-content ui-corner-bottom")
        .hide()
  )
# end of alert

toolbar.css 'float': 'left', width: '150px'
toolbar.insertBefore canvascontainer

#toolbar.togglepanels()
#toolbar.dialog()
#toolbar.dialog('open')

opentoolbar = ->
  toolbar.dialog('open')
  #.dialog('widget')
  #.position( my: 'left', at: 'left', of: canvaselem )
replaycontrols = $ "<div id=replaycontrols>"
replaycontrols.css clear: 'left'
#replaycontrols.css width: '100%'
#replaycontrols.css 'background-color':'#eee', border: '1px inset', padding: 2, 'float': 'left', 'width': '100%'

#opentoolbar()

body.append replaycontrols

pausebutton = $ "<button>pause/unpause replay</button>"
pausebutton.button icons: { primary: "ui-icon-pause" }, text: true
pausebutton.click ->
  paused=not paused

replaybutton = $ "<button>restart replay</button>"
replaybutton.button icons: { primary: "ui-icon-seek-first" }, text: true
replaybutton.click startreplay

replayspeed.css 'margin': 5, float: 'left'

timebar = $ "<div></div>"
replaycontrols.append "<label>replay speed</label>"
replaycontrols.append replayspeed
replaycontrols.append skipbutton
cachebutton = $ "<button>clear local replay cache</button>"
clearlocalcache = ->
  cache = []
  lastframe = 0
cachebutton.click clearlocalcache
cachebutton.button()
replaycontrols.append pausebutton, replaybutton
#cachebutton
#loadbutton
replaycontrols.append archivebutton


tickbutton = $ "<button>advance one tick</button>"
tickbutton.click replaytick
replaycontrols.append tickbutton

replaycontrols.append $ "<input type=checkbox id=nocache /><label for=nocache>clear cache automagically</label>"

$('#nocache').change -> nocache = this.checked

replaycontrols.append "&middot;"

#replaycontrols.append but = $ "<button id=toolbarbutton>open toolbar</button>"
#but.button()
#but.click opentoolbar

replaycontrols.append $ "<div id='hotkeyinfo'></div>"
listdata = [ "i - flip canvas", "a/z - change brush size", "x - swap color", "p - png snapshot", "r - replay", "k - skip replay (takes a while)" ]
  .map (x) -> tag "li", x
$("#hotkeyinfo").append "Hold alt and press one of the following:\n"+tag "ul", listdata.join("")
$("#hotkeyinfo").hide()

replaycontrols.append but = $ tag "button", "hotkey info"
but.button icons: { primary: "ui-icon-help" }, text: true
but.click -> $("#hotkeyinfo").dialog()

replaycontrols.append timebar


#info = $ "<textarea style='height: 100px;' readonly></textarea>"
info = $ "<div>"
info.css width: '100%', background: 'white', font: 'sans-serif', overflow: 'scroll', height: '300px'

zeropad = (num) ->
  if num < 10
    return '0'+num
  return String num

infoprepend = (text) ->
  now=new Date
  hh=zeropad now.getHours()
  mm=zeropad now.getMinutes()
  ss=zeropad now.getSeconds()
  timestamp = "#{hh}:#{mm}:#{ss}"
  text=timestamp+"|&nbsp;"+text
  info.prepend text

timelog = (time,text) ->
  hh=zeropad time.getHours()
  mm=zeropad time.getMinutes()
  ss=zeropad time.getSeconds()
  timestamp = "#{hh}:#{mm}:#{ss}"
  text=timestamp+"|&nbsp;"+text
  info.prepend text


weekdays=["Sun","Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
datelog = (time) ->
  dd=zeropad time.getUTCDate()
  mm=zeropad time.getUTCMonth()+1
  yyyy=time.getUTCFullYear()
  weekday=weekdays[time.getUTCDay()]
  timestamp = "#{yyyy}/#{mm}/#{dd} (#{weekday})"
  stuff=$ tag "div", timestamp
  stuff.css color: 'salmon', 'border-bottom': '1px solid salmon'
  info.prepend stuff

htmlencode = (str) ->
  String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')


prevtime = 0

someonesaid = ( timems, name, text ) ->
  time = new Date timems
  if timems - prevtime > 1000*60*60
    datelog time
  oldrandom=Math.random
  Math.seedrandom name
  hue = Math.random()*360
  Math.random=oldrandom
  timelog time, "<span style=\"color: hsl(#{hue},50%,50%)\">#{htmlencode name}></span> #{htmlencode text}<br/>\n"
  prevtime = timems

chatname = false
say = ( text ) ->
  if not chatname
    chatname = prompt "pick a name", 'anon'
  if not chatname then return
  text=chatinput.val()
  time=new Date().getTime()
  someonesaid time, chatname, text
  socket.emit 'say', { name: chatname, text: text, time: time }


chatbox = $ "<form>"
chatbox.css margin: 0
chatbox.submit ->
  say chatinput.val()
  chatinput.val ''
  return false

body.append chatbox
chatbox.append chatinput = $ "<input type='text' placeholder='type words here'>"
#chatbox.append $ "<input type='submit' value='say'></input>"
chatinput.css 'width': '100%'
chatinput 

body.append info
info.css 'user-select': 'text'

skipbutton.css 'float': 'right'

log = (text) ->
  infoprepend "**#{text}<br/>\n"

loadchat = ->
  $.get '/chatlog',
    ( (data, textstatus, jqxhr ) ->
      for datum in data
        someonesaid datum.time, datum.name, datum.text
    )
    , 'json'

$(document).ready ->
  loadsession()
  loadchat()
  disablecanvas()
  luup()
  #drawloop()
  brushsizedelta 0
  updateswatches()
  if NETWORKED
    socket = io.connect '/'
    socket.on 'stroke', (data) ->
      cache.push data
      networkcursors.push -> drawcursor data.to, rgba(0,0,0,1/2), data.width
    socket.on 'say', (data) ->
      someonesaid data.time, data.name, data.text 
    socket.on 'bomb', (data) ->
      bombsahoy()

updatecolor rgba 0, 0, 0, 1

