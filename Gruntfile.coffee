module.exports = (grunt)->

	grunt.initConfig
		mochacli:
			options:
				reporter: 'spec'
				compilers: [ 'coffee:coffee-script' ]

			all: [ 'test/**/*.coffee' ]

		watch:
			test:
				files: [ 'lib/**/*.coffee', 'test/**/*.coffee' ]
				tasks: [ 'mochacli' ]

	grunt.loadNpmTasks 'grunt-contrib-watch'
	grunt.loadNpmTasks 'grunt-mocha-cli'

	grunt.registerTask 'test', [ 'mochacli:all' ]
