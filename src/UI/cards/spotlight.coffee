{theme, mixins, react_utils, TimeLimitedEventListener} = require '../common'
{React, ReactDOM} = react_utils
MyouAppletComponent = require('myou-applet').get_component(React)
e = React.createElement

SlideShow = require '../slideshow'
Card = require './card'
{load_json} = require '../../loader'
class Spotlight extends Card
    # A spotlight is a card which contains a slideshow, a canvas that will play a
    # myou engine applet and a child wich will be placed over the canvas and the slideshow
    constructor: (tag, settings)->
        super tag
        @settings = settings
        @video_time = 0
        @video_opacity = 0
        @video_src = ''

    create_card: ->
        {tag, title, logo, intro, text, buttons, applet, alignment, image} = @settings
        for b in buttons ? []
            b.category = @category
            b.key = tag + '.button.' + b.text + Math.random()

        @spotlight_ref = React.createRef()
        card = @
        absolute_image = "/#{@tag[...@tag.lastIndexOf('/')]}/" + image
        absolute_logo = "/#{@tag[...@tag.lastIndexOf('/')]}/" + logo

        class SpotlightComponent extends React.Component
            constructor: (props={})->
                super props
                @state = line_size: innerWidth
                @update_text_size = null # to be rewritten in componentDidMount
                @mounted = false

            componentDidMount: ->
                @mounted = true
                card.show_applet = =>
                    card.slideshow.pause()
                    # @mounted and @forceUpdate()

                @update_text_size = => #new TimeLimitedEventListener 2000, =>
                    if not @mounted
                        return
                    element = ReactDOM.findDOMNode(@)
                    rect = element.getBoundingClientRect()
                    old_line_size = parseInt(@state.line_size)
                    new_line_size = parseInt(rect.width)
                    if old_line_size != new_line_size
                        @setState line_size: new_line_size
                    @update_video_size()

                # .event_sensor
                @update_text_size()
                addEventListener 'resize', @update_text_size

            componentDidUpdate: ->
                card.myou?.canvas_screen?.resize_to_canvas()
                @update_video_size()

            update_video_size: =>
                # Firefox quirck: Video size can not be calculated in css if it is dynamic.
                if card.video_ref?.current?
                    vid = card.video_ref.current
                    client_height = vid.getBoundingClientRect()["height"]
                    aspect_ratio = vid.videoWidth/vid.videoHeight
                    if aspect_ratio
                        vid.style.width = client_height * aspect_ratio + 'px'

            componentWillUnmount: ->
                removeEventListener 'resize', @update_text_size
                @mounted = false
                card.myou?.main_loop.enabled = false
                card.myou?.render_manager.clear_context()

            render: ->
                line_size = 0.45*@state.line_size
                font_size = Math.min(
                    Math.max line_size / 10, mixins.cm * 0.4
                    mixins.cm
                    )

                button_size = Math.max(mixins.cm * 0.5, font_size*0.8)


                e 'div',
                    id: card.tag + '.spotlight'
                    key: card.tag + '.spotlight'
                    style: {
                        theme.card...
                        position:'relative'
                        overflow: 'hidden'
                        background: theme.colors.very_dark
                        color: theme.colors.light
                        maxWidth: '35cm'
                        height: '100%'
                        width: '90vw'
                        ref: card.spotlight_ref
                    }

                    if card.slideshow
                        e card.slideshow.component,
                            style:
                                right: 0
                                top: 0
                                maxWidth:'100%'
                            e 'div',
                                id: card.tag + '.gradient'
                                key: card.tag + '.gradient'
                                style: {
                                    width: '50%'
                                    minWidth: '10cm'
                                    height: '100%'
                                    position: 'absolute'
                                    left: 0
                                    top: 0
                                    background: mixins.smooth_gradient
                                        to: 'right'
                                        a: theme.colors.very_dark
                                        b: "rgba(0, 0, 0, 0)"
                                        steps: 10
                                }

                    if image
                        e 'div',
                            style: {
                                display: 'inline-block'
                                height: '100%'
                                position: 'absolute'
                                top: 0
                                right: 0
                                maxWidth: '100%'
                                overflow: 'hidden' #workaround for a bug in chrome
                            }

                            if card.video_ref
                                e 'video',
                                    id: card.tag + '.image'
                                    key: card.tag + '.image'
                                    src: absolute_image
                                    # autoPlay: 'autoPlay'
                                    loop: 'loop'
                                    preload: 'none'
                                    ref: card.video_ref
                                    onCanPlay: =>
                                        card.video_ref.current.style.opacity = card.video_opacity = 1
                                        @update_video_size()
                                    style: {
                                        height: '100%'
                                        mixins.transition('1000ms', 'opacity')...
                                    }
                            else
                                e 'img',
                                    id: card.tag + '.image'
                                    key: card.tag + '.image'
                                    src: absolute_image
                                    style: {
                                        height: '100%'
                                    }
                            e 'div',
                                id: card.tag + '.gradient'
                                key: card.tag + '.gradient'
                                style: {
                                    width: '50%'
                                    minWidth: '10cm'
                                    height: '100%'
                                    position: 'absolute'
                                    left: 0
                                    top: 0
                                    background: mixins.smooth_gradient
                                        to: 'right'
                                        a: theme.colors.very_dark
                                        b: "rgba(0, 0, 0, 0)"
                                        steps: 10
                                }


                    if applet
                        e MyouAppletComponent,
                            id: card.tag + '.applet'
                            key: card.tag + '.applet'
                            check_is_on_screen: true
                            stop_on_scroll: true
                            on_show_applet: -> card.show_applet()
                            app: card.applet = require('../../content/applets_index') applet
                            style: {
                                position: 'absolute'
                                top: 0
                                height: '100%'
                                width: '100%'
                                borderRadius: theme.radius.r2
                                (mixins.transition '1s', 'opacity')...
                            }
                            myou_settings: {
                                data_dir: '/data',
                                disable_physics: true,
                                gl_options: {alpha:false, antialias:true}
                                auto_resize_to_canvas: false
                            }


                    e 'div',
                        className: 'SpotlightContent'
                        style: {
                            mixins.rowFlex...
                            position: 'relative'
                            overflow: 'hidden'
                            alignItems: 'flex-start'
                            justifyContent: 'flex-start'
                            top: 0
                            textShadow: theme.shadows.title_strong
                            margin: '7%'
                        }
                        e 'div',
                            style: {
                                mixins.columnFlex...
                                justifyContent: 'flex-end'
                                alignItems: 'flex-start'
                                fontSize: font_size * 2
                                fontWeight: 500
                            }
                            if logo
                                e 'img',
                                    src: absolute_logo
                                    height: font_size * 4
                            else
                                title

                            e 'div',
                                style: {
                                    fontWeight: 100
                                    fontSize: font_size
                                    width: '65%'
                                }
                                e 'div',
                                    dangerouslySetInnerHTML:__html: intro
                            e 'div',
                                dangerouslySetInnerHTML:__html: text

                            if buttons
                                ls = 0.45*innerWidth
                                fs = Math.min(
                                    Math.max line_size / 10, mixins.cm * 0.4
                                    mixins.cm
                                    )
                                anti_margin = -Math.max(mixins.cm * 0.5, font_size*0.8)
                                e 'div',
                                    style:{
                                        mixins.rowFlex...
                                        flexWrap: 'wrap'
                                        margin: "#{anti_margin}px #{anti_margin*0.5}px 0 #{anti_margin*0.5}px"
                                    }
                                    for b in buttons
                                        e Button, b

        super e SpotlightComponent

    show_applet: ->
        console.warn 'You are executing show_applet before spotlight component is mounted'

    on_init: ->
        if @settings?.intro
            load_settings = Promise.resolve @settings
        else
            load_settings = load_json '/' + @tag + '.json'

        load_settings.then (settings)=>
            {use_physics=false, slides=[], play_on_init=false, image} = settings

            if image?.endsWith '.mp4' #TODO: detect video
                @video_ref = React.createRef()
                @mounted_promise.then =>
                    @video_ref.current.currentTime = @settings.start or 0
                    @video_ref.current.muted = true
                @add_on_screen_callback =>
                    console.log 'VIDEO ON SCREEN:', @video_ref.current
                    @mounted_promise.then =>
                        load_promise = @video_ref.current.load()
                        @video_ref.current.currentTime = @video_time
                        @video_ref.current.play()
                @add_out_of_screen_callback =>
                    console.log 'VIDEO OUT OF SCREEN:', @video_ref
                    @video_time = @video_ref.current.currentTime
                    src = @video_ref.current.src
                    @video_ref.current.pause()
                    @video_time = @video_ref.current.currentTime
                    @video_ref.current.src = ''
                    @video_ref.current.load()
                    @video_ref.current.src = src
                    @video_ref.current.style.opacity = @video_opacity = 0

            if slides.length
                absolute_slides = []
                for s in slides
                    absolute_slides.push "/#{@tag[...@tag.lastIndexOf('/')]}/" + s

                @play_on_init = play_on_init
                @slideshow = new SlideShow
                    id:@tag
                    slide_urls: absolute_slides
                    slide_duration: settings.slide_duration
                    alignment: 'center'
                    fill: 'cover'
                    force_aspect_ratio: true

                @on_screen_promise.then =>
                    @slideshow.play()

                @slideshow.init().then =>
                    if @play_on_init
                        @slideshow.play()

            @settings = settings
            @create_card()
            Promise.resolve()

