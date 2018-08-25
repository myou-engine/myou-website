# To be used on the post-receive hook
require 'shelljs/global'
path = process.argv[2...process.argv.length][0]

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

recursive_gz path
