{MyoUI, mixins, react_utils, css_utils} = require 'myoui'
# adding default css code to the document
if document?
    require 'myoui/default_fonts'
    require 'myoui/default_animations'

# custom theme
theme = require './theme'

# myoui instance
myoui = new MyoUI theme

if document? # moment could be used only in the client side.
    moment = require('moment/src/moment').default

class TimeLimitedEventListener
        # its purpose is to execute listeners only if event has ocurred on a certain time
    constructor: (@timer, listener)->
        last_event_time = 0

        # Detecting if a event has ocurred
        event_has_occurred = false
        @event_sensor = (@event)=>
            event_has_occurred = true

        # execute listener only if last_event_time > @timer and event has ocurred
        limited_listener = =>
            now = Date.now()
            if now - last_event_time > @timer and event_has_occurred
                last_event_time = now
                event_has_occurred = false
                listener(@event)
            requestAnimationFrame limited_listener
        limited_listener()

# getting scrollTop compatible with IE
mixins.getScrollTop = ->
    return if scrollY?
        scrollY
    else
        document.body.parentElement.scrollTop #IE quirk

mixins.getDocumentHeight = ->
    if document?
        body = document.body
        html = document.documentElement
        return Math.max body.scrollHeight, body.offsetHeight,
            html.clientHeight, html.scrollHeight, html.offsetHeight
    else
        console.warn 'Document does not exist.'
        return 0

mixins.color_to_chroma = (color, category)->
    color = color or 'auto'
    # split in first "."
    [_,color,chroma_function] = color.match(/^([^.]+)(\..*)?/)
    if color of theme.colors
        color = theme.colors[color]
    else if color of theme.category_colors
        color = theme.category_colors[color]
    else if color == 'auto' and category?
        color = theme.category_colors[category]
    if chroma_function
        color_expression = "mixins.chroma('#{color}').#{chroma_function[1...]}"
        return eval color_expression
    else
        return mixins.chroma color

get_tag_from_path = ->
    if location.hash
        tag = location.hash[1...]
    else if location.pathname and location.pathname != '/'
        tag = location.pathname[1...location.pathname.length-1]

module.exports = {
    theme, mixins, react_utils, css_utils, moment,
    TimeLimitedEventListener, get_tag_from_path
}
