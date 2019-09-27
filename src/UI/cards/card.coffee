{mixins, react_utils} = require '../common'
{React, ReactDOM} = react_utils
e = React.createElement

# Card is a object which contains a react_element (to be rendered)
# And some functions and promises to know the visibility state of the element.
class Card
    constructor: (@tag, @child=null, @style={})->
        split_index = @tag.indexOf('/')
        if split_index > -1
            @category = @tag[0...split_index]
        else
            @category = @tag

        @is_on_screen = false
        @_on_screen_callbacks = []
        @_out_of_screen_callbacks = []

        @_restore_promises()

        @card_manager = null # To be filled in CardManager constructor

        if @child
            @create_card(@child)

    _restore_on_screen_promise: ->
        # on_screen_promise is resolved if
        #component is mounted and it is on screen
        @on_screen_promise = Promise.all [
            new Promise (resolve, reject)=>
                # this promise resolverd is saved on @
                # to be resolved on check_is_on_screen
                @_resolve_on_screen_promise = =>
                    console.log 'on screen:', @tag
                    resolve(arguments)
            @mounted_promise
        ]

    _restore_mounted_promise: ->
        @mounted_promise = new Promise (resolve, reject)=>
            # this promise resolver is saved on @
            #to be resolved on componentDidMount
            @_resolve_mounted_promise = =>
                console.log 'mounted:', @tag
                resolve(arguments)

    _restore_promises: ->
        @_restore_mounted_promise()
        @_restore_on_screen_promise()

    create_card: (child=@child)->
        card = @
        # React element is a instance of a component.
        class CardComponent extends React.Component
            constructor: (props={})->
                super props
                @state = {opacity:0}

            componentDidMount: ->
                card._resolve_mounted_promise()
                card.forceUpdate = => @forceUpdate()
                card.check_is_on_screen()
                @mounted = card.mounted = true
                clearTimeout card.tiemout_to_unhide
                card.timeout_to_unhide = setTimeout =>
                    if @mounted
                        @setState opacity:1
                ,100

            componentWillUnmount: ->
                @mounted = card.mounted = false
                console.log 'Unmounting', card.tag
                card._restore_promises()
                card._set_out_of_screen()
                
            shouldComponentUpdate: ->
                not @state.opacity

            render: ->
                padding = if card.no_margin then 0 else Math.min 0.025 * innerWidth, mixins.cm
                margin = if card.no_margin then 0 else Math.min 0.05 * innerWidth, mixins.cm
                e 'div',
                    id: card.tag + '.container'
                    key: card.tag + '.container'
                    style: {
                        mixins.columnFlex...
                        mixins.transition('1s', 'opacity')...
                        position: 'relative'
                        alignItems: 'center'
                        height: if card.adjust_to_container then '100%' else 'auto'
                        width: if card.adjust_to_container then '100%' else '28cm'
                        maxWidth: "90vw"
                        paddingTop: padding
                        marginTop: margin
                        opacity: @state.opacity or 0
                        fontFamily: 'OpenSans, sans-serif'
                        fontWeight: 300
                        # transform: if @state.opacity then 'scale(1)' else 'scale(1.05)'
                        card.style...
                    }
                    e 'div', # this is the actual anchor of the card
                        id: card.tag
                        key: card.tag + Math.random()
                        name: card.tag
                        style: {
                            position: 'relative'
                            top: - margin - padding - mixins.cm *1.5 # this is the height of the menu bar
                        }
                    child

        @react_element = e CardComponent, key:@tag

    # This function will be overwritten on componentDidMount
    forceUpdate = ->
        console.warn 'You are trying to update the CardComponent before mount it'

    add_on_screen_callback: (c)=>
        if @_on_screen_callbacks.indexOf(c) > -1
            return
        @_on_screen_callbacks.push c

    add_out_of_screen_callback: (c)=>
        if @_out_of_screen_callbacks.indexOf(c) > -1
            return
        @_out_of_screen_callbacks.push c

    remove_on_screen_callback: (c)=>
        index = @_on_screen_callbacks.indexOf(c)
        if index > -1
            @_on_screen_callbacks.splice index, 1

    remove_out_of_screen_callback: (c)=>
        index = @_out_of_screen_callbacks.indexOf(c)
        if index > -1
            @_out_of_screen_callbacks.splice index, 1

    init: (args...)->
        # if @_init_promise exists then use it, else create it.
        @_init_promise = @_init_promise or @on_init args...
        return @_init_promise.then =>
            @initiated = true
            return @

    _set_on_screen: -> if not @is_on_screen
        for c in @_on_screen_callbacks
            c()
        @_resolve_on_screen_promise()
        @is_on_screen = true

    _set_out_of_screen: -> if @is_on_screen
        @_restore_on_screen_promise()
        for c in @_out_of_screen_callbacks
            c()
        @is_on_screen = false

    check_is_on_screen: =>
        # It returns true if the card is being displayed on the screen
        element = document.getElementById @tag+'.container'
        if element
            rect = element.getBoundingClientRect()
            top = rect.top
            bottom = top + rect.height
            if 0 <= bottom and top <= innerHeight
                @_set_on_screen()
            else
                @_set_out_of_screen()
        else
            @_set_out_of_screen()
        return @is_on_screen

    get_visual_weight: ->
        # Visual weight is a value between 0 and 1
        # it depends on the distance of the card to the screen_center* and
        # the area on screen of the card.

        element = document.getElementById @tag + '.container'
        if not element
            return 0

        rect = element.getBoundingClientRect()

        top = rect.top
        bottom = top + rect.height

        # screen center is moved to innerHeight*0.4 because this value is
        # much more intuitive for the user. #TODO: rename this variable.
        screen_center = innerHeight*0.4
        visible_top = Math.max(top, 0)
        visible_bottom = Math.min(bottom, innerHeight)
        visible_height = visible_bottom - visible_top

        visible_ratio = Math.max(visible_height,0)/innerHeight
        tc_prox = screen_center-top
        bc_prox = screen_center-bottom
        if tc_prox >= 0 and bc_prox <= 0
            center_proximity = 0
        else
            center_proximity = Math.min(Math.abs(tc_prox),
                Math.abs(bc_prox))/innerHeight

        visual_weight = visible_ratio*0.2 + (1-center_proximity)*0.8
        # Uncomment following line to debug
        # element.children[0].children[0].style.background = "rgb(#{parseInt(visual_weight*255)},255,255)"
        return visual_weight



module.exports = Card
