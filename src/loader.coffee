load_text = (url) -> new Promise (resolve, reject)->
    fetch(url).then (response)->
        if response.ok
            response.text().then (text)->
                resolve text
        else
            console.error "Text file not found:", url
            reject()

load_json = (url) -> new Promise (resolve, reject)->
    fetch(url).then (response)->
        if response.ok
            response.json().then (data)->
                # setTimeout ->
                    resolve data
                # , 1000
        else
            console.error "Json file not found:", url
            reject()

# load_image = require('image-promise')
extension_re = new RegExp /\.[0-9a-z]+$/i
load_image = (url)-> new Promise (resolve, reject)->
    extension = extension_re.exec(url)[0].toLowerCase()[1...]
    if extension in ["mp4", "webm", "ogg", "m4v"]
        element = document.createElement 'video'
        element.addEventListener 'loadeddata', -> resolve element
        element.addEventListener 'error', -> reject 'Failed to load: ' + url
    else if extension == 'gif'
        element = document.createElement 'img'
        console.warn "Loading gif:" + element.src,
            "\nWe can't be sure when the gif is ready to be played. This case is not managed for fixing scroll jumps."
        timeout = setTimeout (-> resolve element), 100
        element.addEventListener 'error', ->
            clearTimeout timeout
            reject 'Failed to load: ' + url
    else
        element = document.createElement 'img'
        element.addEventListener 'load', -> resolve element
        element.addEventListener 'error', -> reject 'Failed to load: ' + url


    element.src = url

load_media = (html_str)-> new Promise (resolve, reject)->
    tmp_div = document.createElement('div')
    tmp_div.innerHTML = html_str
    media = tmp_div.firstElementChild
    type = media.tagName
    switch type
        when 'VIDEO'
            media.addEventListener 'loadeddata', -> resolve media
            media.addEventListener 'error', -> reject 'Failed to load: ' + media.src
        when 'IMG'
            extension = extension_re.exec(media.src)[0].toLowerCase()[1...]
            if extension == 'gif'
                console.warn "Loading gif:" + media.src,
                    "\nWe can't be sure when the gif is ready to be played, so it can cause scroll jumps."
                timeout = setTimeout (-> resolve media), 100
                media.addEventListener 'error', ->
                    reject 'Failed to load: ' + media.src
                    clearTimeout timeout
            else
                media.addEventListener 'load', -> resolve media
                media.addEventListener 'error', -> reject 'Failed to load: ' + media.src
        else
            reject 'Unknown media type: ' + type

module.exports = {load_image, load_media, load_text, load_json}
