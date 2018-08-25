{theme, mixins, react_utils} = require './common'
{React, ReactDOM} = react_utils
e = React.createElement

{Header} = require './header'
CardManager = require './cards/card_manager'
{load_json} = require '../loader'
card_index_promise = load_json '/index.json'

# UI is a class that contains a promise which is resolved after mount the main_component
# main_component contains all the UI sub components.
class UI
    constructor: ->
        @update = ->
            console.warn '''
            You are trying to update the UI before it is ready.
            Use UI.ready promise to make sure you can use the update function.
            '''

        ui = @
        @ready = new Promise (resolve, reject) ->
            app_element = document.getElementById 'app'
            card_index_promise.then (card_index)->
                MainComponent = class MainComponent extends React.Component
                    componentDidMount: ->
                        app_element.style.opacity = 1
                        ui.update = @forceUpdate
                        element = ReactDOM.findDOMNode(@)
                        resolve(element)

                    render: ->
                        e 'div',
                            id: 'Main container'
                            e 'div',
                                id: 'background'
                                style: {
                                    position: 'fixed'
                                    zIndex: -1000
                                    width: '100vw'
                                    height: '100vh'
                                    background: theme.colors.gray
                                    mixins.transition('1000ms', 'background')...
                                }

                            e Header, {card_index}
                            e CardManager, {card_index}

                # Rendering main_component with ReactDOM in our HTML element `app`
                ReactDOM.render e(MainComponent), app_element

module.exports = new UI
