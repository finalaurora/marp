module.exports = gulp = require('gulp')

$           = do require('gulp-load-plugins')
config      = require('./package.json')
del         = require('del')
packager    = require('electron-packager')
runSequence = require('run-sequence')
Path        = require('path')
extend      = require('extend')

packageOpts =
  asar: true
  dir: 'dist'
  out: 'packages'
  name: config.name
  version: '0.36.7'
  prune: true
  overwrite: true
  'app-bundle-id': 'jp.yhatt.mdslide'
  'app-version': config.version

packageElectron = (opts = {}, done) ->
  packager extend(packageOpts, opts), (err) ->
    throw err if err
    done() if done?

globFolders = (pattern, func, callback) ->
  doneTasks = 0
  g = new (require("glob").Glob) pattern, (err, pathes) ->
    return console.log(err) if err
    done = ->
      doneTasks++
      callback() if callback? and doneTasks >= pathes.length

    func(path, done) for path in pathes

gulp.task 'clean', ['clean:js', 'clean:css', 'clean:dist', 'clean:packages']
gulp.task 'clean:js', -> del ['js/**/*', 'js']
gulp.task 'clean:css', -> del ['css/**/*', 'css']
gulp.task 'clean:dist', -> del ['dist/**/*', 'dist']
gulp.task 'clean:packages', -> del ['packages/**/*', 'packages']
gulp.task 'clean:releases', -> del ['releases/**/*', 'releases']

gulp.task 'compile', ['compile:coffee', 'compile:sass']
gulp.task 'compile:production', ['compile:coffee:production', 'compile:sass:production']

gulp.task 'compile:coffee', ->
  gulp.src 'coffee/**/*.coffee'
    .pipe $.plumber()
    .pipe $.sourcemaps.init()
    .pipe $.coffee
      bare: true
    .pipe $.uglify()
    .pipe $.sourcemaps.write()
    .pipe gulp.dest('js')

gulp.task 'compile:sass', ->
  gulp.src ['sass/**/*.scss', 'sass/**/*.sass']
    .pipe $.plumber()
    .pipe $.sourcemaps.init()
    .pipe $.sass()
    .pipe $.sourcemaps.write()
    .pipe gulp.dest('css')

gulp.task 'compile:coffee:production', ['clean:js'], ->
  gulp.src 'coffee/**/*.coffee'
    .pipe $.coffee
      bare: true
    .pipe $.uglify()
    .pipe gulp.dest('js')

gulp.task 'compile:sass:production', ['clean:css'], ->
  gulp.src ['sass/**/*.scss', 'sass/**/*.sass']
    .pipe $.sass()
    .pipe $.cssnano()
    .pipe gulp.dest('css')

gulp.task 'dist', ['clean:dist'], ->
  gulp.src ['js/**/*', 'css/**/*', '*.js', '!gulpfile.js', '*.html', 'package.json'], { base: '.' }
    .pipe gulp.dest('dist')
    .pipe $.install
      production: true

gulp.task 'package', ['clean:packages', 'dist'], (done) ->
  runSequence 'package:win32', 'package:darwin', 'package:linux', done

gulp.task 'package:win32',  (done) -> packageElectron { platform: 'win32', arch: 'ia32,x64' }, done
gulp.task 'package:linux',  (done) -> packageElectron { platform: 'linux', arch: 'ia32,x64' }, done
gulp.task 'package:darwin', (done) -> packageElectron { platform: 'darwin', arch: 'x64' }, done

gulp.task 'build',        (done) -> runSequence 'compile:production', 'package', done
gulp.task 'build:win32',  (done) -> runSequence 'compile:production', 'package:win32', done
gulp.task 'build:linux',  (done) -> runSequence 'compile:production', 'package:linux', done
gulp.task 'build:darwin', (done) -> runSequence 'compile:production', 'package:darwin', done

gulp.task 'archive', ['archive:win32', 'archive:darwin', 'archive:linux']

gulp.task 'archive:win32', (done) ->
  globFolders 'packages/*-win32-*', (path, globDone) ->
    gulp.src ["#{path}/**/*"]
      .pipe $.zip("#{config.version}-#{Path.basename(path, '.*')}.zip")
      .pipe gulp.dest('releases')
      .on 'end', globDone
  , done

gulp.task 'archive:darwin', (done) ->
  # TODO: setting gulp-appdmg
  done()

gulp.task 'archive:linux', (done) ->
  globFolders 'packages/*-linux-*', (path, globDone) ->
    gulp.src ["#{path}/**/*"]
      .pipe $.tar("#{config.version}-#{Path.basename(path, '.*')}.tar")
      .pipe $.gzip()
      .pipe gulp.dest('releases')
      .on 'end', globDone
  , done

gulp.task 'release', (done) -> runSequence 'build', 'archive', 'clean', done

gulp.task 'run', ['compile'], ->
  gulp.src '.'
    .pipe $.runElectron()
