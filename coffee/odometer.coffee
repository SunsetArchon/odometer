DIGIT_HTML = '<span class="odometer-digit"><span class="odometer-digit-spacer">8</span><span class="odometer-digit-inner"></span></span>'
RIBBON_HTML = '<span class="odometer-ribbon"><span class="odometer-ribbon-inner"></span></span>'
VALUE_HTML = '<span class="odometer-value">{value}</span>'
FORMAT_MARK_HTML = '<span class="odometer-formatting-mark">{char}</span>'
DIGIT_FORMAT = ',ddd'

# What is our target framerate?
FRAMERATE = 60

# How long will the animation last?
DURATION = 2000

# What is the fastest we should update values when we are
# counting up (not using the wheel animation).
COUNT_FRAMERATE = 20

# What is the minimum number of frames for each value on the wheel?
# We won't render more values than could be reasonably seen
FRAMES_PER_VALUE = 2

# If more than one digit is hitting the frame limit, they would all get
# capped at that limit and appear to be moving at the same rate.  This
# factor adds a boost to subsequent digits to make them appear faster.
DIGIT_SPEEDBOOST = .5

MS_PER_FRAME = 1000 / FRAMERATE
COUNT_MS_PER_FRAME = 1000 / COUNT_FRAMERATE

TRANSITION_END_EVENTS = 'transitionend webkitTransitionEnd oTransitionEnd otransitionend MSTransitionEnd'
TRANSITION_SUPPORT = document.createElement('div').style.transition?

renderTemplate = (template, ctx) ->
  template.replace /\{([\s\S]*?)\}/gm, (match, val) ->
    ctx[val]

createFromHTML = (html) ->
  el = document.createElement('div')
  el.innerHTML = html
  el.children[0]

now = ->
  performance?.now() ? +new Date

