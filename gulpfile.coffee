_ = require "lodash"
{join} = require "path"
fs = require "fs-extra"
{execSync} = require "child_process"
https = require "https"

ip = require "ip"
gulp = require "gulp"
gutil = require "gulp-util"
debug = require "gulp-debug"
runSequence = require "run-sequence"

environments = require "gulp-environments"
git = require "gulp-git"
gulpnunjucks = require "gulp-nunjucks-html"
nunjucksDate = require "nunjucks-date"
livereload = require "gulp-livereload"
sass = require "gulp-sass"
changed = require "gulp-changed"
watch = require "gulp-watch"
webpack = require "webpack-stream"
plumber = require "gulp-plumber"
merge = require "merge-stream"
gulpif = require "gulp-if"
minifycss = require "gulp-minify-css"
htmlmin = require "gulp-htmlmin"
sourcemaps = require "gulp-sourcemaps"
emptytask = require "gulp-empty"
data = require "gulp-data"
newy = require "./vendor/newy"
del = require "del"
imagemin = require "imagemin-pngquant"
md5 = require "gulp-md5-assets"
purify = require "gulp-purifycss"
postcss = require "gulp-postcss"
reporter = require "postcss-reporter"
autoprefixer = require "autoprefixer"
stylelint = require "gulp-stylelint"
lr = require "connect-livereload"
st = require "st"
portfinder = require "portfinder"
express = require "express"

markdown = require "nunjucks-markdown"
marked = require "marked"
Highlights = require "highlights"
imagemin = require "imagemin-pngquant"
named = require "vinyl-named"


# Path configurations

workingPath = process.cwd()
# workingSession = Math.floor(Date.now() / 1000)
variables = require(join(workingPath, '.gulp/.variables'));

paths =
	build: 			".build"
	templates: 		"templates"
	pages: 			"pages"
	static: 		"assets/static"
	scss: 			"assets/css"
	javascript: 	"assets/scripts"
	root:			"root"

projectPath = 	(path="", fileTypes="") -> join(workingPath, path, fileTypes)
buildPath = 	(path="", fileTypes="") -> join(workingPath, paths.build, path, fileTypes)

isDirectory = (path) ->
	try
		return fs.lstatSync(path).isDirectory()
	catch e
		return false

filesInDir = (path, ext) ->
	return [] unless fs.existsSync(path)
	fs.readdirSync(path).filter (fileName) ->
		_.endsWith(fileName, ext)

# Configuration

try
	config = require(join(process.cwd(), "config"))
	config = config[_.first(_.keys(config))]
catch e
	config = {}

# Environments

staging = environments.make("staging");
production_live = environments.make("production_live");
development = environments.development;
production = environments.production;

environment = variables[environments.current()["$name"]]
environment.name = environments.current()["$name"]

highlighter = new Highlights()

marked.setOptions
	highlight: (code, language) ->
		return highlighter.highlightSync
			fileContents: code
			scopeName: language

nunjucksDate.setDefaultFormat("MMMM Do YYYY, h:mm:ss a")

nunjucks = {}
nunjucksPipe = -> gulpnunjucks
	searchPaths: projectPath(paths.templates)
	locals: { 
		environment: environment,
		staging: staging(), 
		development: development(), 
		production: production() || production_live()
		}
	setUp: (env) ->
		markdown.register(env, marked)
		nunjucksDate.install(env)
		nunjucks.env = env
		return env

# Webpack

webpackConfig =
	module:
		loaders: [{test: /\.coffee$/, loader: "coffee-loader"}]
	resolve: extensions: ["", ".js"]
	resolveLoader: {root: join(__dirname, "node_modules")}
	output:
		filename: "[name].js"
	cache: true
	quiet: true
	watch: false
	devtool: "sourcemap"

webpackConfigPlugins = [
	new webpack.webpack.optimize.DedupePlugin(),
	new webpack.webpack.optimize.UglifyJsPlugin()
]

webpackConfigJavaScript = _.cloneDeep(webpackConfig)
webpackConfigJavaScript.output.filename = "[name].js"
webpackConfigJavaScript.plugins = webpackConfigPlugins

# Imagemin

imageminOptions =
	quality: process.env.MOONBASE_IMAGEMIN_QUALITY or "65-80"
	speed: process.env.MOONBASE_IMAGEMIN_SPEED or 4

# Utilities

getTotalSizeForFileType = (path, ext) ->
	try
		return execSync("find '#{path}' -type f -name '*.#{ext}' -exec du -ch {} + | grep total")
			.toString().replace(/^\s+|\s+$/g, "").split(/\s/)[0]
	catch
		return "0"
# Context

context =
	nunjucks: nunjucks

