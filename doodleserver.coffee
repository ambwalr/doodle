port = 8008

express = require 'express'
app = express()
server = require('http').Server app
ior = require 'socket.io'
io = ior.listen server

server.listen port

app.use express.bodyParser()

cache = []

app.get '/getsession', ( req, res ) ->
  res.send cache

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
  socket.on 'bomb', (data) ->
    cache = []
    socket.broadcast.emit 'bomb'

