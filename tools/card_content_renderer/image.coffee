{theme, mixins, react_utils} = require '../../src/UI/common'
{React} = react_utils
e = React.createElement

class Image extends React.Component

    render: ->
        {src, title, alt} = @props

        style_re = new RegExp /{.*}/g
        extension_re = new RegExp /\.[0-9a-z]+$/i

        # NOTE: you can add extra style options by adding a JSON object inside
        # alt text in the markdown file.
        # EG:
        # ![Alt text{"width":"100%"}](path/to/the/image.jpg)

        alt = alt.replace(/\n/g,'')

        options =
            content: {}
            container: {}
            controls: false
            autoPlay: true
            loop: true
            muted: true

        # Parsing options
        o = style_re.exec(alt)
        o = (o and o[0]) or "{}"
        o = JSON.parse o

        for k,v of o
            options[k]=v

        alt = alt.split(style_re)[0]

        if alt.startsWith("applet:")
            alt = alt[7...]
            is_applet = true

        extension = extension_re.exec(src)[0].toLowerCase()[1...]
        is_video = extension in ["mp4", "webm", "ogg", "m4v"]

        content_style =
            maxWidth: '100%'
            position: 'relative'
            borderRadius: theme.radius.r1
            boxShadow: 'rgba(0, 0, 0, 0.2) 0px 4px 10px, rgba(0, 0, 0, 0.2) 0px 0px 5px'
        for k,v of options.content
            content_style[k]=v

        container_style =
            background: 'rgba(0,0,0,0)'
            position: 'relative'
        for k,v of mixins.rowFlex
            container_style[k] = v
        container_style.justifyContent = 'center'
        for k,v of options.container
            container_style[k]=v

        if is_applet
            canvas_style =
                position: 'absolute'
                left: 0
                opacity: 0
                width: '100%'
                height: '100%'
                borderRadius: theme.radius.r1
                boxShadow: 'rgba(0, 0, 0, 0.2) 0px 4px 10px, rgba(0, 0, 0, 0.2) 0px 0px 5px'
            fs_button_style =
                position: 'absolute'
                bottom: '0.5cm'
                right: '0.5cm'
                width: '0.75cm'
                height: 'auto'
                opacity: 0
            for k,v of mixins.transition('1s', 'opacity')
                canvas_style[k] = v
                fs_button_style[k] = v

        e 'div',
            className: if is_applet then '' else 'ExpandableContent' 
            style: container_style

            if is_video
                e 'video',
                    id: src
                    controls: options.controls
                    autoPlay: options.autoPlay
                    loop: options.loop
                    muted: options.muted
                    src: src
                    title: title
                    alt: alt
                    style: content_style
            else
                e 'img',
                    id: src
                    src: src
                    title: title
                    alt: alt
                    style: content_style

            if is_applet
                e 'canvas',
                    id: alt
                    title: title
                    style: canvas_style



module.exports = Image
