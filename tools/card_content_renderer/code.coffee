{theme, mixins, react_utils} = require '../../src/UI/common'
{React} = react_utils
e = React.createElement

highlight = require('codemirror-highlight-node')

themeName = 'myou'

# This renderer could not be used on the client side.
class CodeBlock extends React.Component
    render: ->
        lines = highlight(@props.value, @props.language or 'plain').split('\n')
        e 'div',
            className: "CodeMirror cm-s-#{themeName or 'default'}"
            style:
                borderRadius: theme.radius.r1
                background: mixins.chroma(theme.colors.light).darken(0.2)
                padding: "0.6cm"
                boxShadow:'
                    inset rgba(0, 0, 0, 0.2) 0px 0px 5px,
                    inset rgba(0, 0, 0, 0.1) 0px 0px 40px
                    '
                textShadow: '1px 1px 0 rgba(255,255,255,0.3)'

            e 'div', {className: "CodeMirror-scroll", draggable: "false", style: overflow: 'auto'},
                e 'div', {className: "CodeMirror-sizer"},
                    e 'div', {className: "CodeMirror-lines"},
                        e 'div', {className: "CodeMirror-code"},
                            for line,i in lines
                                if 0 #line numbers
                                    [
                                        e 'div', {className: "CodeMirror-gutter-wrapper"},
                                            e 'div', {className: "CodeMirror-linenumber CodeMirror-gutter-elt"}, i
                                        e 'div', {style: {whiteSpace: 'pre'}, dangerouslySetInnerHTML: {__html: line}}
                                    ]
                                else
                                    e 'div', {style: {whiteSpace: 'pre'}, dangerouslySetInnerHTML: {__html: line}}

module.exports = CodeBlock
