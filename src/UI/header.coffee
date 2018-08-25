{theme, mixins, react_utils} = require './common'
{React, ReactResizeDetector} = react_utils
e = React.createElement

{MainMenu} = require './main_menu'
Card = require './cards/card'

exports.is_bar_mode = ->
    if document.getElementById 'header'
        mixins.getScrollTop() > mixins.dynamic_spacing * 4 - mixins.dynamic_spacing
    else
        true

# mounted_promise will be resolved when floating_header is mounted.
resolve_mounted_promise = ->
mounted_promise = new Promise (resolve, reject)->
    resolve_mounted_promise = resolve

# update will be overwritten when floating_header is mounted.
exports.update = ->
    mounted_promise.then ->
        exports.update()

# floating header has two states (bar_mode = true, bar_mode = false)
# if bar_mode == true, it will be floating on the top of the page as a nav bar.
# if bar_mode == false, it will be placed under over header_card with absolute position.
# floating_header contains the main menu.

exports.Header = class Header extends React.Component
    constructor: (props={})->
        super props
        @mounted = false
        @state =
            bar_mode:false

    componentDidMount: ->
        exports.update = =>
            @setState bar_mode: exports.is_bar_mode()
        addEventListener 'scroll', exports.update
        resolve_mounted_promise()
        @mounted = true

    on_resize: ->
        @forceUpdate()

    componentWillUnmount: ->
        @mounted = false

    shouldComponentUpdate: (newProps, newState)->
        newState.bar_mode != @state.bar_mode

    render: ->
        # Calculating header_height wich will be the total height of the header.
        header_height = mixins.dynamic_spacing * 4
        # Calculating main_menu_height, to fit the screen size
        main_menu_height =
            if @state.bar_mode
                Math.floor(Math.min(mixins.dynamic_spacing, 1.75*mixins.cm))
            else
                mixins.dynamic_spacing
        e 'div',
            id: 'floating_header'
            style: {
                height: header_height
                width: '100%'
                zIndex: 1000
                (
                    if @state.bar_mode
                        # only main_menu inside a floating bar
                        {
                            position:'fixed'
                            boxShadow: theme.shadows.long
                            top: - header_height + main_menu_height
                            # height: main_menu_height
                        }
                    else
                        # main_menu and logo as background image
                        position:'absolute'
                )...

            }
            e ReactResizeDetector,
                handleWidth: true
                onResize: => @on_resize()
            e 'div',
                style:
                    position: 'absolute'
                    bottom: 0
                    opacity: (@state.bar_mode and 1) or 0
                    background: theme.colors.very_dark
                    height: main_menu_height
                    width: '100%'

            e MainMenu, bar_mode: @state.bar_mode, card_index: @props.card_index

exports.HeaderCard = class HeaderCard extends React.Component
    # it is a component which contains only the logo (as background) and
    # its size is the same than the floating_header as not bar_mode.
    componentDidMount: ->
        exports.update()

    on_resize: -> @forceUpdate()

    render: ->
        e 'div',
            id: 'header'
            name: 'header'
            style:
                height: mixins.dynamic_spacing * 4
                width: '100%'
                overflow: 'hidden'
                background: mixins.bgImg theme.logo, 'transparent'
            e ReactResizeDetector,
                handleWidth: true
                onResize: => @on_resize()

header_card_component = e exports.HeaderCard, key:'header'
exports.header_card = header_card = new Card 'header', header_card_component, {paddingTop: 0, marginTop:0, width: '100%'}
header_card.on_init = -> Promise.resolve()
