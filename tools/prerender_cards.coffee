fs = require 'fs-extra'
path = require 'path'
process = require 'process'
glob = require 'glob'
require 'shelljs/global'

module.exports = (input_dir, output_dir, working_dir)->
    if output_dir.startsWith '.'
        output_dir = path.join(working_dir, output_dir).replace /\\/g, '/'

    if input_dir.startsWith '.'
        input_dir = path.join(working_dir, input_dir).replace /\\/g, '/'

    console.log input_dir, output_dir

    # Creating output_dir if necessary
    if fs.existsSync output_dir #output_dir found
        console.log 'Clearing output dir: ', output_dir
        fs.emptyDirSync output_dir

    assets_dir = path.join(__dirname, '../assets').replace /\\/g, '/'

    output_assets_dir = path.join(output_dir,).replace /\\/g, '/'
    output_webpack_build_dir = path.join(output_dir, 'src').replace /\\/g, '/'

    root_dir = path.join(__dirname, '../').replace /\\/g, '/'


    mkdir '-p', output_dir

    # it will generate an object from some parameters
    card = (type, id, children...)->
        attributes = {}
        if children[0]? and not children[0].is_element
            attributes = children.shift()
        return {type, id, attributes, children, is_element: true}

    # it will bind the type of the card to the card function
    cards = {}
    for type in ['index', 'category', 'article', 'spotlight', 'feature', 'link']
        cards[type] = card.bind null, type

    # getting file extension
    extension_re = new RegExp /\.[0-9a-z]+$/i
    get_filename_and_extension = (file)->
        extension = extension_re.exec(file)[0][1...]
        filename = file[0...file.length - extension.length - 1]
        return {extension, filename}

    # read date from article metadata and write it if it is not assigned.
    article_date = (filepath)->
        # Reading file to obtain date
        text = fs.readFileSync(filepath, 'utf8').toString()
        time = null
        if text.indexOf("Date:\n") != -1
            # Adding date based on file modification date.
            date = new Date ls('-l', filepath)[0].mtime
            strdate = date.toGMTString()
            text = text.replace "Date:\n", "Date: #{strdate}\n"
            fs.writeFileSync filepath, text
        else
            # Extracting date from article metadata.
            strdate = /Date:(.*)\n/.exec(text)[1]

        date = new Date strdate
        return date.getTime()

    # it will generate a index from a file tree
    get_file_tree = (path)->
        items = []
        for i in ls path
            ipath = path + '/' + i
            is_dir = test '-d', ipath

            item = {}
            if not is_dir
                {filename, extension} = get_filename_and_extension(i)
                extension = extension.toLowerCase()
                if filename == 'README' or extension != 'md'
                    continue
                item.id = filename
                text = fs.readFileSync(ipath, 'utf8').toString()
                type_match = /Type:(.*)\n/.exec(text)

                # JulioManuel Lopez --> julio_manuel_lopez
                item.type = if type_match
                    type_match[1].replace(/([A-Z])/g,'_$1')
                    .replace(/^_|\s*/g,'').toLowerCase()

                else 'article'

                item.date = article_date ipath

                #finding children
                children_path = path + '/' + filename
                if test '-d', children_path
                    item.children = get_file_tree children_path

            else if not glob.sync(ipath+'/**/*.md').length > 0
                # Empty of markdown files
                continue
            else if not fs.existsSync ipath + '.md'
                item.id = i
                item.type = 'category'
                item.children = get_file_tree path + '/' + i
            else
                continue
            items.push item

        #sorted by date from new to old
        items.sort (a,b)-> b.date - a.date
        return items

    # Creating index_file if it doesn't exist
    index_file = path.resolve path.join(input_dir, 'index.coffee').replace /\\/g, '/'

    if ls(index_file).code == 2
        index = {id:'index', type:'index', children:[]}
    else
        index = require(index_file) cards

    # index from file tree
    index_from_file_tree =  {id: 'index', type: 'index', children: get_file_tree input_dir}

    # updating index with the new items of index from file tree
    update_item = (item, new_item)->
        children = []
        old_ids = {}
        new_ids = {}
        for child in new_item.children ? [] then new_ids[child.id] = child
        for old_child in item.children ? []
            old_ids[old_child.id] = old_child
            new_child = new_ids[old_child.id]
            if new_child?
                children.push update_item old_child, new_child
            else
                children.push old_child
        for new_child in new_item.children ? [] by -1 when new_child.id not of old_ids
            children.unshift new_child

        return {item..., children}
    index = update_item index, index_from_file_tree

    # writing index in coffeescript format
    item_format = (item, level=0)->
        indent = '    '.repeat level
        if not item.type
            throw 'ERROR: Card type not defined in item:' + JSON.stringify item, null, 2
        if not item.id
            throw 'ERROR: Card id not defined in item:' + JSON.stringify item, null, 2
        formatted = "#{indent}#{item.type} '#{item.id}'"
        if item.attributes? and Object.keys(item.attributes).length != 0
            formatted += ', ' + JSON.stringify(item.attributes)
        if item.children? and item.children.length != 0
            formatted += ','
            for i in item.children
                formatted+='\n'+item_format i, level + 1
        return formatted
    index_header = '''
    module.exports = (cards={})->
        {index, category, article, spotlight, feature, link} = cards

        '''

    fs.writeFileSync index_file, index_header + item_format index, 1

    clean_index = {
        id: 'index'
        type: 'index'
        children: []
    }

    clean_item = (item, new_item)->
        for i in item.children ? []
            if i.attributes?.disabled
                continue
            new_item_child =
                id: i.id
                type: i.type
                attributes: i.attributes
                children: []
            new_item.children.push new_item_child
            clean_item i, new_item_child
    clean_item index, clean_index
    index_json_path = output_dir + '/index.json'

    fs.writeFileSync index_json_path, JSON.stringify clean_index

    main_menu_items = []
    main_menu = '''
        <ul id="defautl_main_menu" style="list-style-type: none; padding: 0; margin: 0;">[ITEMS]</ul>
    '''

    for item in  clean_index.children
        main_menu_items.push '''
        <li id="[ID]" style="display: inline; margin: 10px; font-weight: 700; font-size: 2em;">
            <a href="[HREF]"> [TITLE] </a>
        </li>
        '''.replace('[ID]', item.id).replace('[HREF]','/' + item.id + '/').replace('[TITLE]', item.attributes?.title or item.id)

    main_menu = main_menu.replace '[ITEMS]', main_menu_items.join('\n            ')

    renderer = require './card_content_renderer/main.coffee'
    page_template = '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>[TITLE]</title>
        <meta name="description" content="[DESCRIPTION]" />
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <meta charset="utf-8" >
        <meta name="theme-color" content=#3f3f3f></meta>
        <meta name=viewport content="width=device-width, initial-scale=1, user-scalable=no"></meta>
        <link rel="icon"
              type="image/png"
              href="/assets/icons/png/128x128.png">
        </link>
    </head>
    <body>
        <div id="app"></div>
        <script>
            var style=document.createElement('style');
            style.textContent='#static_page {opacity:0;}';
            document.body.appendChild(style);
        </script>

        <div id="static_page" style="max-width: 800px; margin:2em auto;">
            <a id="logo" href="/" style="text-decoration: none; font-size: 8em; color:black;">myou.cat</a>
            [MAIN_MENU]<br>
            <a id="parent_card" href="[PARENT_URL]" style="font-size: 1.5em; margin-top:1em; display:[PARENT_DISPLAY];">Back to: [PARENT_ID]</a><br>
            <div id="card_title" style="font-weight:700; font-size: 3em; margin-top:1em;">[TITLE]</div><br>
            [CARD]
            <div style="font-weight:700; font-size: 1.5em; margin-top:2em;">
                [CHILDREN]
            </div>
        </div>
        <script src="/src/site.js"></script>
    </body>
    </html>
    '''.replace '[MAIN_MENU]', main_menu

    get_file_tree_item = (path, tree)->
        if path.startsWith '/'
            path = path[1...]
        path_list = path.split('/')
        children_target = path_list[0]
        if path_list.length > 1
            for c in tree.children when c.id == children_target
                path_list = path_list[1...]
                return get_file_tree_item path_list.join('/'), c
        else
            for c in tree.children when c.id == children_target
                path_list = path_list[1...]
                return c

    # TODO: Optimize, and document the next function.
    export_articles = (input_path)->
        output_path = output_dir
        root_output_path = output_dir

        base_path = input_path.split(input_dir)[1]
        if base_path
            output_path = path.join(output_dir, base_path).replace /\\/g, '/'
            root_output_path = path.join(output_dir, base_path).replace /\\/g, '/'

        items = []
        for i in ls input_path
            ipath = path.join(input_path, i).replace /\\/g, '/'
            is_dir = test '-d', ipath

            if is_dir
                new_output_path = path.join(output_path, i).replace /\\/g, '/'
                new_root_output_path = path.join(root_output_path, i).replace /\\/g, '/'
                mkdir new_output_path
                if glob.sync(ipath+'/**/*.md').length > 0
                    if not fs.existsSync ipath + '.md'
                        item_path = path.resolve(ipath).split(path.resolve(input_dir))[1]
                        item_path = item_path.replace /\\/g, '/'
                        item = get_file_tree_item item_path, clean_index
                        item_parent_path_list = item_path.split('/')
                        item_parent_path_list = item_parent_path_list[0...item_parent_path_list.length-1]
                        item_parent_path = item_parent_path_list.join('/')
                        item_parent = get_file_tree_item item_parent_path, clean_index

                        children_template = '<li id="' + item_path + '/[CHILD_ID]"><a href="[CHILD_HREF]"}>[CHILD_ID]</a></li>'

                        if item?.children? and item.children.length
                            children_list = []
                            for c in item.children
                                chref = item.attributes?.link and (item.attributes.link != '#') and item.attributes.link or (item_path + '/' + c.id + '/')
                                children_list.push children_template.replace(/\[CHILD_ID\]/g, c.id).replace('[CHILD_HREF]', chref)


                            children = '''<ul id="children_cards" style="background: rgb(200,200,200); padding: 1em; width: fit-content; list-style-type: none;">''' +
                                children_list.join('\n') +
                            '</ul>'
                        else
                            children = ''

                        html = page_template
                            .replace(/\[TITLE\]/g, item.id)
                            .replace('[DESCRIPTION]', item?.attributes?.description or 'Myou is a cat.')
                            .replace('[CARD]', '<div style="font-weight: 700 font-size: 3em>item.id</div>"')
                            .replace('[PARENT_ID]', item_parent?.attributes?.title or item_parent?.id)
                            .replace('[PARENT_URL]', item_parent_path + '/')
                            .replace('[PARENT_DISPLAY]', (item_parent? and 'block') or 'none')
                            .replace('[CHILDREN]', children)

                        root_opath = path.join(root_output_path, item.id).replace(/\\/g, '/') + '/'
                        if not fs.existsSync root_opath
                            fs.mkdirSync root_opath

                        fs.writeFileSync root_opath + 'index.html', html

                    mkdir new_root_output_path


                export_articles ipath
            else
                {filename, extension} = get_filename_and_extension(i)
                extension = extension.toLowerCase()
                opath = path.join(output_path, filename).replace /\\/g, '/'
                root_opath = path.join(root_output_path, filename).replace /\\/g, '/'
                if extension != 'md'
                    # copy as is
                    cp ipath, opath + '.' + extension
                    continue

                text = fs.readFileSync(ipath, 'utf8').toString()

                # extract metadata and text from article
                article = {text:'', metadata:{}, intro:''}
                match = /--\n((.*\n)*?)---\n((.*\s)*)/.exec(text)

                # text is the group 3 of the match
                t = match[3].split(/<!--\s*intro\s*-->/)
                article.intro = t[0] or ''
                article.text = t[1] or ''

                # metadata is the group 1 of the match
                metadata_raw = match[1]

                # split in every \n which is followed by uppercase
                for chunk in metadata_raw.split(/\n(?=[A-Z])/)
                    c = /(\w*):((.*\s*)*)/.exec(chunk)
                    if c?
                        k = c[1].replace(/([A-Z])/g,'_$1')
                        .replace(/^_|\s*/g,'').toLowerCase()
                        v = c[2].replace(/^\s+|\s+$/g,'')
                        try v = JSON.parse v
                        article.metadata[k] = v

                #base directory to be added to image paths to make them relative to server root
                img_base_dir = '/' + ipath.split((input_dir + '/').replace('//','/'))[1].split(i)[0]
                if article.intro or article.text
                    item_path = path.resolve(ipath).replace(/\\/g, '/').split(path.resolve(input_dir).replace(/\\/g, '/'))[1]
                    item_path = item_path[...item_path.length - 3]
                    item = get_file_tree_item item_path, clean_index
                    item_parent_path_list = item_path.split('/')
                    item_parent_path_list = item_parent_path_list[0...item_parent_path_list.length-1]
                    item_parent_path = item_parent_path_list.join('/')
                    item_parent = get_file_tree_item item_parent_path, clean_index

                    children_template = '<li id="' + item_path + '/[CHILD_ID]"><a href="' + item_path + '/[CHILD_ID]/"}>[CHILD_ID]</a></li>'

                    if item?.children? and item.children.length
                        children_list = []
                        for c in item.children
                            chref = item.attributes?.link and (item.attributes.link != '#') and item.attributes.link or (item_path + '/' + c.id + '/')
                            children_list.push children_template.replace(/\[CHILD_ID\]/g, c.id).replace('[CHILD_HREF]', chref)


                        children = '''<ul id="children_cards" style="background: rgb(200,200,200); padding: 1em; width: fit-content; list-style-type: none;">''' +
                            children_list.join('\n') +
                        '</ul>'
                    else
                        children = ''

                    full_article = renderer article.intro + article.text, '/' + img_base_dir
                    full_article = full_article.replace /href="#([^"]*)"/g, 'href="/$1"'
                    full_article = full_article.replace /title="#([^"]*)"/g, 'title="/$1"'
                    html = page_template
                        .replace(/\[TITLE\]/g, article.metadata.title)
                        .replace('[DESCRIPTION]', article.metadata.description or article.intro[...144])
                        .replace('[CARD]', full_article)
                        .replace('[PARENT_ID]', item_parent?.id)
                        .replace('[PARENT_URL]', item_parent_path + '/')
                        .replace('[PARENT_DISPLAY]', (item_parent? and item_path != '/about/introduction' and 'block') or 'none')
                        .replace('[CHILDREN]', children)

                    if not fs.existsSync root_opath
                        fs.mkdirSync root_opath

                    fs.writeFileSync root_opath + '/index.html', html


                    if item_path == '/about/introduction'
                        fs.writeFileSync path.join(output_dir,'index.html').replace(/\\/g, '/'), html

                if article.intro
                    intro = renderer article.intro, img_base_dir
                    article.metadata.intro = intro
                    if article.text
                        article.metadata.has_text = true
                    fs.writeFileSync opath + '.json', JSON.stringify article.metadata

                if article.text
                    article = renderer article.text, img_base_dir
                    fs.writeFileSync opath + '.html', article

        return items

    export_articles input_dir