# Gulp Tasks

gulp.task "static", ->
	console.log("Running Static Task..")
	return gulp.src(projectPath(paths.static, "**/*.*"))
		.pipe(changed(buildPath(paths.static)))
		.pipe(debug())
		.pipe(gulp.dest(buildPath(paths.static)))
		.pipe(livereload())

gulp.task "root", ->
	console.log("Running Root Task..")
	return gulp.src(projectPath(paths.root, "**/*.*"))
		.pipe(changed(buildPath()))
		.pipe(debug())
		.pipe(gulp.dest(buildPath()))
		.pipe(livereload())

gulp.task "pages", ->
	console.log("Running Pages Task..")
	config.before?(context)
	return gulp.src(projectPath(paths.pages, "**/*"))
		.pipe(plumber())
		.pipe(data((file) -> config.page?(file.path.replace(projectPath(paths.pages), ""), file, context)))
		.pipe(nunjucksPipe())
		.pipe(debug())
		.pipe(gulp.dest(buildPath()))
		.pipe(livereload())

gulp.task "stylelint", ->

	# Check if there's a stylelint configuration
	settings = JSON.parse(fs.readFileSync('./package.json'))
	if settings.stylelint or fs.existsSync(projectPath("", ".stylelintrc"))
		gulp.src(projectPath(paths.scss, "**/*.scss"))
			.pipe(plumber())
			.pipe(stylelint({
				reporters: [
					{formatter: 'string', console: true}
				]
		}))

gulp.task "scss", ->
	processors = []

	if config.style?.autoprefixer?
		processors.push(autoprefixer({ browsers: [config.style.autoprefixer] }))

	gulp.src(projectPath(paths.scss, "*.scss"))
		.pipe(plumber())
		.pipe(sourcemaps.init())
		.pipe(sass().on("error", sass.logError))
		.pipe(postcss(processors))
		.pipe(sourcemaps.write("."))
		.pipe(debug())
		.pipe(gulp.dest(buildPath(paths.scss)))
		.pipe(livereload())

gulp.task "minifycss", ["scss"], ->
	gulp.src(buildPath(paths.scss, "*.css"))
		.pipe(plumber())
		.pipe(minifycss())
		.pipe(debug())
		.pipe(gulp.dest(buildPath(paths.scss)))
		
gulp.task "configfile", ->

	get_branch_name = (callback) ->
		git.revParse({args:'--abbrev-ref HEAD'}, callback)

	callback = (error, branch_name) ->
		environment.branch = branch_name
		console.log('//////// BRANCH NAME SET TO: ' + branch_name + ' WRITING /environment.json CONFIG FILE! ////////////////')
		fs.writeFileSync(paths.javascript + "/environment.json", JSON.stringify(environment), 'utf8')
		gulp.src(projectPath(paths.javascript, "*.json"))
			.pipe(plumber())
			.pipe(named())
			.pipe(debug())
			.pipe(gulp.dest(buildPath(paths.javascript)))
			.pipe(livereload())

	get_branch_name(callback)

gulp.task "javascript", ->

	return emptytask unless filesInDir(
		projectPath(paths.javascript), ".js").length

	gulp.src(projectPath(paths.javascript, "*.js"))
		.pipe(plumber())
		.pipe(named())
		.pipe(webpack(webpackConfigJavaScript))
		.pipe(debug())
		.pipe(gulp.dest(buildPath(paths.javascript)))
		.pipe(livereload())

gulp.task "imagemin", ->
	return gulp.src(projectPath(paths.static, "**/*.png"))
		.pipe(plumber())
		.pipe(imagemin(imageminOptions)())
		.pipe(gulp.dest(projectPath(paths.static)))

gulp.task "handleassets", (cb) ->
	console.log("Handling Assets for in folder:")
	console.log(buildPath())
	console.log("Running Runsequence...")
	runSequence("minifycss", "md5js", "md5svg", "md5png", "md5css", "md5ico", "minifyHtml", cb)

gulp.task "minifyHtml", -> 
	console.log("Minifying Html...")
	return gulp.src(buildPath("", "**/*.html"))
		.pipe(htmlmin({collapseWhitespace: true, removeComments: true}))
		.pipe(debug())
		.pipe(gulp.dest(buildPath("")))

gulp.task "md5ico", ->
	console.log("Hashing ICO...")
	return gulp.src(buildPath("", "**/*/*.ico"))
		.pipe(md5(20, buildPath("", "**/*.html")))
		.pipe(debug())
		.pipe(gulp.dest(buildPath("")))