class Button extends React.Component
    constructor: (props={})->
        super props
        @state = over: false

        {color, category, background=true, href} = props
        @color = mixins.color_to_chroma color, category
        @background = background

        if href
            @element_type = 'a'
        else
            @element_type = 'div'

    # this component is a button with a label defined in the property called "content".
    render: ->
        line_size = 0.45*innerWidth
        font_size = Math.min(
            Math.max line_size / 10, mixins.cm * 0.4
            mixins.cm
            )
        button_size = Math.max(mixins.cm * 0.5, font_size*0.8)

        e @element_type,
            href: @props.href
            onClick: (event)=>
                @props.onClick?(event)
            onMouseOver: =>
                @setState
                    over: true
            onMouseOut: =>
                @setState
                    over: false
            style: if @background
                    {
                        background: if @state.over then @color.brighter() else @color
                        padding: "#{button_size*0.8}px #{button_size}px"
                        margin: "#{button_size}px #{button_size*0.5}px 0 #{button_size*0.5}px"
                        fontSize: button_size
                        textShadow: theme.shadows.title_regular
                        boxShadow: theme.shadows.box
                        borderRadius: theme.radius.r2
                        userSelect: 'none'
                        textDecoration: 'none'
                        color: 'white'
                        cursor: 'pointer'
                        (mixins.transition '0.5s', 'background')...
                        @props.style...
                    }
                else
                    {
                        background: 'transparent'
                        padding: "#{button_size*0.8}px #{button_size}px"
                        margin: "#{button_size}px #{button_size*0.5}px 0 #{button_size*0.5}px"
                        fontSize: button_size
                        textShadow: theme.shadows.title_regular
                        userSelect: 'none'
                        textDecoration: 'none'
                        color: if @state.over then @color else 'white'
                        cursor: 'pointer'
                        (mixins.transition '0.5s', 'color')...
                        @props.style...
                    }
            dangerouslySetInnerHTML: __html: @props.content


module.exports = {Spotlight, Button}
