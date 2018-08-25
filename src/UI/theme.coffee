{Theme, mixins, css_utils} = require "myoui"

theme = new Theme
mixins.cm = theme.dynamic_spacing = 38

# custom mixins
mixins.smooth_gradient = (settings={})->
    {to ='bottom', a='white', b='black', start=0, end=100, steps=10} = settings
    step = (end-start)/steps
    result = "linear-gradient( to #{to}, "
    gradient_steps = for i in [0..steps]
        factor = (-Math.cos(Math.PI * i/steps) + 1)/2
        color = mixins.chroma.mix(a,b,factor).css()
        "#{color} #{start + step*i}%"
    result += gradient_steps.join(', ') + ')'
    return result

mixins.random_color = (r,g,b)->
    random_channel = -> parseInt(Math.random()*255)
    return "rgb(#{r or random_channel()}, #{g or random_channel()}, #{b or random_channel()})"

# Updating screen size dependent theme properties
if document?
    # getting resolution in pixels/cm
    resolution_element = document.createElement 'DIV'
    resolution_element.id="resolution"
    resolution_element.style.width="1cm"
    document.body.appendChild resolution_element
    mixins.cm = resolution_element.clientWidth

    # custom css
    css_utils.add_css require './css/animations.css'

    update_sizes = ->
        mixins.min_side_length = Math.min(innerHeight,innerWidth)
        mixins.dynamic_spacing = Math.floor(Math.min(Math.max(mixins.min_side_length*0.1, 1.5*mixins.cm), innerWidth*0.1))
    update_sizes()
    window.addEventListener 'resize', update_sizes

# customizing theme
theme.shadows.title = "0px 1px 8px rgba(0,0,0,0.2), 0px 1px 1px rgba(0,0,0,0.2)"
theme.shadows.title_strong = "0px 1px 15px rgba(0,0,0,1), 0px 1px 4px rgba(0,0,0,0.6)"
theme.shadows.title_regular = "0px 1px 15px rgba(0,0,0,0.6), 0px 1px 4px rgba(0,0,0,0.4)"
theme.shadows.box = 'rgba(0, 0, 0, 0.2) 0px 4px 30px,
                    rgba(0, 0, 0, 0.2) 0px 0px 10px'
theme.card = {
    fontFamily: 'Roboto, sans-serif'
    color: theme.colors.t1
    overflow: 'hidden'
    maxWidth: "90vw"
    background: theme.colors.light
    borderRadius: theme.radius.r2
    boxShadow: theme.shadows.box
    mixins.transition('0.25s', 'opacity')...
}

if document?
    custom_theme = require '../content/custom_theme' # custom theme customization
    theme.logo = custom_theme.logo
    theme.category_colors = cat_cols = custom_theme.category_colors or {}
    for k,col of cat_cols when col.startsWith 'myou.'
        col = theme.colors[col[5...]]
        cat_cols[k] = col

module.exports = theme
