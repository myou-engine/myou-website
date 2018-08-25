{mixins, react_utils} = require './common'
{React, ReactDOM} = react_utils
e = React.createElement
{load_image} = require '../loader'

class SlideShow
    # A simple slideshow which can with play and pause functions.
    # each slide is downloaded only when it will be shown.

    constructor: (@id, slide_urls=[], @slide_duration=4, @alignment='center')->
        @_active = 0
        @_initiated = false
        @_playing = false
        @_interval = null

        @resolve_mounted_promise = null
        @mounted_promise = new Promise (resolve, reject)=>
            @resolve_mounted_promise = resolve

        self = @

        @slides = []
        for url in slide_urls
            @slides.push
                url: url
                visible: 0
                href: null
        class SlideComponent extends React.Component

            componentDidMount: ->
                self.slides[@props.index].set_href = (url)=>
                    slide = self.slides[@props.index]
                    if slide.href != url
                        slide.href = url
                        self.mounted and @forceUpdate()

                self.slides[@props.index].set_visibility = (v)=>
                    v = (v and 1) or 0
                    slide = self.slides[@props.index]
                    if slide.visible != v
                        slide.visible = v
                        self.mounted and @forceUpdate()

            render: ->
                slide = self.slides[@props.index]
                e 'div',
                    id: @props.id
                    className: 'Slide'
                    style: {
                        position: 'absolute'
                        top: 0
                        width: '100%'
                        height: '100%'
                        background: do ->
                            if slide.href
                                mixins.bgImg(
                                    #Workaround, it must be fixed in MyoUI
                                    '"' + slide.href + '"'
                                    'transparent'
                                    self.alignment
                                    'cover'
                                )
                            else 'transparent'
                        opacity: slide.visible
                        (mixins.transition '1s', 'opacity')...
                        (mixins.rowFlex)...
                    }

        slide_elements = []

        for slide, n in @slides
            id = self.id + '.' + n
            slide.element = e SlideComponent,
                index: n
                id: id
                key: id

            slide_elements.push slide.element
            slide.loader = ->
                load_image(@url).then =>
                    @set_href @url

        class Component extends React.Component
            componentDidMount: ->
                self.mounted = true
                self.resolve_mounted_promise()
                self._update = =>
                    current_slide = self.slides[self._active]
                    if not current_slide
                        return
                    current_slide.loaded_promise =
                        current_slide.loaded_promise or current_slide.loader()

                    current_slide.loaded_promise.then (url)->
                        current_slide.set_visibility 1
                        for s in self.slides when s != current_slide
                            s.set_visibility 0

                    if self._initiated and self._playing
                        if not self.visible
                            self.visible = 1
                            self.mounted and @forceUpdate()

            componentWillUnmount: ->
                self.mounted = false

            render: ->
                e 'div',
                    className: 'SlideShow'
                    style: {
                        position: 'absolute'
                        width: '100%'
                        height: '100%'
                        overflow: 'hidden'
                        opacity: self.visible
                        pointerEvents: (self.visible and 'all') or 'none'
                        (mixins.transition '1s', 'opacity')...
                    }

                    slide_elements

        @react_element = e Component

    _update: ->
        console.warn 'You are trying to update slideshow before mount it'

    next: =>
        @_active += 1
        if @_active+1 > @slides.length
            @_active = 0
        @_update()
        return


    play: =>
        if @_playing then return
        @_playing = true

        if @slide_duration
            @_interval = setInterval @next, @slide_duration*1000
        @_update()

    pause: =>
        @_playing = false
        clearInterval @_interval

    init: =>
        @_initiated = true
        @initiated_promise = @initiated_promise or @mounted_promise.then =>
            @_update()



module.exports = SlideShow
