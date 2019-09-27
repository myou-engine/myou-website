console.log ''
fs = require 'fs-extra'
path = require 'path'
process = require 'process'
glob = require 'glob'
{spawnSync} = require 'child_process'
require 'shelljs/global'

working_dir = process.cwd()

print_usage = ->
    console.log '''

        TODO: help text.

    '''

# Reading arguments of the command
for option in process.argv when ('=' in option) or option.startsWith '-'
    [type, value] = option.split '='
    switch type
        when 'env'
            env = value
        when 'config'
            config_file = (value.replace /\\/g, '/')
        when '--cards'
            prerender_cards = true
        when '-c'
            prerender_cards = true
        when '--applets'
            compile_applets = true
        when '-a'
            compile_applets = true
        when '--help'
            print_usage()
            exit()
        when '-h'
            print_usage()
            exit()
        when '--watch'
            webpack_watch = true
        when '-w'
            webpack_watch = true
        when '--compress'
            compress = true
        when '-c'
            compress = true
        else
            # node debugger options
            if option not in ['--inspect', '--debug-brk']
                console.log 'unknown option:', option
                should_print_usage_and_exit = true

if not prerender_cards and not compile_applets
    prerender_cards = true
    compile_applets = true

if not config_file
    console.log 'No config.js file specified, using ./config.js'
    config_file = './config.js'

if not fs.existsSync config_file
    console.log 'ERROR: Config file does not exists:', config_file
    should_print_usage_and_exit = true

if should_print_usage_and_exit
    print_usage()
    exit()

config = require(path.join working_dir, config_file)(env)

tmp_dir = path.join config.output, '.tmp'
mkdir '-p', tmp_dir #it will also create config.output dir

category_colors = JSON.stringify(config.category_colors or {})
rel_logo = path.relative  path.join(__dirname, 'src/content'), config.logo

logo = "require '#{rel_logo.replace /\\/g, '/'}'"
theme = """
module.exports =
    category_colors: #{category_colors}
    logo: #{logo}
"""
console.log theme
fs.writeFileSync path.join(__dirname, 'src/content', 'custom_theme.coffee'), theme

if prerender_cards
    require('./tools/prerender_cards.coffee') {
        input_dir: config.cards
        output_dir: tmp_dir
        working_dir
        title: config.title
        description: config.description
    }
    for i in ls tmp_dir
        old_path = path.join config.output, i
        if fs.existsSync old_path
            rm '-r', old_path
    mv path.join(tmp_dir, '*'), config.output
rm '-r', config.output + '.tmp'

add_indent = (string, indent=0)->
    string.replace /\n/g, "\n#{'    '.repeat(indent)}"

output_data_path = path.join(config.output, 'data')
rm output_data_path
rm '-r', output_data_path
ln '-s', path.join(working_dir, config.data), output_data_path

if compile_applets
    build_src = path.join config.output, 'src'
    mkdir '-p', build_src
    applets_index =
    '''
        module.exports = (applet_id) ->
            console.log 'Downloading applet:', applet_id
            switch applet_id
    '''
    single_modules = ''

    for i in ls(config.applets)
        p = path.resolve path.join config.applets, i
        is_dir = test('-d', p)
        if is_dir and i not in ['common','assets']
            p = path.join p, 'main'
            p = p.replace /\\/g, '/'

            single_modules += "require '#{p}'\n"

            applets_index += add_indent """
            \nwhen '#{i}'
                (applet)-> require.ensure ['#{p}'], ->
                    require('#{p}') applet
            """,2

    applets_index += add_indent '''
        \nelse
            console.error "Applet not found: #{applet_id}"
        ''',2

    fs.writeFileSync path.join(__dirname, 'src/content', 'applets_index.coffee'), applets_index
    fs.writeFileSync path.join(__dirname, 'src/', 'single_modules.coffee'), single_modules

    wpc_template = path.join __dirname, 'webpack.config.template.js'
    wpc_path = path.join __dirname, 'webpack.config.js'

    wpc = fs.readFileSync(wpc_template, 'utf8').toString()

    rel_build_src = path.relative __dirname, build_src
    wpc = wpc.replace /#BUILD_DIR/g, rel_build_src.replace /\\/g, '/'
    fs.writeFileSync wpc_path, wpc

    cd __dirname
    spawnSync 'node', [path.join(__dirname, '/node_modules/webpack/bin/webpack.js'), if webpack_watch then '-w' else "--env.release"], {stdio: 'inherit', shell: true}

    compressible_files = [
        'js', 'html', 'css', 'svg',
        'woff', 'mesh', 'json',
    ]
    recursive_gz = (path)->
        for i in ls path
            full_path = path + '/' + i
            if test '-d', full_path # if is path
                recursive_gz full_path
            else
                extension = full_path.split('.').pop()
                if extension in compressible_files
                    exec 'gzip -vfk ' + full_path

    if compress
        abs_output = path.join working_dir, config.output
        recursive_gz(abs_output)
