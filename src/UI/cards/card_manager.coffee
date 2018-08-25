{
    theme, mixins, react_utils,
    TimeLimitedEventListener,
    get_tag_from_path
} = require '../common'
{React, ReactDOM} = react_utils
e = React.createElement

main_menu = require '../main_menu'
header = require '../header'
Card = require './card'

cards =
    article: require './article'
    feature: require './feature'
    spotlight: require('./spotlight').Spotlight
    category: require './category_title'

# If enabled, the hash will not change while its related card is visible.
# if the card is not visible, the has protection will be disabled.
protected_tag = null
protect_tag = (tag=get_tag_from_path())->
    protected_tag = tag

class CardManager extends React.Component
    # CardManager will contain some cards and will manage when init them and
    # which chunk of cards must be rendered according the scroll state.
    create_cards_from_index: (index, path)->
        for i in index.children ? []
            if i.type == 'link' #Skip links, which only have to be used in main_menu
                continue
            if path
                ipath = path+'/'+i.id
            else
                ipath = i.id
            @cards.push new cards[i.type] ipath, i.attributes
            @create_cards_from_index i, ipath


    constructor: (props={})->
        super props
        @cards = @props.cards or []
        if @props.card_index
            @create_cards_from_index @props.card_index, ''
        @cards.unshift header.header_card
        footer = new Card 'footer', React.createElement 'div',
            key: 'footer'
            style:
                height: '60vh'

        footer.on_init = -> Promise.resolve()
        footer.ignore_anchor = true

        @cards.push footer
        @card_tags = []
        @cards_by_tag = {}

        for card in @cards
            if card.tag in @card_tags
                console.warn 'Ignoring duplicated card tag:', card.tag
                continue
            card.card_manager = @
            @card_tags.push card.tag
            @cards_by_tag[card.tag] = card

        @_previous_chunk_promise = Promise.resolve()

        # The hash will change depending on the visual weight of the cards on screen.
        # Winner color is the category color of the card with higher visual weight.
        @_winner_color = theme.category_colors[undefined]
        @_cards_on_screen = []

        # if hash is manually changed, goto will be executed.
        addEventListener 'hashchange', (event)=>
            hash_protected = null
            event.preventDefault()
            new_url = event.newURL
            path = new_url.split('#')[1]
            path = path or ''
            console.log 'has changed to ', location.hash, path
            if path
                history.replaceState undefined, undefined, '/' + path + '/'
            else
                history.replaceState undefined, undefined, '/'
            @goto path, {expanded: true}

        tag = get_tag_from_path()
        if location.hash
            history.replaceState undefined, undefined, '/' + tag + '/'

        @goto tag, {expanded: true}
        @_init_card_sensor()

    _init_card_sensor: ->
        @_cards_on_screen_sensor = new TimeLimitedEventListener 100, =>
            # it is a TimeLimitedEventListener, which means that it will be called
            # no more than once every 100 miliseconds if the event trigger is being
            # executed (scroll in this case).

            # searchin cards on screen.
            @_cards_on_screen.splice 0
            cos = '-------------\n'
            for tag in @_get_chunk_that_contains(get_tag_from_path())
                c = @cards_by_tag[tag]
                is_on_screen = c.check_is_on_screen()
                if  is_on_screen
                    @_cards_on_screen.push c
                    cos += c.tag + '\n'

                # If the card with tag equal to protected_tag is not on screen
                # then disable hash protection
                #TODO: manage header

                if c.tag == protected_tag and not is_on_screen
                    protected_tag = null

            winner_w = 0
            winner = null

            # Checking which card has higher visual weight and change the hash and bg color.
            for c in @_cards_on_screen
                vw = c.get_visual_weight()
                if vw >= winner_w
                    winner = c
                    winner_w = vw

            if winner
                new_color = theme.category_colors[winner.category]
                if not header.is_bar_mode()
                    new_color = theme.category_colors[undefined]

                #background is global. TODO: fix it
                if background and new_color != @_winner_color
                    @_winner_color = new_color
                    background.style.background = new_color

                if winner.category != last_winner_category
                    last_winner_category = winner.category
                    main_menu.set_active_category winner.category

                # tag protection system
                if not protected_tag
                    tag = winner.tag

                    if not header.is_bar_mode()
                        tag = ''
                    if tag != 'footer'
                        path = ''
                        if tag then path = '/' + tag + '/'
                        history.replaceState undefined, undefined, path
                        document.title = winner.title or winner.metadata?.title or winner.settings?.title or tag or 'myou.cat'
        .event_sensor
        # Triggering cards_on_screen_sensor every scroll event.
        addEventListener 'scroll', =>
            @_cards_on_screen_sensor()
        requestAnimationFrame => @_cards_on_screen_sensor()

    _init_chunk: (tag, before=0, after=0, first_card_options={}, other_cards_options={})->
        {card_tags, cards_by_tag, cards} = @
        ###
        We will init the cards following this pattern:
        [n, n+1, n-1, n+2, n-2...] where n is the index of the first card to init
        n+i must be a number between max(0,before) and min(cards.length, after)

        Examples:
        If n = 10, before = 4, after = 3, cards.length = 20.
        The order will be: [10, 11, 9, 12, 8, 13, 7, 6]

        If n = 3, before = 4, after = 4, cards.length = 5
        The order will be: [3, 4, 2, 1, 0]

        if n = 0, before = 3, after = 3, cards.length = 5
        the order will be: [0, 1, 2]

        So, when we are talking about the first card of the chunk,
        we mean the card with index n (10 in the first example).
        And when we are talking about the last card of the chunk,
        we mean the last card of the order (6 in the first example).
        ###

        # This promise will be resolved when the
        # first card of the chunk has been initiated
        resolve_first_card = null
        first_card = new Promise (resolve, reject)->
            resolve_first_card = resolve
        # this promise will be resolved when the
        # last card of the chunk has been initiated
        resolve_full_chunk = null
        full_chunk = new Promise (resolve, reject)->
            resolve_full_chunk = resolve
        # the new chunk must be initiated immediately after
        # the previous chunk has been completely initiated.
        @_previous_chunk_promise.then =>
            index = card_tags.indexOf tag
            # if card tag doesn't exist, init the first card
            if index < 0
                index = 0
                tag = card_tags[0]
            # here current_card is a promise which will be resolved when
            # the first card of the chunk has been initiated.
            current_card = cards_by_tag[tag].init(first_card_options).then (card)=>
                @update_and_fix_jump =>@forceUpdate()
                resolve_first_card(card)

            # chain of promises
            for i in [1...Math.max(before, after)+1]
                pre = index-i
                if i <= after and post < cards.length
                    card = cards[post]
                    if card.initiated
                        continue
                    do (card)=>
                        current_card = current_card.then =>
                            card.init(other_cards_options).then (card)=>
                                #TODO: move it to Card
                                @update_and_fix_jump(=>@forceUpdate())
                                card
                post = index+i
                if i <= before and pre >= 0
                    card = cards[pre]
                    if card.initiated
                        continue
                    do (card)=>
                        current_card = current_card.then ->
                            card.init(other_cards_options)

            # here current_card is a promise which will be resolved when
            # the last card of the chunk has been initiated
            current_card.then (card)->
                resolve_full_chunk(card)

        @_previous_chunk_promise = full_chunk

        return {first_card, full_chunk}

    # A card chunck is a list of cards which are consecutively
    # initiated without uninitiated cards between them.
    _get_chunk_that_contains: (tag)->
        tag = tag or @cards[0].tag
        # It will return an array of card tags
        chunks = []
        current_chunk_index = 0
        required_chunk = 0

        for card in @cards
            if chunks.length == current_chunk_index
                chunks.push []
            if card.initiated
                if card.tag == tag
                    required_chunk = current_chunk_index
                chunks[current_chunk_index].push card.tag
            else
                if chunks[current_chunk_index].length
                    current_chunk_index += 1

        return chunks[required_chunk] or []

    # It will init n number of cards avobe the card on the top
    # of the specified card chunk
    _init_above: (n=1)=>
        for tag in @_get_chunk_that_contains(get_tag_from_path()) when tag?
            c = @cards_by_tag[tag]
            if c.initiated
                top_card = c
                break
        if top_card
            @_init_chunk(top_card.tag, n, 0)

    # It will init n number of cards avobe the card on the bottom
    # of the specified card chunk
    _init_below: (n=1)=>
        for tag in @_get_chunk_that_contains(get_tag_from_path()) when tag?
            c = @cards_by_tag[tag]
            if c.initiated
                bottom_card = c

        if bottom_card
            @_init_chunk bottom_card.tag, 0, n

    render: ->
        card_chunk = @_get_chunk_that_contains get_tag_from_path()
        header_tag = @cards[0].tag
        footer_tag = @cards[@cards.length - 1].tag
        e 'div',
            id: 'InfiniteScroll'
            style: {
                mixins.columnFlex...
                width: '100%'
                paddingBottom: 20
                minHeight: 0
                minWidth: 0
            }

            e LoadingIcon,
                key:'loading_top'
                color: @_winner_color
                init_more: @_init_above
                should_enable: =>
                    tag = get_tag_from_path()
                    (tag != header_tag or tag not in @card_tags) and (card_chunk[0] != header_tag)

            for tag in card_chunk
                @cards_by_tag[tag].react_element

            e LoadingIcon,
                key:'loading_bottom'
                color: @_winner_color
                init_more: @_init_below
                should_enable: -> card_chunk.length and card_chunk[card_chunk.length-1] != footer_tag

    # Goto will init the card where we can go and then will change the scroll
    # to set the card on the top of the screen.
    # It should be called each manual hash change or when following a link to an anchor.
    goto: (tag=location.hash[1...], options)->
        console.log '-------------------------------------\nGO TO: ' + tag + '\n-------------------------------------'
        tag = tag or @cards[0].tag
        if not @cards_by_tag[tag]?
            console.warn 'No tag found: "' + tag + '"'
            tag = @cards[0].tag

        {first_card, full_chunk} = @_init_chunk(tag, 4, 4, options)

        full_chunk.then =>
            console.log 'full chunk loaded.',
        first_card.then (card)=>
            protect_tag(tag)
            card.mounted_promise.then ->
                console.log 'first card loaded and mounted: ', card.tag
                # we need requestAnimationFrame because react
                # will create the card on the next frame.
                requestAnimationFrame ->
                    target = document.getElementById tag
                    if not target
                        console.warn 'element', tag, 'not found'
                        return

                    console.log "scrolling to", tag
                    scrollTo 0, (mixins.getScrollTop() + target.getBoundingClientRect().top)
                    document.title = card.title or card.metadata?.title or card.settings?.title or card.tag or 'myou.cat'

                    header.update()
                    card.on_goto?()

    # this function will update the component and fix scroll jumps if necessary.
    # it should be called after any change which modifies the height
    # of the infinite_scroll component. EG: new children added/removed/height changed
    # NOTE: this function must be called on every component update which could
    # push down other cards.
    update_and_fix_jump: (update_function)->
        tag = location.hash[1...] or @cards[0].tag

        if not location.hash
            pathname = location.pathname
            path = pathname[1...location.pathname.length - 1]
            history.replaceState undefined, undefined, '/#' + path
            tag = path

        active_card = document.getElementById tag

        #TODO: Check if it stills being necessary
        if not active_card
            update_function()
            if pathname
                history.replaceState undefined, undefined, pathname
            return

        old_top = active_card.getBoundingClientRect().top
        update_function()
        scroll_jump = active_card.getBoundingClientRect().top - old_top
        if scroll_jump
            scrollBy 0, scroll_jump

        if pathname
            history.replaceState undefined, undefined, pathname

