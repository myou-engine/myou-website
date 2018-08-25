{theme, mixins, react_utils, moment, TimeLimitedEventListener} = require '../common'
{React, ReactDOM, ReactResizeDetector} = react_utils
e = React.createElement
Card = require './card'
{MyouApplet} = require 'myou-applet'
myou_applets = {}
{load_image, load_json, load_text, load_media} = require '../../loader'

today = Math.floor(Date.now/1000/60/60/24)*1000*60*60*24

img_video_re = new RegExp /\<(img|video)[^<]*>/g

# this card contains a title, date, author, text, images, etc.
# Its content can be downloaded as HTML from the server or generated from markdown.

prevent_default_event = (e)->
    console.log 'preventing event', e.cancelable
    e.preventDefault()

disable_scroll = ->
    addEventListener 'wheel', prevent_default_event
    addEventListener 'touchmove', prevent_default_event

enable_scroll = ->
    removeEventListener 'wheel', prevent_default_event
    removeEventListener 'touchmove', prevent_default_event

class Article extends Card
    constructor: (tag, settings={})->
        super tag
        @settings = settings
        @videos = []
        @canvas = []
        @images = []

    create_card: (expanded)=>
        # it will configure the card only when the content
        # has been downloaded (in load_promise.then)

        play_videos = =>
            for v in @videos
                if v.autoplay
                    v.play()

        pause_videos = =>
            for v in @videos
                v.pause()

        enable_full = (p,c)->
            disable_scroll()
            p.orig_style =
                position: p.style.position
                background: p.style.background
                top: p.style.top
                left: p.style.left
                width: p.style.width
                maxWidth: p.style.maxWidth
                height: p.style.height
                maxHeight: p.style.maxHeight
                zIndex: p.style.zIndex
                cursor: p.style.cursor
                display: p.style.display
                flexFlow: p.style.flexFlow
                justifyContent: p.style.justifyContent
                alignItems: p.style.alignItems

            c.orig_style =
                margin: c.style.margin
                maxWidth: c.style.maxWidth
                maxHeight: c.style.maxHeight
                width: c.style.width
                height: c.style.height

            p.style.position = 'fixed'
            p.style.background = 'rgba(0,0,0,0.8)'
            p.style.top = 0
            p.style.left = 0
            p.style.width = '100vw'
            p.style.maxWidth = null
            p.style.height = '100vh'
            p.style.maxHeight = null
            p.style.zIndex = 100000000000
            p.style.display = 'flex'
            p.style.flexFlow = 'row wrap'
            p.style.justifyContent = 'center'
            p.style.alignItems = 'center'

            c.style.margin = null
            c.style.maxWidth = '100vw'
            c.style.maxHeight = '100vh'
            if c.className == 'AppletContainer'
                c.style.width = '90vw'
                c.style.height = '90vh'
            else
                p.style.cursor = 'zoom-out'
                c.style.width = 'auto'
                c.style.height = 'auto'
            # c.style.width = '100%'
            c.full = true

        disable_full = (p,c)->
            enable_scroll()
            for k,v of p.orig_style
                p.style[k] = v
            for k,v of c.orig_style
                c.style[k] = v
            c.style.maxWidth = p.orig_style.img_max_width
            c.style.maxHeight = p.orig_style.img_max_height
            c.style.margin = p.orig_style.img_margin

            c.full = false

        full_toggle = (event)->
            event.stopPropagation()
            p = event.target
            while not p.classList.contains 'ExpandableContent'
                p = p.parentElement

            c = p.children[0]
            if not c.full
                enable_full(p,c)
            else
                disable_full(p,c)

        init_content = =>
            article_card = document.getElementById @tag + '.container'
            @videos = article_card.getElementsByTagName 'video'
            pause_videos()
            @images = article_card.getElementsByTagName 'img'
            @canvas = article_card.getElementsByTagName 'canvas'
            @on_screen_promise.then =>
                play_videos()
                @add_on_screen_callback play_videos
                @add_out_of_screen_callback pause_videos
                for a,i in @canvas
                    id = @tag + '.applet.' + i
                    applet = myou_applets[id]
                    if not applet?
                        applet_style = {}
                        for k,v of a.style
                            applet_style[k]=v
                        applet = new MyouApplet {
                            id: id
                            title: a.title
                            style: applet_style
                            canvas: a
                            myou_settings: {
                                data_dir: '/data',
                                disable_physics: true,
                                gl_options: {alpha:false, antialias:true}
                                auto_resize_to_canvas: false
                            }
                            app: require('../../content/applets_index') a.id
                            on_show_applet: ->
                                v = a.parentElement.getElementsByTagName('video')
                                v.length and v[0].pause()
                                a.style.opacity = 1
                        }
                    else if a != applet.canvas
                        a.replaceWith applet.canvas
                        @canvas[i] = applet.canvas

                    myou_applets[id] = applet
                    a.applet = applet
                    if not applet.enabled
                        applet.enable()


            for i in article_card.getElementsByClassName 'ExpandableContent' then do(i)->
                if not i.classList.contains 'Applet' and not i.children[0].controls
                    i.style.cursor = 'zoom-in'
                    i.removeEventListener 'click',  full_toggle
                    i.addEventListener 'click', full_toggle

        article = @
        class ArticleCardComponent extends React.Component
            constructor: (props={})->
                super props
                @state = expanded: false

            on_resize: ->
                console.warn 'You are trying to execute on_resize before mounting the component'

            componentDidMount: ->
                article._restore_promises()
                init_content()

                article.forceUpdate = =>
                    if not article.mounted then return
                    article.card_manager?.update_and_fix_jump =>
                        @forceUpdate()
                @on_resize = new TimeLimitedEventListener(2000, article.forceUpdate).event_sensor
                article.setState = (state)=> @setState(state)
                article.expand = =>
                    if not article.settings.has_text
                        return
                    if not article.text
                        load_text("/#{article.tag}.html").then (text)=>
                            article.text = text
                            @setState {expanded:true}
                    else
                        @setState {expanded:true}

                # Replacing media elements by others which are already loaded.
                # because it will not make jump the following articles

                article_card = document.getElementById article.tag + '.container'
                videos = article_card.getElementsByTagName('video')
                images = article_card.getElementsByTagName('img')

                for element in videos
                    replacement = article.settings.media_elements[element.id]
                    if replacement
                        element.parentElement.replaceChild replacement, element

                for element in images when element.id
                    replacement = article.settings.media_elements[element.id]
                    if replacement
                        element.parentElement.replaceChild replacement, element

                if expanded
                    @setState(expanded:true)

                article.mounted = true

            componentWillUnmount: ->
                article.mounted = false

            componentDidUpdate: (prevProps, prevState)->
                if prevState.expanded != @state.expanded
                    init_content()

            render: ->
                spacing = Math.max(mixins.dynamic_spacing*0.25, mixins.cm * 0.7)
                color = mixins.chroma(theme.category_colors[article.category])
                # calculating font size depending on innerWidth
                # and minimum size for a correcttext visibility
                fontSize = Math.max(Math.min(innerWidth, mixins.cm*25)*0.024, mixins.cm*0.45)

                e 'div',
                    id: article.tag + '.container'
                    key: article.tag + '.container'
                    style: {
                        maxWidth: "100%"
                        fontSize: fontSize
                        fontWeight: 400
                        mixins.transition('1s', 'opacity')...
                    }
                    e ReactResizeDetector,
                        handleWidth: true
                        onResize: => @on_resize()
                    if article.intro then e 'div',
                        id: article.tag + '.intro_container'
                        key: article.tag + '.intro_container'
                        style: {
                            theme.card...
                            paddingTop: Math.min 0.05 * innerWidth, mixins.cm * 1.5
                            paddingBottom: Math.min 0.05 * innerWidth, mixins.cm * 1.5
                            paddingLeft: Math.min 0.055 * innerWidth, mixins.cm * 2
                            paddingRight: Math.min 0.055 * innerWidth, mixins.cm * 2
                        }

                        if article.settings and article.settings.title
                            e ArticleTitle,
                                id: article.tag + '.title'
                                key: article.tag + '.title'
                                article: article

                        if article.settings and article.settings.image
                            e ArticleImage,
                                id: article.tag + '.image.' + article.settings.image
                                key: article.tag + '.image.' + article.settings.image
                                article: article

                        e 'div',
                            id: article.tag + '.intro'
                            key: article.tag + '.intro'
                            dangerouslySetInnerHTML:__html: article.intro

                        if article.settings.has_text
                            if @state.expanded
                                # expanded text
                                e 'div',
                                    id: article.tag + '.expanded_text'
                                    key: article.tag + '.expanded_text'
                                    dangerouslySetInnerHTML:__html: article.text

                            else
                                # expand button
                                e 'div',
                                    id: article.tag + '.expand_button_container'
                                    key: article.tag + '.expand_button_container'
                                    style: {
                                        mixins.rowFlex...
                                        justifyContent: 'center'
                                    }
                                    e 'div',
                                        id: article.tag + '.expand_button'
                                        key: article.tag + '.expand_button'
                                        style: {
                                            cursor: 'pointer'
                                            color: color.darken 0.5
                                            margin: "#{spacing * 0.3}px 0"
                                            paddingBottom: spacing* 0.3
                                            width: 'auto'
                                            userSelect: 'none'
                                            mixins.transition('250ms', 'background shadow width')...
                                        }
                                        onClick: => article.expand()
                                        onMouseOver: (event)=>
                                            event.target.style.color = color.darken 1.5
                                            event.target.style.paddingBottom = spacing + 'px'

                                        onMouseOut: (event)=>
                                            event.target.style.color = color.darken 0.5
                                            event.target.style.paddingBottom = spacing*0.3 + 'px'

                                        'Continue reading'

        super e ArticleCardComponent

    on_init: (options={})=>
        {expanded=false} = options
        # on init the content will be downlaoded and it returns a promise which
        # will be resolved after download all the content.

        # when this promise is resolved, we will create the card
        load_settings = =>
            @intro = @settings.intro
            @settings.date = new Date @settings.date
            @settings.media_elements = {}

            # load promise will be resolved when the article itself and all its
            # content have been loaded.
            media_promises = []

            match = true
            while match
                if match != true
                    media_promises.push load_media(match).then (element)=>
                        # We are saving the loaded elements use as replacement
                        # of the originals of @settings.intro
                        @settings.media_elements[element.id] = element
                match = img_video_re.exec @settings.intro

            Promise.all [
                Promise.all media_promises
                if @settings.image
                    load_image("/#{@tag[...@tag.lastIndexOf('/')]}/" + @settings.image).then (img)=>
                        @settings.image_element = img

                if @settings.has_text and expanded
                    load_text("/#{@tag}.html").then (text)=>
                        @text = text

                else if @settings.text
                    @text = @settings.text
                    @settings.has_text = true
            ]

        if @settings.intro
            load_promise = load_settings()
        else
            load_promise = load_json("/#{@tag}.json").then (settings)=>
                @settings = {@settings..., settings...}
                load_settings()

        load_promise.then =>
            @create_card expanded
            Promise.resolve()

    expand: => #to be rewritten by componentDidMount of ArticleCardComponent.
        @mounted_promise.then =>
            @expand()

    on_goto: =>
        @expand()

