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
			test:
				files: [ 'lib/**/*.coffee', 'test/**/*.coffee', 'src/**/*.coffe', 'src/**/*.js', '!src/graph.js', '!test/parser.coffee' ]
				tasks: [ 'mochacli' ]

			test_parser:
				files: [ 'src/graph.js', 'test/parser.coffee' ]
				tasks: [ 'mochacli:parser' ]

			jison:
				files: [ 'src/graph.jison' ]
				tasks: [ 'jison' ]

	grunt.loadNpmTasks 'grunt-contrib-watch'
	grunt.loadNpmTasks 'grunt-mocha-cli'
	grunt.loadNpmTasks 'grunt-jison'

	grunt.registerTask 'test', [ 'mochacli:all' ]
