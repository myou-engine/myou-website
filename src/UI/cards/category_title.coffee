{theme, mixins, react_utils} = require '../common'
{React} = react_utils
e = React.createElement

{load_json} = require '../../loader'
Card = require './card'

# This card is very simple, it only contains the title of a category.
class Category extends Card
    constructor: (tag, settings)->
        super tag
        @settings = settings

    create_card: ->
        self = @
        class CategoryComponent extends React.Component
            render: ->
                e 'div',
                    className: "category"
                    id: self.tag + '.category'
                    style: {
                        mixins.columnFlex...
                        width: '100%'
                        overflow: 'hidden'
                        paddingBottom: self.text and 20 or 0
                    }

                    if self.text
                        href = '#' + self.tag
                        e 'a',
                            href: href
                            title: href
                            className: 'category_title'
                            style:
                                textAlign: 'center'
                                color: 'white'
                                fontSize: '2.5cm'
                                fontFamily: 'Roboto'
                                fontWeight: 100
                                textShadow: theme.shadows.title
                                textDecoration: 'none'
                            self.text
        super e CategoryComponent

    on_init: ->
        if @settings?.title?
            @title = @text = @settings.title
        else
            l = @tag.split('/')
            @title = @text = l[l.length-1]
        if not @text
            @no_margin = true
        @create_card()
        Promise.resolve()

module.exports = Category
