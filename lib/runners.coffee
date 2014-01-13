Q = require 'q'
SuperAgent = require 'superagent'
Context = require './context'

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

class Trigger
	invoke: (ctx, args)->
		name = args?[ 0 ]

		values = args?[ 1 ] || {}

		if name?
			ctx.storage.queueTrigger ctx, name, values
		else
			Q.reject new Error 'No trigger name'

class StartTimer
	invoke: (ctx, args)->
		name = args?[ 0 ]
		interval = args?[ 1 ]
		options = args?[ 2 ]
		options = {} if !options?

		if name? && interval? && interval > 0
			ctx.storage.startTimer ctx, name,
				interval: interval
				count: options.count
				firstIn: options.firstIn
				expiry: options.expiry
		else
			Q.reject new Error 'Invalid parameters'

class StopTimer
	invoke: (ctx, args)->
		name = args?[ 0 ]

		if name?
			ctx.storage.stopTimer ctx, name
		else
			Q.reject new Error 'Invalid parameters'

class CreateContext
	invoke: (ctx, args)->
		name = args?[ 0 ]
		graph = args?[ 1 ]

		if name? && graph?
			values = args[ 2 ] || {}

			values[ 'contextName' ] = name
			values[ 'parentContextId' ] = ctx.id
			values[ 'parentContextGraphId' ] = ctx.graph_id

			Context.run( graph, ctx.storage, values ).then (ctx)->
				ctx.id
		else
			Q.reject new Error 'Invalid parameters'

class TriggerParent
	invoke: (ctx, args)->
		name = args?[ 0 ]
		values = args?[ 1 ] || {}

		parentId = ctx.getValue 'parentContextId'
		parentGraphId = ctx.getValue 'parentContextGraphId'
		subName = ctx.getValue 'contextName'

		if name? && parentId? && parentGraphId? && subName?
			name = "sub.#{subName}.#{name}"
			values.childContextId = ctx.id

			ctx.storage.queueExtTrigger ctx, parentGraphId, parentId, name, values
		else
			Q.reject new Error 'Parent context not set correctly'

module.exports =
	Http: Http
	Json: Json
	Trigger: Trigger
	TriggerParent: TriggerParent
	StartTimer: StartTimer
	StopTimer: StopTimer
	CreateContext: CreateContext
