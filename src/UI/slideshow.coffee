{mixins, react_utils} = require './common'
{React, ReactDOM} = react_utils
e = React.createElement
{load_image} = require '../loader'

class SlideShow
    # A simple slideshow which can with play and pause functions.
    # each slide is downloaded only when it will be shown.

    constructor: (settings)->
        {id, slide_urls=[], slide_duration=4, alignment='center', fill='cover',force_aspect_ratio=false} = settings
        @id = id
        @slide_duration = slide_duration
        @alignment = alignment
        @fill = fill
        @force_aspect_ratio = force_aspect_ratio
        @_active = 0
        @_initiated = false
        @_playing = false
        @_interval = null
        @parent_height = null
        @slideshow_ref = React.createRef()

        @resolve_mounted_promise = null
        @mounted_promise = new Promise (resolve, reject)=>
            @resolve_mounted_promise = resolve

        self = @

        @slides = []
        @aspect_ratio = 16/9
        @aspect_ratio_callbacks = []
        for url in slide_urls
            @slides.push
                url: url
                visible: 0
                href: null
        class SlideComponent extends React.Component

            componentDidMount: ->
                self.slides[@props.index].set_img = (img_info)=>
                    {url, aspect_ratio} = img_info
                    if @props.index == 0
                        self.aspect_ratio = aspect_ratio
                        aspect_ratio_changed = true
                        console.log 'ASPECT RATIO', aspect_ratio
                    slide = self.slides[@props.index]
                    slide.aspect_ratio = aspect_ratio
                    if slide.href != url
                        slide.href = url
                        href_changed = true
                    if aspect_ratio_changed or href_changed
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
                                    self.fill
                                )
                            else 'transparent'
                        opacity: slide.visible
                        (mixins.transition '1s', 'opacity')...
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
                load_image(@url).then (img)=>
                    @set_img {@url, aspect_ratio:img.width/img.height}
                    console.log 'IMAGEN CARGADA:', img
                    console.log 'RESOLUCION:', img.width, img.height


        self.component = class Component extends React.Component
            componentDidMount: ->
                slideshow_element = self.slideshow_ref.current

                self.mounted = true
                self.resolve_mounted_promise()

                if force_aspect_ratio
                    self.parent_height = slideshow_element.getBoundingClientRect()['height']
                    console.log 'HEIGHT:', self.parent_height
                    @forceUpdate()

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

                addEventListener 'resize', =>
                    slideshow_element = self.slideshow_ref.current
                    self.parent_height = slideshow_element.parentElement.getBoundingClientRect()['height']
                    self.mounted and @forceUpdate()

            componentWillUnmount: ->
                self.mounted = false

            render: ->
                style = @props.style or {}
                width = height = '100%'
                if self.force_aspect_ratio and self.parent_height
                    height = self.parent_height + 4 #I don't know why I need theese 4px extra
                    width = self.parent_height * self.aspect_ratio

                e 'div',
                    className: 'SlideShowContainer'
                    ref: self.slideshow_ref
                    style: {
                        position: 'absolute'
                        width
                        height
                        opacity: self.visible
                        pointerEvents: (self.visible and 'all') or 'none'
                        (mixins.transition '1s', 'opacity')...
                        style...
                    }
                    e 'div',
                        className: 'SlideShow'
                        style: {
                            height: '100%'
                            width: '100%'
                            overflow: 'hidden'
                        }

                        slide_elements
                    @props.children


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