# loading_icon is a component which will be rendered when there are cards which
# are not loaded yet. And when this icon is on screen, it will load more cards.
class LoadingIcon extends React.Component
    constructor: (props={})->
        super props
        @state = {}

    componentDidMount: ->
        addEventListener 'resize', =>
            @setState(enabled:@props.should_enable())
        on_screen_sensor = new TimeLimitedEventListener 100, =>
            # It returns true if the card is being displayed on the screen
            element = ReactDOM.findDOMNode(@)
            if element
                rect = element.getBoundingClientRect()
                t = top = rect.top
                bottom = top + rect.height
                if 0 <= bottom and top <= innerHeight
                    on_screen = true
            if on_screen
                @props.init_more 4

            @setState
                enabled: @props.should_enable()
                color: background.style.background
        .event_sensor
        on_screen_sensor()
        addEventListener 'scroll', on_screen_sensor

    componentWillUnmount: ->
        @_mounted = false

    shouldComponentUpdate: (new_props, new_state)->
        @state.enabled != @props.should_enable() or @state.color != new_state.color

    render: ->
        size = Math.floor(Math.min(mixins.dynamic_spacing, 1.75*mixins.cm))
        enabled = @state.enabled
        e 'div',
            id: @props.id
            className: 'loading_icon_container'
            style:
                width: size
                height: (enabled and size) or 0
                pointerEvents: 'none'
                padding: (enabled and size * 0.05) or 0
                borderRadius: '100%'
                background: 'white'
                margin: (enabled and size*2) or 0
                opacity: (enabled and 1) or 0
                boxShadow: theme.shadows.box

            if enabled
                e LoadingSpinner, color: @state.color

# this is the visual representation of the loading icon.
# It is a svg animated spinner.
class LoadingSpinner extends React.Component
    render: ->
        # NOTE: This icon is based on the work at
        # https://codepen.io/jczimm/pen/vEBpoL
        e 'svg',
            className: 'loading_icon'
            viewBox: "25 25 50 50"
            style:
                animation: 'spin 2s linear infinite'

            e 'circle',
                className: 'path'
                cx: '50'
                cy: '50'
                r: '20'
                fill: 'none'
                strokeWidth: '5'
                strokeMiterlimit: '10'
                style:
                    stroke: @props.color
                    strokeDasharray: '1, 200'
                    strokeDashoffset: '0'
                    strokeLinecap: 'round'
                    animation: 'dash 1.5s ease-in-out infinite'

module.exports = CardManager
