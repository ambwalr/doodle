# doodle
# a creatively named javascript app for multi user online doodling
# by ambwalr at gmail

body = $ "body"
canvaselem = $ "#doodlecanvas"
canvasobj = canvaselem[0].getContext "2d"

wacom = -> document.getElementById 'wtPlugin'

isdrawing = false
holdingright = false

cache = []

rgba = ( r, g, b, a ) ->
  r: r, g: g, b: b, a: a

recentcolors = [ rgba(0,0,0,1), rgba(255,255,255,1), rgba(255,0,0,1) ]

socket = undefined

canvaselem.mousedown (e) ->
  if e.button == 0
    mpos = correctpos e
    isdrawing = true
  if e.button == 2
    holdingright = true
    rdown e
canvaselem.mouseup (e) ->
  if e.button == 0
    isdrawing = false
  if e.button == 2
    holdingright = false
body.mouseup (e) ->
  if e.button == 0
    isdrawing = false
  if e.button == 2
    holdingright = false

correctpos = (e) ->
  screenpageoffset = x: e.screenX-e.pageX, y: e.screenY-e.pageY
  x=e.pageX
  y=e.pageY
  #penapi = wacom().penAPI
  #console.log penapi
  #if penapi and penapi.isInProximity
  #  x = penapi.sysX
  #  y = penapi.sysY
  #  x -= screenpageoffset.x
  #  y -= screenpageoffset.y
  offset = canvaselem.offset()
  x-=offset.left
  y-=offset.top
  if flipped
    x = canvaselem.width()-x

  
  return x: x, y: y

color = r: 0, g: 0, b: 0, a: 1

canvaselem.bind 'contextmenu', (e) ->
  return false

rdown = (e) ->
  mpos = correctpos e
  imgd = canvasobj.getImageData mpos.x, mpos.y, 1, 1
  r = imgd.data[0]
  g = imgd.data[1]
  b = imgd.data[2]
  a = color.a
  console.log mpos
  console.log imgd
  updatecolor rgba r, g, b, a

prev = undefined
maxradius = 10
lastdab = undefined

vnmul = ( v,n ) ->
  return x: v.x*n, y: v.y*n
vadd = ( a,b ) ->
  return x: a.x+b.x, y: a.y+b.y
vsub = ( a,b ) ->
  return x: a.x-b.x, y: a.y-b.y

vmag = ( v ) ->
  Math.sqrt( Math.pow(v.x,2)+Math.pow(v.y,2) )

vdist = ( a, b ) -> vmag vsub a,b


cancelright = (e) ->
  if e.button == 2
    holdingright = false
canvaselem.mouseup cancelright

updaterecentcolors = () ->
  if color not in recentcolors
    recentcolors.push color
    updateswatches()
  if recentcolors.length > 8
    recentcolors.shift()
    updateswatches()

threshfraction = 0.5

draw = (mpos) ->
  if not isdrawing
    prev = undefined
    lastdab = undefined
    return
  updaterecentcolors()
  penapi = wacom().penAPI
  if penapi and penapi.isInProximity
    pressure = penapi.pressure
  else
    pressure = 1
  r = maxradius * pressure
  threshold = r* threshfraction
  if prev
    if penapi and penapi.isEraser
      tmpcolor = r: 255, g: 255, b: 255, a: 1
      stroke prev.x, prev.y, mpos.x, mpos.y, r, tmpcolor
    else
      stroke prev.x, prev.y, mpos.x, mpos.y, r, color
    #if not lastdab
    #  dab mpos, r, color
    #  lastdab = x: mpos.x, y: mpos.y
    #else
    #  dabcount=vdist( lastdab, mpos )/threshold
    #  if dabcount >= 1
    #    max = Math.floor dabcount
    #    dir=vsub mpos, lastdab
    #    for i in [1..max]
    #      c=i/max
    #      offs=vnmul dir, c
    #      tmppos = vadd lastdab, offs
    #      dab tmppos, r, color
    #    prev = mpos
    #    lastdab = x: mpos.x, y: mpos.y

  prev = x: mpos.x, y: mpos.y

canvaselem.mousemove (e) ->
  if holdingright
    rdown e
  mpos = correctpos e
  draw(mpos)

csscolor = ( col ) ->
  "rgba(#{col.r},#{col.g},#{col.b},#{col.a})"

