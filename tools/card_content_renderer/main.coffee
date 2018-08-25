
{react_utils} = require '../../src/UI/common'
{React} = react_utils

markdown = React.createFactory require('react-markdown')
ReactDOMServer = require('react-dom/server')

renderers =
    link: require './link'
    image: require './image'

if not window?
    # This kind of renderer will not be called if it is being executed
    # on the client side.
    renderers.code = require './code'
    # TODO: renderers.inlineCode = require './renderers/inline_code'

image_path_resolver = (node, props) ->
    if node.type == 'image'
        node.url = props.base_url+node.url
        node.url = node.url.replace '//', '/'
    if node.children?
        for c in node.children
            image_path_resolver c, props
    return node

module.exports = (source, base_url="./")->
    # It will return a HTML as string from a markdown formated source.
    # base_url is to make paths of markdown files relative to base_url
    ReactDOMServer.renderToString  markdown
        source: source
        renderers: renderers
        astPlugins: [image_path_resolver]
        base_url: base_url
        escapeHtml: false
