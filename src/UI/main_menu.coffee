{theme, mixins, react_utils} = require './common'
{React, ReactDOM} = react_utils
header = require './header'

e = React.createElement

exports.set_active_category = ->
    console.warn 'You are trying to set active category before mount MainMenu.'

close_close_sub_menus = ->
# main menu contains is the map of the web-site,
# and it will contain links to all of the categories
exports.MainMenu = class MainMenu extends React.Component
    constructor: (props={})->
        super props
        @card_manager = null
        @state =
            active: null
            over: null
            expanded: null

        @main_menu = []
        for item in @props.card_index.children
            menu_item =
                id: item.id
                title: item.attributes.title or item.id
                link: item.attributes.link or '#' + item.id
                color: mixins.color_to_chroma item.attributes.color, item.id
                no_menu: item.attributes.no_menu
            if 'children' of item and item.attributes.submenu
                menu_item.submenu = []
                for subitem in item.children
                    menu_item.submenu.push
                        id: subitem.id
                        title: subitem.attributes?.title or subitem.id
                        link: subitem.attributes?.link or '#' + item.id + '/' + subitem.id
            @main_menu.push menu_item

    componentDidMount: ->
        close_close_sub_menus = =>
            @setState expanded: null
        exports.set_active_category = (category)=>
            @setState active: category

    render: ->
        # adjusting dynamic spacing to bar_mode
        dynamic_spacing =
            if @props.bar_mode
                parseInt(Math.min(mixins.dynamic_spacing, 1.75*mixins.cm))
            else
                mixins.dynamic_spacing
        e 'div',
            id: 'main_menu'
            style: {
                mixins.rowFlex...
                justifyContent: 'center'
                alignItems: 'center'
                height: dynamic_spacing
                position:'absolute'
                bottom: 0
                left: 0
                width: '100%'
                fontSize: 15
                fontFamily: 'Roboto, sans-serif'
                zIndex:1000
            }

            for item in @main_menu when not item.no_menu then do (item)=>
                href = '#' + item.id

                should_expand = => requestAnimationFrame =>
                    if @state.expanded == item.id
                        return
                    else if item.submenu?
                        @setState expanded: item.id
                    else
                        @setState expanded: null

                on_click = (event) =>
                    if event.target.id in [item.id + '.item', item.id + '.item.container']
                        item.onClick?(event)
                        location.href = item.link or href
                        close_close_sub_menus()

                on_over = (event) =>
                    if event.target.id in [item.id + '.item', item.id + '.item.container']
                        @setState
                            over: item.id
                        should_expand()

                e 'div',
                    key: item.id + '.item.container'
                    id: item.id + '.item.container'

                    onClick: (event)=>
                        if not item.submenu
                            on_click(event)
                        else if @state.expanded
                            on_click(event)
                        else
                            @setState expanded: item.id

                    onMouseOver: on_over

                    onMouseLeave: (event)=>
                        @setState
                            over: null
                            expanded: null


                    style: {
                        padding: "0 #{parseInt(dynamic_spacing * 0.25)}px"
                        fontSize: parseInt(dynamic_spacing * 0.5)
                        fontWeight: 100
                        textShadow: theme.shadows.title
                        textDecoration: 'none'
                        overflow: 'hidden'
                        #remove default button style
                        background: 'transparent'
                        outline: 'none'
                        border: 'none'
                        userSelect: 'none'
                        mixins.transition('0.25s', 'color')...

                    }
                    e 'a',
                        href: href
                        id: item.id + '.item'
                        title: href
                        style:
                            userSelect: 'none'
                            cursor: 'pointer'
                            textDecoration: 'none'
                            color: if @props.bar_mode
                                    if @state.over == item.id
                                        if @state.active == item.id
                                            item.color.brighten 0.6
                                        else
                                            item.color
                                    else
                                        if @state.active == item.id
                                            item.color
                                        else
                                            theme.colors.light
                                else
                                    if @state.over == item.id
                                        item.color.darken 0.3
                                    else
                                        theme.colors.very_dark
                        onClick: (event)->
                            if event.button == 0
                                event.preventDefault()
                        item.title
                    if item.submenu?
                        e SubMenu,
                            item: item
                            expanded: @state.expanded
                            bar_mode: @props.bar_mode
                            hover_shadow: @props.hover_shadow
                            ParentSetState: (state)=> @setState(state)

