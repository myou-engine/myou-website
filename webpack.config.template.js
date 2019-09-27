'use strict'
var webpack = require('webpack');
var path = require('path')
// TODO: Use official plugin as soon as 1.0 is out of beta
var UglifyJsPlugin = require('uglify-es-webpack-plugin');
// generating banner
var fs = require('fs');
var license = fs.readFileSync('./LICENSE', 'utf8').toString()

var config = {
    output: {
        path: __dirname + '/#BUILD_DIR',
        filename: '[name].js',
        publicPath: '/src/',
    },
    context: __dirname,
    entry: {
        site: __dirname + '/src/init.coffee',
        single_modules: __dirname + '/src/single_modules.coffee',
    },
    stats: {
        colors: true,
        reasons: true
    },
    module: {
        rules: [
            {
                test: /\.coffee$/,
                use: {
                    loader: 'coffee-loader',
                },
            },
            {
                test: /\.(png|jpe?g|gif)$/i,
                loader: 'url-loader?limit=18000&name=[path][name].[ext]',
            },
            {test: /\.svg$/, loader: 'url-loader?mimetype=image/svg+xml'},
            {test: /\.json$/, loader: 'json-loader'},
            {test: /\.woff2?$/, loader: 'url-loader?mimetype=application/font-woff'},
            {test: /\.eot$/, loader: 'url-loader?mimetype=application/font-woff'},
            {test: /\.ttf$/, loader: 'url-loader?mimetype=application/font-woff'},
            {test: /\.styl$/, loader: 'raw-loader!stylus-loader'},
            {test: /\.css$/, loader: 'raw-loader'},
        ]
    },
    plugins: [
        new webpack.BannerPlugin({banner:license, raw:false}),
        new webpack.IgnorePlugin(/^(fs|stylus|path|coffeescript)$/),
        new webpack.optimize.CommonsChunkPlugin({
            chunks: ['site', 'single_modules'],
            async: true,
        }),
        new webpack.DefinePlugin({
            'process.env': {
                'NODE_ENV': '"production"'
            },
        }),
    ],
    resolve: {
        extensions: [".webpack.js", ".web.js", ".js", ".coffee", ".json"],
        alias: {
            // You can use this to override some packages and use local versions
            'myoui': path.resolve(__dirname+'/../myoui'),
            'myou-applet': path.resolve(__dirname+'/../myou-applet'),
        },
    },
    node: false,
}

module.exports = (env) => {
    if(env && (env.release)){
        console.log('RELEASE')
        config.plugins.push(new UglifyJsPlugin({
            //minimize: true,
            mangle: true,
            compress: {
        		sequences: true,
        		dead_code: true,
        		conditionals: true,
        		booleans: true,
        		unused: true,
        		if_return: true,
        		join_vars: true,
        		drop_console: true
            }
        }))
        config.module.rules[0].use.options = {
            transpile: {
                presets: ['env'],
            },
        }
        if(env.sourcemaps){
            config.devtool = 'cheap-module-eval-source-map';
        }
    }else{
        console.log('DEBUG')
        config.devtool = 'cheap-module-eval-source-map';
    }
    return config
}