drawstroke = ( from, to, r, col ) ->
  canvasobj.strokeStyle = csscolor col
  canvasobj.lineWidth = r
  canvasobj.lineCap="round"
  canvasobj.beginPath()
  canvasobj.moveTo from.x, from.y
  canvasobj.lineTo to.x, to.y
  canvasobj.stroke()

noop = ->
handler = ( data, jblerf ) ->
  #console.log data

stroke = ( x1, y1, x2, y2, r, col ) ->
  from = x: x1, y: y1
  to = x: x2, y: y2
  #drawstroke( from, to, r, col )
  strokedata = color: col, width: r, from: from, to: to
  cache.push strokedata
  replaytick()
  if socket
    socket.emit 'stroke', strokedata
  #$.post '/sendstroke', strokedata, noop, "json"

dab = ( pos, r, col ) ->
  dabdata = c: col, p: pos, r: r
  cache.push dabdata
  replaytick()
  if socket
    socket.emit 'stroke', dabdata

drawdab = ( pos, r, col ) ->
  canvasobj.beginPath()
  canvasobj.arc pos.x, pos.y, r, 0, 2*Math.PI, true
  canvasobj.fillStyle = csscolor col
  canvasobj.fill()

toolbar = $ "<div id=toolbar>"
body.append toolbar

header = (str) -> $ "<h3>#{str}</h3>"
label = (str) -> $ "<label>#{str}</label>"

toolbar.append header "brush"
toolbar.append container = $ "<div>"

WEDABSNOW = false
if WEDABSNOW
  container.append label "spacing"
  spacingslider = $ "<div></div>"
  spacingslider.slider min: 1/20, max: 2, step: 1/100, slide: (e,ui) ->
    threshfraction = ui.value
  container.append spacingslider

container.append label "size"
radiusslider = $ "<div></div>"
radiusslider.slider min: 1, max: 100, slide: (e,ui) ->
  maxradius = ui.value
container.append radiusslider

toolbar.append header "color"
toolbar.append colorpicker = $ "<div>"
colorpicker.addClass 'colorpicker'

colorslider = ->
  sliderelem = $ "<div>"
  sliderelem.slider min: 1, max: 255, range: 'min'
  return sliderelem

redslider = colorslider().slider slide: (e,ui) ->
  updatecolor rgba ui.value, color.g, color.b, color.a
greenslider = colorslider().slider slide: (e,ui) ->
  updatecolor rgba color.r, ui.value, color.b, color.a
blueslider = colorslider().slider slide: (e,ui) ->
  updatecolor rgba color.r, color.g, ui.value, color.a
redslider.addClass 'red'
greenslider.addClass 'green'
blueslider.addClass 'blue'
alphaslider = $ "<div>"
alphaslider.slider min: 0, max: 1, step: 0.01, value: 1, slide: (e,ui) ->
  updatecolor rgba color.r, color.g, color.b, ui.value

colorbox = $ "<div>&nbsp;</div>"
colorpicker.append colorbox
colorbox.css float: 'right', width: 32, height: 32, margin: 8

colorpicker.append redslider, greenslider, blueslider, alphaslider

updatecolor = ( col ) ->
  #color = r: r, g: g, b: b, a: a
  color = col
  redslider.slider value: color.r
  greenslider.slider value: color.g
  blueslider.slider value: color.b
  alphaslider.slider value: color.a
  colorbox.css "background", csscolor color

swatches = $ "<div></div>"
colorpicker.append swatches

updateswatches = ->
 x = recentcolors.map (col) ->
   but= $ "<button></button>"
   but.css "background": csscolor col
   but.button()
   but.css width: 20, height: 20
   but.click -> updatecolor col
 swatches.html ''
 swatches.append x

clearcanvas = ->
  w = 1280
  h = 700
  canvasobj.clearRect 0, 0, w, h

lastframe = 0

startreplay = ->
  clearcanvas()
  lastframe = 0
  return false

strokespertick = 1

replaytick = ->
  for x in [0..strokespertick]
    if cache.length > lastframe
      curr = cache[lastframe]
      drawstroke curr.from, curr.to, curr.width, curr.color
      #drawdab curr.p, curr.r, curr.c
      lastframe++
  timebar.progressbar value: lastframe, max: cache.length

drawloop = ->
  replaytick lastframe
  setTimeout drawloop, 1

skipreplay = ->
  tolast()
  return false

tolast = ->
  while cache.length > lastframe
    replaytick()

