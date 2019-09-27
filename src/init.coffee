# Promise polyfill
if not Promise? then window.Promise = require 'prms'
# fetch polyfill
if not fetch? then window.fetch = require('unfetch').default

# Default basic styles
body = document.body
body.style.minHeight = "100vh"
body.style.margin = 0

app = document.getElementById('app')
app.style.width = '100%'
app.style.height = '100vh'
app.style.opacity = '0'
app.style.transitionDuration = '2s'
app.style.transitionProperty = 'opacity'

# Deleting default card
static_page = document.getElementById('static_page')
if static_page
    body.removeChild(static_page)

{css_utils} = require './UI/common'

# Adding highlight css
css_utils.add_css require './UI/css/hl.css'

# setting OpenSans font-family as global myoui style
css_utils.add_css '''
    .myoui * {
        font-family: 'Roboto', 'sans-serif';
      }
    .myoui {
        font-family: 'Roboto', 'sans-serif';
      }

    h1 {
    	font-family: "Roboto";
    	font-style: normal;
    	font-variant: normal;
    	font-weight: 500;
    }
    h3 {
    	font-family: "Roboto";
    	font-style: normal;
    	font-variant: normal;
    	font-weight: 500;
    }
    p {
        font-family: "Roboto";
    	font-style: normal;
    	font-variant: normal;
    	font-weight: 300;
    }
    li {
        font-family: "Roboto";
    	font-style: normal;
    	font-variant: normal;
    	font-weight: 300;
    }
    blockquote {
        font-family: "Roboto";
    	font-style: normal;
    	font-variant: normal;
    	font-weight: 400;
    }
    pre {
        font-family: "Roboto";
    	font-style: normal;
    	font-variant: normal;
    	font-weight: 400;
    }
    '''

ui = require './UI/main'
