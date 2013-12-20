Values = require './values'
_ = require 'underscore'
utils = require './utils'
Q = require 'q'

class AssignmentExp
	constructor: (@left, @op, @right)->

	evaluate: (ctx, trigger)->
		l = @left.evaluateRef( ctx, trigger )
		r = @right.evaluate( ctx, trigger )

		l.then (left)=>
			r.then (right)=>
				switch @op
					when '='
						left.set right
					when '*='
						left.set left.get() * right
					when '/='
						left.set left.get() / right
					when '%='
						left.set left.get() % right
					when '+='
						left.set left.get() + right
					when '-='
						left.set left.get() - right
					when '<<='
						left.set left.get() << right
					when '>>='
						left.set left.get() >> right
					when '&='
						left.set left.get() & right
					when '^='
						left.set left.get() ^ right
					when '|='
						left.set left.get() | right
					else
						throw new Error "Unknown assignment operator: #{@op}"

	evaluateRef: (ctx, trigger)->
		Q.reject new Error "Cannot evaluate reference to assignment expression"

class OpExp
	constructor: (@left, @op, @right)->

	evaluate: (ctx, trigger)->
		l = @left.evaluate( ctx, trigger )
		r = @right.evaluate( ctx, trigger )

		l.then (left)=>
			r.then (right)=>
				switch @op
					when '*'
						left * right
					when '/'
						left / right
					when '%'
						left % right
					when '+'
						left + right
					when '-'
						left - right
					when '<<'
						left << right
					when '>>'
						left >> right
					when '<'
						left < right
					when '<='
						left <= right
					when '>'
						left > right
					when '>='
						left >= right
					when '=='
						a = left
						b = right
						`a == b`
					when '!='
						a = left
						b = right
						`a != b`
					when '==='
						left == right
					when '!=='
						left != right
					when '&'
						left & right
					when '^'
						left ^ right
					when '|'
						left | right
					when '&&'
						left && right
					when '||'
						left || right
					else
						Q.reject Error "Unknown operator: #{@op}"

	evaluateRef: (ctx, trigger)->
		Q.reject new Error "Unable to calculate ref on expression"

class UnaryOpExp
	constructor: (@op, @right)->

	evaluate: (ctx, trigger)->
		r = @right.evaluate( ctx, trigger )

		r.then (right)=>
			switch @op
				when '+'
					+ right
				when '-'
					- right
				when '~'
					~ right
				when '!'
					! right
				else
					Q.reject new Error "Unknown unary operator: #{@op}"

	evaluateRef: (ctx, trigger)->
		Q.reject new Error "Cannot evaluate reference to unary expression"

class NumberLiteralExp
	constructor: (@number)->

	evaluate: (ctx, trigger)->
		Q.resolve parseFloat( @number )

	evaluateRef: (ctx, trigger)->
		Q.reject new Error "Cannot evaluate reference to number literal"

class StringLiteralExp
	constructor: (string)->
		@string = string[ 1 .. -2 ]

	evaluate: (ctx, trigger)->
		Q.resolve @string

	evaluateRef: (ctx, trigger)->
		Q.reject new Error "Cannot evaluate reference to string literal"

class ObjectLiteralExp
	constructor: (@props)->

	evaluate: (ctx, trigger)->
		res = {}

		q = utils.reduce @props, (prop)->
			name = prop[ 0 ][ 1 .. -2 ]
			prop[ 1 ].evaluate( ctx, trigger ).then (val)->
				res[ name ] = val

		q.then ->
			res

	evaluateRef: (ctx, trigger)->
		Q.reject new Error "Cannot evaluate reference to object literal"

class WordLiteralExp
	constructor: (@word)->
#		if (@word != 'ctx') && (@word != 'trigger')
#			throw new Error "Unknown object: #{@word}, use 'ctx' or 'trigger'"

	evaluate: (ctx, trigger)->
		switch @word
			when 'true'
				Q.resolve true
			when 'false'
				Q.resolve false
			else
				@evaluateRef( ctx, trigger ).then (ref)->
					ref.get()

	evaluateRef: (ctx, trigger)->
		switch @word
			when 'ctx'
				Q.resolve( new Values.Ref ctx.values, [] )
			when 'trigger'
				Q.resolve( new Values.Ref trigger, [] )
			else
				Q.resolve( new Values.Ref @word, [] )

class SubscriptExp
	constructor: (@base, @subscript)->

	evaluateRef: (ctx, trigger)->
		@base.evaluateRef( ctx, trigger ).then (base)=>
			@subscript.evaluate( ctx, trigger ).then (path)=>
				base.addPath path
				base

	evaluate: (ctx, trigger)->
		@evaluateRef( ctx, trigger ).then (ref)->
			ref.get()

functions =
	exist: (obj)->
		obj?

class CallExp
	constructor: (@base, @args)->

	evaluate: (ctx, trigger)->
		@base.evaluateRef( ctx, trigger ).then (base)=>
			args = []
			q = utils.reduce @args, (arg)->
				arg.evaluate( ctx, trigger ).then (a)->
					args.push a

			q.then =>
				f = functions[ base.base ]
				if (base.path.length == 0) && (f?)
					if f.length == @args.length
							f.apply f, args
					else
						Q.reject new Error "Invalid number of arguments for #{base.base}"
				else
					actionRunner = ctx.getActions()[ base.path[ 0 ] ]

					if (actionRunner?) && (base.path.length == 1) && (base.base == 'action') && (!f?)
						actionRunner.invoke ctx, args
					else
						Q.reject new Error "Unknown function #{base.base}"

	evaluateRef: (ctx, trigger)->
		Q.reject new Error "Unable to calculate ref on function result"

class PropExp
	constructor: (@base, @prop)->

	evaluateRef: (ctx, trigger)->
		@base.evaluateRef( ctx, trigger ).then (base)=>
			base.addPath @prop
			base

	evaluate: (ctx, trigger)->
		@evaluateRef( ctx, trigger ).then (ref)->
			ref.get()

module.exports =
	AssignmentExp: AssignmentExp
	OpExp: OpExp
	UnaryOpExp: UnaryOpExp
	NumberLiteralExp: NumberLiteralExp
	StringLiteralExp: StringLiteralExp
	WordLiteralExp: WordLiteralExp
	ObjectLiteralExp: ObjectLiteralExp
	SubscriptExp: SubscriptExp
	CallExp: CallExp
	PropExp: PropExp
