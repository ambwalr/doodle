# doodle
# a creatively named javascript app for multi user online doodling
# by ambwalr at gmail

body = $ "body"
canvaselem = $ "#doodlecanvas"
canvasobj = canvaselem[0].getContext "2d"

tag = ( type="div", body="" ) -> "<#{type}>#{body}</#{type}>"
dataurl = (data) -> "data:image/svg+xml;base64,"+btoa data

wacom = -> document.getElementById 'wtPlugin'
tabletaffectsradius = false
tabletaffectsopacity = false


isdrawing = false
holdingright = false

cache = []

rgba = ( r, g, b, a ) -> r: r, g: g, b: b, a: a

recentcolors = [ rgba(0,0,0,1), rgba(255,255,255,1), rgba(255,0,0,1), rgba(255,130,110,1) ]

socket = undefined

canvaselem.mousedown (e) ->
  if e.button == 0
    mpos = correctpos e
    isdrawing = true
  if e.button == 2
    holdingright = true
    rdown e

cancel = (e) ->
  if e.button == 0
    isdrawing = false
  if e.button == 2
    holdingright = false

canvaselem.mouseup cancel
body.mouseup cancel

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
  if flipped then x = canvaselem.width()-x
  
  return x: x, y: y

color = rgba 0,0,0,1

canvaselem.bind 'contextmenu', (e) -> false

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
  c = recentcolors.shift()
  recentcolors.push c
  updateswatches()
  updatecolor recentcolors[0]

bindings = {}
keytapbind = ( key, func ) ->
  k=key.toUpperCase().charCodeAt 0
  bindings[k]=func

keytapbind 'x', switchcolor

$(document).bind 'keydown', (e) ->
  key = e.which
  console.log e.which
  console.log bindings
  if bindings.hasOwnProperty key
    bindings[key]()

threshfraction = 0.5

tabletmodifier = ( st ) ->
  penapi = wacom().penAPI
  pressure = penapi.pressure
  if penapi.isEraser
    newcolor = rgba 255, 255, 255, 1
    pressure = 1
  w=st.width
  f=st.from
  t=st.to
  c=st.color
  if tabletaffectsradius then w = w*pressure
  if tabletaffectsopacity
    newalpha = c.a * pressure
    c = rgba c.r, c.g, c.b, newalpha
  return from: f, to: t, width: w, color: c

draw = (mpos) ->
  if not isdrawing
    prev = undefined
    lastdab = undefined
    return
  updaterecentcolors()
  penapi = wacom().penAPI
  if prev
    st = from: prev, to: mpos, width: maxradius, color: color
    if penapi and penapi.isInProximity
      st=tabletmodifier st
    #threshold = r* threshfraction
      makestroke st
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

drawstroke = ( st ) ->
  canvasobj.strokeStyle = csscolor st.color
  canvasobj.lineWidth = st.width
  canvasobj.lineCap="round"
  canvasobj.beginPath()
  canvasobj.moveTo st.from.x, st.from.y
  canvasobj.lineTo st.to.x, st.to.y
  canvasobj.stroke()

noop = ->
handler = ( data, jblerf ) ->
  #console.log data

makestroke = ( st ) ->
  from = st.from
  to = st.to
  r = st.width
  col = st.color
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

header = (str) -> $ tag "h3", str
label = (str) -> $ tag "label", str

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

brushsizedelta = ( delta ) ->
  maxradius = maxradius + delta
  maxradius = Math.max maxradius, 1
  maxradius = Math.min maxradius, 100
  radiusslider.slider value: maxradius
brushsizeup = -> brushsizedelta 1
brushsizedown = -> brushsizedelta -1

keytapbind 'd', brushsizedown
keytapbind 'f', brushsizeup

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
   but= $ tag "button"
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
      drawstroke curr
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

toolbar.append header "tablet (wacom)"
toolbar.append container = $ "<div>"
container.append label "pressure affects..."
container.append $ "<input type=checkbox id=pressure /><label for=pressure>size</label>"
container.append $ "<input type=checkbox id=opacity /><label for=opacity>opacity</label>"

$('#pressure').change -> tabletaffectsradius = this.checked
$('#opacity').change -> tabletaffectsopacity = this.checked


toolbar.append header "misc"
toolbar.append container = $ "<div>"

container.append label "export "
exportpng = ->
  url=canvaselem.get(0).toDataURL("image/png")

  window.open url

keytapbind 'p', exportpng


savebutton = $ tag "button", ".png"

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
savebutton = $ tag "button", "replay .json"
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

flipbutton = $ tag "button", "flip canvas view"
flipbutton.click toggleflip
flipbutton.button()

keytapbind 'i', toggleflip

container.append flipbutton

bombbutton = $ tag "button", "BOMB"
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

replaycontrols.append $ "<div id='hotkeyinfo'></div>"
listdata = [ "i - flip canvas", "d/f - change brush size", "x - swap color", "right click - colorpick", "p - png snapshot" ]
  .map (x) -> tag "li", x
$("#hotkeyinfo").append tag "ul", listdata.join("")
$("#hotkeyinfo").hide()

replaycontrols.append but = $ "<button>hotkey info</button>"
but.button()
but.click -> $("#hotkeyinfo").dialog()

info = $ "<textarea style='height: 100px;' readonly></textarea>"
info.css width: '100%'
body.append info

skipbutton.css 'float': 'right'

log = (text) ->
  info.prepend "#{text}<br/>\n"

$(document).ready ->
  loadsession()
  drawloop()
  brushsizedelta 0
  updateswatches()
  socket = io.connect '/'
  socket.on 'stroke', (data) ->
    cache.push data
  socket.on 'bomb', (data) ->
    cache = []
    startreplay()

