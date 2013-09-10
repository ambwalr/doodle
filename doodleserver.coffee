port = 8008

express = require 'express'
app = express()
server = require('http').Server app
ior = require 'socket.io'
io = ior.listen server
zlib = require 'zlib'

server.listen port

app.use express.bodyParser()

cache = []
chatlog = []

#app.get '/getsession', ( req, res ) ->
#  res.send cache

app.get '/getsession', ( req, res ) ->
  res.writeHead 200, { "Content-Type": "application/json", "Content-Encoding": "gzip" }
  buf = new Buffer JSON.stringify(cache), 'utf-8'
  zlib.gzip buf, (_,result) -> res.end result

app.get '/chatlog', ( req, res ) ->
  res.writeHead 200, { "Content-Type": "application/json", "Content-Encoding": "gzip" }
  buf = new Buffer JSON.stringify(chatlog), 'utf-8'
  zlib.gzip buf, (_,result) -> res.end result

#app.post '/sendstroke', ( req, res ) ->
#  cache.push req.body
#  console.log req.body
#  res.send ''

app.use '/', express.static __dirname+'/'

app.use express.static __dirname+'/public'

io.sockets.on 'connection', (socket) ->
  #socket.emit 'message', ( message: 'sup' )
  socket.on 'stroke', (data) ->
    cache.push data
    socket.broadcast.emit 'stroke', data
  socket.on 'say', (data) ->
    data.time = new Date().getTime()
    chatlog.push data
    while chatlog.length > 10
      chatlog.shift()
    socket.broadcast.emit 'say', data
  socket.on 'bomb', (data) ->
    cache = []
    socket.broadcast.emit 'bomb'

