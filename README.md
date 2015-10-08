### Cactus with Gulp

This is a reimplementation of Cactus' ideas with [Gulp](http://gulpjs.com). No fancy app, just a command line tool. The main goal for this was speed, as larger Cactus projects became slow to work on. Other goals are portability so everyone can start building right away. Next to that, the added benefits are minified and compiled Java/Coffee Script, the posibilities to run tests, etc.

#### Quick Start

- `git clone https://github.com/motif/MoonbaseTemplate.git website.com` clone the template
- `cd website` 
- `make`

#### Features

- Built in server with automatic reloading on changes, based on [Express](http://expressjs.com) and [Live Reload](https://github.com/napcs/node-livereload)
- Template engine (like Django, with extend) based on [Nunjucks](https://mozilla.github.io/nunjucks/) – [Docs](https://mozilla.github.io/nunjucks/templating.html)
- Markdown support (with `{% markdown %}`) based on [Marked](https://github.com/chjj/marked)
- Code highlighting in Markdown, based on [Highlights](https://github.com/atom/highlights)
- Support for SCSS and includes, including minification sourcemaps.
- Support for Java/Coffee Script (with minification and sourcemaps), based on [Webpack](https://webpack.github.io)
- Support for image sprites [TODO]
- Support for image optimizations [TODO]


#### Project layout

```
Makefile		Shorthands for commands to quickly build or install.
config.coffee	Configuration variables like page context function
pages			The html pages including site structure.
templates		The templates used in the html pages (for extend and include).
assets
	static		Just static files like images, fonts and downloads.
	css			CSS and SCSS files and dependents. The top level files get compiled.
	scripts		Java/Coffee Script files and dependents. The top level files get compiled and minified.
.build			Path for the generated site (hidden by default).
```

#### Generated site layout

So you can find this structure in `.build` after a make build command.

```

/index.html							from: /pages/index.html				Rendered template
/about/index.html					from: /pages/about/index.html		Rendered template
/assets/static/img/image.jpg		from: /static/img/image.jpg			Simple copy
/assets/css/style.css				from: /css/style.scss				SCSS compiled and minified
/assets/scripts/main.coffee.js		from: /scripts/main.coffee			Coffee compiled and minified
/assets/scripts/main.coffee.js.map	from: /scripts/main.coffee			Coffee sourcemap
/assets/scripts/tracker.js			from: /scripts/tracker.js			JavaScript minified
```

#### Todo

- Better error reporting
- Some form of deploying with rsync, s3
- Port blog plugin
- Tests
- Build command into separate directory
- Maybe move /subdir/subdir.index.html to /subdir/index.html