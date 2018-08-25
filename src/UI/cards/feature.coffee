{theme, mixins, react_utils, TimeLimitedEventListener} = require '../common'
{React, ReactDOM} = react_utils
MyouAppletComponent = require('myou-applet').get_component(React)
e = React.createElement

{load_image, load_json} = require '../../loader'
Card = require './card'

class Feature extends Card
    constructor: (tag, settings)->
        super tag
        @settings = settings

    on_init: ->
        if @settings.intro
            load_settings = Promise.resolve @settings
        else
            load_settings = load_json '/' + @tag + '.json'
        load_settings.then (settings)=>
            @settings = {@settings..., settings...}
            @create_card()

    create_card: ->
        {tag, title, intro, image, applet, flip } = @settings
        absolute_image = "/#{@tag[...@tag.lastIndexOf('/')]}/" + image
        card = @

        @canvas_enabled = false
        vertical_mode = false
        @show_applet = ->
            throw 'You are executing show_applet before feature component is mounted'

        # image
        image_href = null
        image_opacity = 0
        class ImageComponent extends React.Component
            componentDidMount: ->
                if image then load_image(absolute_image).then ()=>
                    image_href = absolute_image
                    card.mounted and @forceUpdate()
                    requestAnimationFrame =>
                        image_opacity = 1
                        card.mounted and @forceUpdate()

            render: ->
                e 'div',
                    id: card.tag + '.feature_image'
                    className: 'FeatureImage'
                    style: {
                        width: '100%'
                        height: if vertical_mode then  Math.max(innerWidth, innerHeight) * 0.3 else '100%'
                        background: (image_href and mixins.bgImg(
                            image_href, 'transparent', 'center', 'cover'
                            )) or 'transparent'
                        opacity: image_opacity
                        (mixins.transition '1s', 'opacity')...
                    }

        class ContentComponent extends React.Component
            constructor: (props={})->
                super props
                @state = line_size: innerWidth

            componentDidMount: ->
                @update_text_size = new TimeLimitedEventListener 2000, =>
                    element = ReactDOM.findDOMNode(@)
                    rect = element.getBoundingClientRect()
                    old_line_size = parseInt(@state.line_size)
                    new_line_size = parseInt(rect.width)
                    if old_line_size != new_line_size
                        card.card_manager?.update_and_fix_jump =>
                            @setState line_size: new_line_size

                .event_sensor
                @update_text_size()
                addEventListener 'resize', @update_text_size

            componentDidUpdate: ->
                card.myou?.canvas_screen?.resize_to_canvas()
            componentWillUnmount: ->
                removeEventListener 'resize', @update_text_size
            render: ->
                line_size = 0.45*@state.line_size
                font_size = Math.min(
                    Math.max line_size / 10, mixins.cm * 0.45
                    mixins.cm
                    )
                margin = font_size * 2

                e 'div',
                    className: 'FeatureContent'
                    style: {
                        mixins.rowFlex...
                        overflow: 'hidden'
                        alignItems: 'flex-start'
                        justifyContent: 'flex-start'
                        top: 0
                        width: vertical_mode and "calc(100% - #{2*margin}px)" or "calc(50% - #{2*margin}px)"
                        margin: margin
                    }
                    e 'div',
                        style: {
                            mixins.columnFlex...
                            justifyContent: 'flex-end'
                            alignItems: 'flex-start'
                            fontSize: font_size * 2
                            fontWeight: 100
                        }
                        e 'div',
                            style:
                                color: mixins.chroma(theme.category_colors[card.category]).darken 0.8
                            title
                        e 'div',
                            style:
                                fontWeight: 400
                                fontSize: font_size

                            e 'div',
                                dangerouslySetInnerHTML:__html: intro

        class Component extends React.Component
            constructor: (props={})->
                super props
                @canvas_ref = React.createRef()

            check_vertical_mode: ->
                innerWidth/mixins.cm < 17

            componentDidMount: ->
                card.mounted = true
                card.show_applet = =>
                    # TODO: It will be black for a few frames, so I'm using
                    # a setTimeout but we need to fix it properly in the engine.
                    setTimeout =>
                        if card.applet
                            # redraw card after enable canvas
                            card.canvas_enabled = 1
                            card.mounted and @forceUpdate()
                        else
                            console.warn '
                                There is no cavas to enable, it only is created if
                                feature.applet function exists.
                            '
                    ,1000

                addEventListener 'resize', =>
                    is_vertical_mode = @check_vertical_mode()
                    if vertical_mode != is_vertical_mode
                        vertical_mode = is_vertical_mode
                        card.mounted and @forceUpdate()

            componentWillUnmount: ->
                card.mounted = false
                card.myou?.main_loop.enabled = false
                card.myou?.render_manager.clear_context()

            componentWillMount: ->
                vertical_mode = @check_vertical_mode()
            render: ->
                e 'div',
                    id: card.tag + '.feature'
                    style: {
                        theme.card...
                        (if vertical_mode then mixins.columnFlex else mixins.rowFlex)...
                        alignItems: 'stretch'
                        position:'relative'
                        background: theme.colors.light
                        maxWidth: '35cm'
                        width: '90vw'
                    }
                    if vertical_mode or flip
                        null
                    else
                        e ContentComponent, key:card.tag+'.feature_content'
                    e 'div',
                        style:
                            position: 'relative'
                            width: vertical_mode and '100%' or '50%'
                            background: theme.colors.gray
                        e ImageComponent, key:card.tag+'.feature_image'
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

                    if vertical_mode or flip
                        e ContentComponent, key:card.tag+'.feature_content'
                    else
                        null

        super e Component

module.exports = Feature