class ArticleTitle extends React.Component

    render: ->
        {article} = @props
        color = mixins.chroma(theme.category_colors[article.category])
        href = '#' + article.category + ':' + article.id
        has_title = article.settings.title and not article.settings.skip_title
        has_author = article.settings.author  and not article.settings.skip_author
        has_date = article.settings.date and not article.settings.skip_date
        e 'a',
            href: href
            title: href

            style:
                textDecoration: 'none'
                paddingBottom: text_size
                paddingTop: text_size

            if has_title
                text_size = Math.max(Math.min(Math.min(0.9 * innerWidth, 25 * mixins.cm) /10, mixins.cm * 1.3), mixins.cm * 0.7)
                e 'div',
                    style:
                        color: color.darken 0.8
                        fontSize: text_size * 0.8
                        fontWeight: 100
                        paddingBottom: text_size * 0.3

                    article.settings.title
            e 'div',
                style: {
                    mixins.rowFlex...
                    flexWrap: 'wrap'
                }

                if has_author
                    e 'div',
                        style:
                            color: color.darken 0.8
                            fontSize: text_size * 0.4
                            fontWeight: 400
                            paddingRight: text_size * 0.3
                        article.settings.author
                if has_author and has_date
                    e 'div',
                        style:
                            color: color.darken 0.8
                            fontSize: text_size * 0.4
                            fontWeight: 400
                            paddingRight: text_size * 0.3
                        '-'
                if has_date
                    date = article.settings.date
                    day = Math.floor(date/1000/60/60/24)*1000*60*60*24
                    fdate = moment(date).format("[#{(day == today and " (Today) ") or ""}]MMM Do [  ] YYYY")
                    e 'div',
                        style:
                                color: color.darken 1
                                fontSize: text_size * 0.5
                                fontWeight: 300
                        fdate

