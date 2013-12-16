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

			sa.end (err, res)->
#			SuperAgent.get('http://localhost:7000/http_test').end (err, res)->
				if !err?
#					console.log res
					q.resolve res.text
				else
					q.reject err

			q.promise
		else
			Q.reject new Error 'No url given for http action'

module.exports =
	Http: Http
