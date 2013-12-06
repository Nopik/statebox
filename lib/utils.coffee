Q = require 'q'
_ = require 'underscore'

class Utils
	@reduce: (array, iter, memo = {})->
	  q_iter = (q, entity)=>
	    q.then (memo)=>
	      iter( entity, memo )
	  _.reduce array, q_iter, Q.resolve( memo )

module.exports = Utils
