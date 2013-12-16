Q = require 'q'
SuperAgent = require 'superagent'

class Http
	invoke: (ctx, args)->
		url = args[ 0 ]

		if url?
			q = Q.defer()

			method = args[ 1 ]?.toLowerCase() || 'get'
			data = args[ 2 ]
			headers = args[ 3 ]

			sa = SuperAgent[ method ]( url )

			if data?
				sa = sa.send data

			if headers?
				for k, v of headers
					sa = sa.set k, v

			sa.end (err, res)=>
				if !err?
					q.resolve @_extract res
				else
					q.reject err

			q.promise
		else
			Q.reject new Error 'No url given for http action'

	_extract: (res)->
		res.text

class Json extends Http
	_extract: (res)->
		res.body

module.exports =
	Http: Http
	Json: Json
