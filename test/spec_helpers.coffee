Q = require 'q'
utils = require '../lib/utils'
StateBox = require '../lib/statebox'

class TestAction extends StateBox.Action.SimpleAction
	constructor: ->
		super( 'test', [], false )

class TestActionRunner
	constructor: (@res = {})->

	invoke: ->
		Q.resolve @res

module.exports =
	waitForTriggers: (storage, fs, done)->
		lock = Q.defer()
		q = utils.reduce fs, (f)=>
			lock.promise.then (memo)->
				lock = Q.defer()
				f( memo.ctx, memo.name )

		q.then ->
			done()
		, (r)->
			done( r )

		processed = (ctx, triggerName)=>
			lock.resolve( { ctx: ctx, name: triggerName } )

		storage.on 'processedTrigger', processed

	sendTriggers: (mgr, graphId, ctxId, triggers)->
		utils.reduce triggers, (trigger)->
			mgr.addTrigger( graphId, ctxId, trigger[ 0 ], trigger[ 1 ] )

	TestAction: TestAction

	TestActionRunner: TestActionRunner

	actions:
		test: new TestActionRunner()
		s1: new TestActionRunner()
		s2: new TestActionRunner()
		s3: new TestActionRunner()
		s4: new TestActionRunner()
		a1: new TestActionRunner()
		a2: new TestActionRunner()
