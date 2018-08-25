{react_utils} = require '../../src/UI/common'
{React} = react_utils
e = React.createElement

class Link extends React.Component

    render: ->
        {href, title, children} = @props
        e 'a',
            className: 'link'
            href: href
            title: title or href
            style:
                textDecoration: 'none'
            children

module.exports = Link
