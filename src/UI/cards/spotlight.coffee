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

    create_card: ->
        {tag, title, intro, text, buttons, applet, alignment} = @settings
        for b in buttons ? []
            b.category = @category
            b.key = tag + '.button.' + b.text

        card = @
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

                @update_text_size = new TimeLimitedEventListener 2000, =>
                    if not @mounted
                        return
                    element = ReactDOM.findDOMNode(@)
                    rect = element.getBoundingClientRect()
                    old_line_size = parseInt(@state.line_size)
                    new_line_size = parseInt(rect.width)
                    if old_line_size != new_line_size
                        @setState line_size: new_line_size
                .event_sensor
                @update_text_size()
                addEventListener 'resize', @update_text_size

            componentDidUpdate: ->
                card.myou?.canvas_screen?.resize_to_canvas()
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
                    }

                    card.slideshow.react_element
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
            {use_physics=false, slides=[], play_on_init=false} = settings

            absolute_slides = []
            for s in slides
                absolute_slides.push "/#{@tag[...@tag.lastIndexOf('/')]}/" + s

            @play_on_init = play_on_init
            @slideshow = new SlideShow(
                @tag
                absolute_slides
                settings.slide_duration
                settings.slides_alignment
                )
            @settings = settings

            @on_screen_promise.then =>
                @slideshow.play()

            @create_card()
            @slideshow.init().then =>
                if @play_on_init
                    @slideshow.play()
            Promise.resolve()

class Button extends React.Component
    constructor: (props={})->
        super props
        @state = over: false

        {color, category, href} = props
        @color = mixins.color_to_chroma color, category

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
            style: {
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
            dangerouslySetInnerHTML: __html: @props.content


module.exports = {Spotlight, Button}