skipbutton = $ "<button>SKIP replay</button>"
skipbutton.click skipreplay
skipbutton.button()


loadbutton = $ "<button>(re)load session</button>"
loadbutton.click -> loadsession()
loadbutton.button()

replayspeed = $ "<div>"
replayspeed.css 'width': 100
replayspeed.slider min: 1, max: 100, slide: ( (e, ui) -> strokespertick = ui.value )

loadsession = ->
  log "downloading session..."
  $.get '/getsession',
    ( (data, textstatus, jqxhr ) ->
      cache = data
      size=jqxhr.getResponseHeader 'Content-Length'
      fcount = cache.length
      log "#{size} byte cache loaded, #{fcount} strokes."
      startreplay()
    )
    , 'json'

#toolbar.append header "tablet (wacom)"
#toolbar.append container = $ "<div>"
#container.append label "pressure affects..."
#container.append $ "<input type=checkbox id=pressure /><label for=pressure>pressure</label>"
#container.append $ "<input type=checkbox id=opacity /><label for=opacity>opacity</label>"

toolbar.append header "misc"
toolbar.append container = $ "<div>"

container.append label "export "
exportpng = ->
  url=canvaselem.get(0).toDataURL("image/png")

  window.open url

savebutton = $ "<button>.png</button>"

savebutton.click -> exportpng()
savebutton.button()
container.append savebutton

exportjson = -> window.open "/getsession"
savebutton = $ "<button>replay .json</button>"
savebutton.click -> exportjson()
savebutton.button()
container.append savebutton
container.append $ "<hr>"

flipped = false
toggleflip = () ->
  flipped = not flipped
  if flipped
    canvaselem.addClass 'flipped'
  else
    canvaselem.removeClass 'flipped'

flipbutton = $ "<button>flip canvas view</button>"
flipbutton.click toggleflip
flipbutton.button()


container.append flipbutton

antialias = true
togglealias = () ->
  antialias = not antialias
  if antialias
    canvasobj.mozImageSmoothingEnabled = false
    canvasobj.webkitImageSmoothingEnabled = false
    canvasobj.imageSmoothingEnabled = false
  else
    canvasobj.mozImageSmoothingEnabled = true
    canvasobj.webkitImageSmoothingEnabled = true
    canvasobj.imageSmoothingEnabled = true

aliasbutton = $ "<button>toggle (anti)aliasing</button>"
aliasbutton.click togglealias
aliasbutton.button()
#container.append aliasbutton



bombbutton = $ "<button>BOMB</button>"
bombbutton.click ->
  if not confirm "are you super sure?" then return false
  cache = []
  startreplay()
  socket.emit 'bomb'
  return false
bombbutton.button()
bombbutton.css 'font-size': 10, 'margin-top': 50, color: 'darkred', display: 'block'
container.append bombbutton

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

#toolbar.togglepanels()
toolbar.dialog()

opentoolbar = ->
  $("#toolbar").dialog('open').dialog('widget').position( my: 'left', at: 'right', of: canvaselem )
opentoolbar()

replaycontrols = $ "<div id=replaycontrols>"
#replaycontrols.css width: '100%'
#replaycontrols.css 'background-color':'#eee', border: '1px inset', padding: 2, 'float': 'left', 'width': '100%'

body.append replaycontrols

replaybutton = $ "<button>restart replay</button>"
replaybutton.button()
replaybutton.click startreplay

replayspeed.css 'margin': 5

timebar = $ "<div></div>"
replaycontrols.append "<label>replay speed</label>"
replaycontrols.append replayspeed, timebar
replaycontrols.append skipbutton
cachebutton = $ "<button>clear local replay cache</button>"
cachebutton.click ->
  tolast()
  cache = []
  lastframe = 0
cachebutton.button()
replaycontrols.append replaybutton, loadbutton, cachebutton

replaycontrols.append "&middot;"

replaycontrols.append but = $ "<button>open toolbar</button>"
but.button()
but.click opentoolbar

info = $ "<textarea style='height: 100px;' readonly></textarea>"
info.css width: '100%'
body.append info

skipbutton.css 'float': 'right'

log = (text) ->
  info.prepend "#{text}<br/>\n"

$(document).ready ->
  loadsession()
  drawloop()
  updateswatches()
  socket = io.connect '/'
  socket.on 'stroke', (data) ->
    cache.push data
  socket.on 'bomb', (data) ->
    cache = []
    startreplay()

