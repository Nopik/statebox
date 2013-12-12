Values = require './values'
_ = require 'underscore'

class AssignmentExp
	constructor: (@left, @op, @right)->

	evaluate: (ctx, trigger)->
		left = @left.evaluateRef( ctx, trigger )
		right = @right.evaluate( ctx, trigger )

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
		throw new Error "Cannot evaluate reference to assignment expression"

class OpExp
	constructor: (@left, @op, @right)->

	evaluate: (ctx, trigger)->
		switch @op
			when '*'
				@left.evaluate( ctx, trigger ) * @right.evaluate( ctx, trigger )
			when '/'
				@left.evaluate( ctx, trigger ) / @right.evaluate( ctx, trigger )
			when '%'
				@left.evaluate( ctx, trigger ) % @right.evaluate( ctx, trigger )
			when '+'
				@left.evaluate( ctx, trigger ) + @right.evaluate( ctx, trigger )
			when '-'
				@left.evaluate( ctx, trigger ) - @right.evaluate( ctx, trigger )
			when '<<'
				@left.evaluate( ctx, trigger ) << @right.evaluate( ctx, trigger )
			when '>>'
				@left.evaluate( ctx, trigger ) >> @right.evaluate( ctx, trigger )
			when '<'
				@left.evaluate( ctx, trigger ) < @right.evaluate( ctx, trigger )
			when '<='
				@left.evaluate( ctx, trigger ) <= @right.evaluate( ctx, trigger )
			when '>'
				@left.evaluate( ctx, trigger ) > @right.evaluate( ctx, trigger )
			when '>='
				@left.evaluate( ctx, trigger ) >= @right.evaluate( ctx, trigger )
			when '=='
				a = @left.evaluate( ctx, trigger )
				b = @right.evaluate( ctx, trigger )
				`a == b`
			when '!='
				a = @left.evaluate( ctx, trigger )
				b = @right.evaluate( ctx, trigger )
				`a != b`
			when '==='
				@left.evaluate( ctx, trigger ) == @right.evaluate( ctx, trigger )
			when '!=='
				@left.evaluate( ctx, trigger ) != @right.evaluate( ctx, trigger )
			when '&'
				@left.evaluate( ctx, trigger ) & @right.evaluate( ctx, trigger )
			when '^'
				@left.evaluate( ctx, trigger ) ^ @right.evaluate( ctx, trigger )
			when '|'
				@left.evaluate( ctx, trigger ) | @right.evaluate( ctx, trigger )
			when '&&'
				@left.evaluate( ctx, trigger ) && @right.evaluate( ctx, trigger )
			when '||'
				@left.evaluate( ctx, trigger ) || @right.evaluate( ctx, trigger )
			else
				throw new Error "Unknown operator: #{@op}"

	evaluateRef: (ctx, trigger)->
		throw new Error "Unable to calculate ref on expression"

class UnaryOpExp
	constructor: (@op, @right)->

	evaluate: (ctx, trigger)->
		switch @op
			when '+'
				+ @right.evaluate( ctx, trigger )
			when '-'
				- @right.evaluate( ctx, trigger )
			when '~'
				~ @right.evaluate( ctx, trigger )
			when '!'
				! @right.evaluate( ctx, trigger )
			else
				throw new Error "Unknown unary operator: #{@op}"

	evaluateRef: (ctx, trigger)->
		throw new Error "Cannot evaluate reference to unary expression"

class NumberLiteralExp
	constructor: (@number)->

	evaluate: (ctx, trigger)->
		parseFloat( @number )

	evaluateRef: (ctx, trigger)->
		throw new Error "Cannot evaluate reference to number literal"

class StringLiteralExp
	constructor: (string)->
		@string = string[ 1 .. -2 ]

	evaluate: (ctx, trigger)->
		@string

	evaluateRef: (ctx, trigger)->
		throw new Error "Cannot evaluate reference to string literal"

class WordLiteralExp
	constructor: (@word)->
#		if (@word != 'ctx') && (@word != 'trigger')
#			throw new Error "Unknown object: #{@word}, use 'ctx' or 'trigger'"

	evaluate: (ctx, trigger)->
		switch @word
			when 'true'
				true
			when 'false'
				false
			else
				@evaluateRef( ctx, trigger ).get()

	evaluateRef: (ctx, trigger)->
		switch @word
			when 'ctx'
				new Values.Ref ctx.values, []
			when 'trigger'
				new Values.Ref trigger, []
			else
				new Values.Ref @word, []
#				throw new Error "Unknown object: #{@word}"

class SubscriptExp
	constructor: (@base, @subscript)->

	evaluateRef: (ctx, trigger)->
		base = @base.evaluateRef( ctx, trigger )

		base.addPath @subscript.evaluate( ctx, trigger )

		base

	evaluate: (ctx, trigger)->
		res = @evaluateRef( ctx, trigger ).get()
#		console.log res
		res

functions =
	exist: (obj)->
		obj?

class CallExp
	constructor: (@base, @args)->

	evaluate: (ctx, trigger)->
		base = @base.evaluateRef( ctx, trigger )

		f = functions[ base.base ]
		if (base.path.length == 0) && (f?)
			if f.length == @args.length
				args = _.map @args, (arg)-> arg.evaluate( ctx, trigger )

				f.apply f, args
			else
				throw new Error "Invalid number of arguments for #{base.base}"
		else
			throw new Error "Unknown function #{base.base}"

	evaluateRef: (ctx, trigger)->
		throw new Error "Unable to calculate ref on function result"

class PropExp
	constructor: (@base, @prop)->

	evaluateRef: (ctx, trigger)->
		base = @base.evaluateRef( ctx, trigger )

		base.addPath @prop

		base

	evaluate: (ctx, trigger)->
		@evaluateRef( ctx, trigger ).get()

module.exports =
	AssignmentExp: AssignmentExp
	OpExp: OpExp
	UnaryOpExp: UnaryOpExp
	NumberLiteralExp: NumberLiteralExp
	StringLiteralExp: StringLiteralExp
	WordLiteralExp: WordLiteralExp
	SubscriptExp: SubscriptExp
	CallExp: CallExp
	PropExp: PropExp