gulp.task "md5css", ->
	console.log("Hashing CSS...")
	return gulp.src(buildPath("", "**/*/*.css"))
		.pipe(md5(20, buildPath("", "**/*.html")))
		.pipe(debug())
		.pipe(gulp.dest(buildPath("")))

gulp.task "md5png", ->
	console.log("Hashing PNG...")
	return gulp.src(buildPath("", "**/*/*.png"))
		.pipe(md5(20, buildPath("", "**/*.html")))
		.pipe(debug())
		.pipe(gulp.dest(buildPath("")))

gulp.task "md5svg", ->
	console.log("Hashing SVG...")
	return gulp.src(buildPath("", "**/*/*.svg"))
		.pipe(md5(20, buildPath("", "**/*.html")))
		.pipe(debug())
		.pipe(gulp.dest(buildPath("")))

gulp.task "md5js", ->
	console.log("Hashing JS...")
	return gulp.src(buildPath("", "**/*/*.js"))
		.pipe(md5(20, buildPath("", "**/*.html")))
		.pipe(debug())
		.pipe(gulp.dest(buildPath("")))

gulp.task "watch", ["build_unminified"], (cb) ->

	options = {debounceDelay: 100}

	watch [
		projectPath(paths.pages, "**/*.html"),
		projectPath(paths.pages, "**/*.md"),
		projectPath(paths.templates, "**/*.html"),
		projectPath(paths.templates, "**/*.md")
	], options, (err, events) -> 
		gulp.start("pages")

	watch [projectPath(paths.static, "**/*.*")], options, (err, events) ->
		gulp.start("static")
	watch [projectPath(paths.scss, "**/*.scss")], options, (err, events) ->
		console.log('running task scss')
		gulp.start("scss")

		run = () ->
			gulp.start("pages")
		setTimeout(run, 1000)
		
	watch [projectPath(paths.javascript, "**/*.js")], options, (err, events) ->
		gulp.start("javascript")

	gulp.start("server", cb)

gulp.task "server", (cb) ->

	portfinder.getPort (err, serverPort)  ->
		portfinder.basePort = 10000
		portfinder.getPort (err, livereloadPort)  ->

			sslKey = "#{__dirname}/ssl/key.pem"
			sslCert = "#{__dirname}/ssl/cert.pem"

			app = express()


			app.use(lr(port:livereloadPort))
			app.use(express.static(buildPath()))

			### Project Specific Development Server Logic Start ###
			app.get('/items/*', (req, res) ->
				res.redirect("/items?uuid=" + req.url.split("/items/")[1]);
			)
			### Project Specific Development Server Logic End ###

			app.get('/*', (req, res) -> 
				if 	req.url.indexOf('.') == -1?
					res.sendFile buildPath() + '/' + req.originalUrl.slice(1) + '.html'
			)

			https.createServer({
				key: fs.readFileSync(sslKey),
				cert: fs.readFileSync(sslCert)
			}, app).listen(serverPort)

			livereload.listen({
				port: livereloadPort,
				basePath: buildPath(),
				key: fs.readFileSync(sslKey),
				cert: fs.readFileSync(sslCert)
			})

			gutil.log(gutil.colors.green("Serving at: https://#{ip.address()}:#{serverPort}"))
			gutil.log(gutil.colors.green("From path:  #{buildPath()}"))

			cb(err)

gulp.task "report", ["stylelint"], ->

	# Report on sizes for each file type
	for ext in ["html", "css", "jpg", "png", "mp4"]
		path = getTotalSizeForFileType(buildPath(paths.assets), ext)
		gutil.log(gutil.colors.green("#{ext} #{path}"))

	# Check all html and js files to see if there's any unused CSS
	commonResetClasses = [
		"applet", "blockquote", "abbr", "acronym", "cite", "del", "dfn", "kbd", "samp", "strike", "sup", "tt", "dt", "fieldset", "legend", "caption", "tfoot", "thead", "th", "figcaption", "hgroup", "mark", "blockquote", "blockquote:after", "blockquote:before", "textarea:focus", "ins"
	]

	gutil.log(gutil.colors.green("Unused CSS"))
	return gulp.src(buildPath(paths.scss, "style.css"))
		.pipe(purify(
			[buildPath("", "**/*.html"), buildPath("", "**/*.js")],
			{rejected: true, whitelist: commonResetClasses}
		))

gulp.task "clean", ->
	return del([buildPath()])

gulp.task "build", (cb) ->
	runSequence("pages", "static", "root", "javascript", "handleassets", "configfile", cb)

gulp.task "build_test", (cb) ->
	runSequence("pages", "static", "root", "handleassets", cb)

gulp.task "build_unminified", (cb) ->
	runSequence("pages", "static", "root", "javascript", "scss", "configfile", cb)

gulp.task("default", ["server"])