class Odometer
  constructor: (@options) ->
    for k, v in Odometer.options
      if not @options[k]?
        @options[k] = v

    @value = @cleanValue(@options.value ? '')
    @el = @options.el

    @inside = document.createElement 'div'
    @inside.className = 'odometer-inside'
    @el.innerHTML = ''
    @el.appendChild @inside

    @options.format ?= DIGIT_FORMAT
    @options.format or= 'd'

    @options.duration ?= DURATION
    @MAX_VALUES = ((@options.duration / MS_PER_FRAME) / FRAMES_PER_VALUE) | 0

    @render()

    for property in ['HTML', 'Text']
      do (property) =>
        Object.defineProperty @el, "inner#{ property }",
          get: =>
            @inside["outer#{ property }"]

          set: (val) =>
            @update @cleanValue val

    @

  cleanValue: (val) ->
    val.toString().replace /[.,]/g, ''

  bindTransitionEnd: ->
    return if @transitionEndBound
    @transitionEndBound = true
    
    # The event will be triggered once for each ribbon, we only
    # want one render though
    renderEnqueued = false
    for event in TRANSITION_END_EVENTS.split(' ')
      @el.addEventListener event, =>
        return true if renderEnqueued

        renderEnqueued = true

        setTimeout =>
          @render()
          renderEnqueued = false
        , 0

        true

  resetFormat: ->
    @format = @options.format.split('').reverse().join('')

  render: (value=@value) ->
    @resetFormat()

    @inside.innerHTML = ''

    classes = @el.className.split(' ')
    newClasses = []
    for cls in classes when cls.length
      unless /^odometer(-|$)/.test(cls)
        newClasses.push cls

    newClasses.push 'odometer'

    unless TRANSITION_SUPPORT
      newClasses.push 'odometer-no-transitions'

    if @options.theme
      newClasses.push "odometer-theme-#{ @options.theme }"
    else
      # This class matches all themes, so it should do what you'd expect if only one
      # theme css file is brought into the page.
      newClasses.push "odometer-auto-theme"

    @el.className = newClasses.join(' ')

    @ribbons = {}

    @digits = []
    for digit in value.toString().split('').reverse()
      ctx = {value: digit}

      @addDigit digit

  update: (newValue) ->
    return unless diff = newValue - @value

    if diff > 0
      @el.className += ' odometer-animating-up'
    else
      @el.className += ' odometer-animating-down'

    @animate newValue

    setTimeout =>
      # Force a repaint
      @el.offsetHeight

      @el.className += ' odometer-animating'
    , 0

    @value = newValue

  renderDigit: ->
    digit = createFromHTML renderTemplate DIGIT_HTML
    digit.querySelector('.odometer-digit-inner').innerHTML = renderTemplate RIBBON_HTML
    digit

  insertDigit: (digit) ->
    if not @inside.children.length
      @inside.appendChild digit
    else
      @inside.insertBefore digit, @inside.children[0]

  addDigit: (value) ->
    while true
      if not @format.length
        @resetFormat()

      char = @format.substring(0, 1)
      @format = @format.substring(1)

      break if char is 'd'

      spacer = createFromHTML renderTemplate(FORMAT_MARK_HTML, {char})
      @insertDigit spacer

    digit = @renderDigit()
    digit.querySelector('.odometer-ribbon-inner').innerHTML = renderTemplate VALUE_HTML, {value}
    @digits.push digit

    @insertDigit digit

  animate: (newValue) ->
    if TRANSITION_SUPPORT
      @animateSlide newValue
    else
      @animateCount newValue

  animateCount: (newValue) ->
    return unless diff = newValue - @value

    start = last = now()

    cur = @value
    do tick = =>
      if (now() - start) > @options.duration
        @value = newValue
        @render()
        return

      delta = now() - last

      if delta > COUNT_MS_PER_FRAME
        last = now()

        fraction = delta / @options.duration
        dist = diff * fraction

        cur += dist
        @render Math.round cur

      if window.requestAnimationFrame
        requestAnimationFrame tick
      else
        setTimeout tick, COUNT_MS_PER_FRAME

  animateSlide: (newValue) ->
    return unless diff = newValue - @value

    @bindTransitionEnd()

    digitCount = Math.ceil(Math.log(Math.max(newValue, @value)) / Math.log(10))

    digits = []
    boosted = 0
    # We create a array to represent the series of digits which should be
    # animated in each column
    for i in [0...digitCount]
      start = Math.floor(@value / Math.pow(10, (digitCount - i - 1)))
      end = Math.floor(newValue / Math.pow(10, (digitCount - i - 1)))

      dist = end - start

      if Math.abs(dist) > @MAX_VALUES
        # We need to subsample
        frames = []

        # Subsequent digits need to be faster than previous ones
        incr = dist / (@MAX_VALUES + @MAX_VALUES * boosted * DIGIT_SPEEDBOOST)
        cur = start
        while (dist > 0 and cur < end) or (dist < 0 and cur > end)
          cur += incr
          frames.push Math.round cur
        frames.push end

        boosted++
      else
        frames = [start..end]

      # We only care about the last digit
      for frame, i in frames
        frames[i] = frame % 10

      digits.push frames

    for frames, i in digits.reverse()
      if not @digits[i]
        @addDigit ' '

      @ribbons[i] ?= @digits[i].querySelector('.odometer-ribbon-inner')
      @ribbons[i].innerHTML = ''

      if diff < 0
        frames = frames.reverse()

      for frame, j in frames
        numEl = createFromHTML renderTemplate VALUE_HTML, {value: frame}

        @ribbons[i].appendChild numEl

        if j == frames.length - 1
          numEl.className += ' odometer-last-value'
        if j == 0
          numEl.className += ' odometer-first-value'

Odometer.options = window.odometerOptions ? {}

Odometer.init = ->
  elements = document.querySelectorAll '.odometer'

  for el in elements
    el.odometer = new Odometer {el, value: el.innerText}

document.addEventListener 'DOMContentLoaded', ->
  if Odometer.options.auto isnt false
    Odometer.init()

window.Odometer = Odometer