class ArticleImage extends React.Component
    componentDidMount: ->
        # We are inserting article.settings.image_element
        # because we are sure it is loaded and
        # it will not make jump the following articles

        element = ReactDOM.findDOMNode(@)
        image_container = element.firstElementChild
        img = @props.article.settings.image_element

        img.style.width = '100%'
        img.style.height = '100%'
        img.style.borderRadius = theme.radius.r1 + 'px'
        img.style.boxShadow = 'rgba(0, 0, 0, 0.2) 0px 4px 10px, rgba(0, 0, 0, 0.2) 0px 0px 5px'


        image_container.appendChild img

    render: ->
        {article} = @props
        enough_width = innerWidth > 20*mixins.cm

        if enough_width
            e 'div',
                className: 'ExpandableContent'
                style: {
                    mixins.rowFlex...
                    justifyContent: 'center'
                    float: 'right'
                    maxWidth:  '60%'
                    maxHeight: '100%'
                }
                e 'div',
                    className: 'image_container'
                    id: article.settings.image
                    style:
                        maxWidth: '100%'
                        margin: '1cm 0 0.5cm 0.5cm'

        else
            e 'div',
                className: 'ExpandableContent'
                style: {
                    mixins.rowFlex...
                    justifyContent: 'center'
                    width: '100%'
                }
                e 'div',
                    className: 'image_container'
                    id: article.settings.image
                    style:
                        maxWidth: '100%'
                        maxHeight: '100%'
                        margin: '0.5cm 0 0.5cm 0'

module.exports = Article
