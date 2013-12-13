module.exports = (grunt)->

	grunt.initConfig
		mochacli:
			options:
				reporter: 'spec'
				compilers: [ 'coffee:coffee-script' ]

			all: [ 'test/**/*.coffee' ]

			parser: [ 'test/parser.coffee' ]

		jison:
			target:
				files:
					'src/graph.js': 'src/graph.jison'

		watch:
			jison:
				options:
					atBegin: true
				files: [ 'src/graph.jison' ]
				tasks: [ 'jison' ]

			test:
				options:
					atBegin: true
				files: [ 'lib/**/*.coffee', 'test/**/*.coffee', 'src/**/*.coffe', 'src/**/*.js', '!src/graph.js', '!test/parser.coffee', '!src/parse_helpers.coffee' ]
				tasks: [ 'mochacli:all' ]

			test_parser:
				files: [ 'src/graph.js', 'test/parser.coffee', 'src/parse_helpers.coffee' ]
				tasks: [ 'mochacli:parser' ]

	grunt.loadNpmTasks 'grunt-contrib-watch'
	grunt.loadNpmTasks 'grunt-mocha-cli'
	grunt.loadNpmTasks 'grunt-jison'

	grunt.registerTask 'test', [ 'mochacli:all' ]