# sub menu will apear on mouse over the main menu item.
class SubMenu extends React.Component
    constructor: (props={})->
        super props
        @state =
            over: null
    componentDidUpdate: ->
        element = ReactDOM.findDOMNode(@)
        parent = element.parentElement
        rect = parent.getClientRects()[0]
        parent_rect = parent.getClientRects()[0]
        element.style.left = parseInt(parent_rect.left + parent.offsetWidth/2 - element.offsetWidth/2) + 'px'
        rect = parent.getClientRects()[0]
        overflow = parseInt(Math.max(innerWidth - rect.left + rect.width, 0))

    render: ->
        expanded = @props.expanded == @props.item.id
        e 'div',
            id: @props.item.id + 'submenu_container'
            style:{
                position: 'absolute'
                padding: parseInt(mixins.dynamic_spacing * if @props.bar_mode then 0.4 else 0.2)
                opacity: if expanded then 1 else 0
                pointerEvents: if expanded then 'auto' else 'none'
                transform: if expanded then 'scale(1) translate(0, 0)' else "scale(0.75) translate(0, -#{mixins.dynamic_spacing*0.75}px)"
                zIndex:1001
                mixins.transition('0.25s', 'opacity, transform')...
            }
            e 'div',
                id: @props.item.id + '.submenu'
                key: @props.item.id + '.submenu'

                style:{
                    mixins.columnFlex...
                    background: theme.colors.very_dark
                    paddingTop: parseInt(Math.max(mixins.dynamic_spacing * 0.15, mixins.cm*0.3))
                    borderRadius: theme.radius.r2
                    fontSize: parseInt(Math.max(mixins.dynamic_spacing * 0.3, mixins.cm*0.6))
                    fontWeight: 100
                    boxShadow: theme.shadows.long
                }
                for subitem in @props.item.submenu then do (subitem)=>
                    id = @props.item.id + '.' + subitem.id + '.item'

                    text_style =
                        userSelect: 'none'
                        color: if @state.over == subitem.id
                                mixins.chroma(@props.item.color).brighten(0.6)
                            else
                                theme.colors.gray
                        textShadow: if @state.over == subitem.id
                                @props.hover_shadow
                            else
                                theme.shadows.title
                        textDecoration: 'none'

                    e 'div',
                        key: id
                        id: id
                        onClick: (event) =>
                            close_close_sub_menus()
                            if event.target.id == id or event.target.id == id + '.link'
                                if subitem.onClick
                                    subitem.onClick?(event)
                                location.href = subitem.link
                            event.stopPropagation()

                        onMouseOver: (event)=>
                            if event.target.id == id or event.target.id == id + '.link'
                                @setState
                                    over: subitem.id

                        onMouseOut: (event)=>
                            @setState
                                over: null
                        style:
                            paddingBottom: parseInt(Math.max(mixins.dynamic_spacing * 0.15, mixins.cm*0.3))
                            paddingLeft: parseInt(Math.max(mixins.dynamic_spacing * 0.15, mixins.cm*0.3))
                            paddingRight: parseInt(Math.max(mixins.dynamic_spacing * 0.15, mixins.cm*0.3))

                        e 'a',
                            key: id+'.link'
                            id: id+'.link'
                            href: subitem.link
                            title: subitem.link
                            style: text_style
                            onClick: (event)->
                                if event.button == 0
                                    event.preventDefault()
                            subitem.title
