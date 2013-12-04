#This class is a stub, shows interface
class Storage
	constructor: ->

	connect: ->

	disconnect: ->

	getGraphs: ->

	destroyGraph: (graph_id)->

	saveGraph: (graph)->
		#should set graph.id

	saveContext: (ctx)->
		#should set ctx.id

	getContexts: (graph_id)->

	getContext: (graph_id, context_id)->

	destroyContext: (graph_id, context_id)->

module.exports = Storage
