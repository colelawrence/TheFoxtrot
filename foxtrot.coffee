# Foxtrot for Molly
$ = Zepto

# Helper for animating efficiently using request animation frame when available

window.requestAnimFrame = (->
  window.requestAnimationFrame or window.webkitRequestAnimationFrame or window.mozRequestAnimationFrame or window.oRequestAnimationFrame or window.msRequestAnimationFrame or (callback, element) ->
    window.setTimeout callback, 1000 / 60
)()
# Create a new instance of the game and get it running.

$ -> 
  game = new Game
  game.run()
  
# ## Game
# The game class handles top level game loop and initialisation.
class Game
  # Start the game in a default state and initiate the game loop. 
  # It attempts to run the loop every 1 millisecond but in reality 
  # the loop is just running as fast as it can.  
  run: ->
    @setup()
    @reset()
    @then = Date.now()
    @animate()

  # Animate the game
  animate: =>
    if(@world)
      if(!@world.endgame)
        @main()
      else
        @world.ctx.fillStyle = "#fff"
        @world.ctx.font = "Bold 40px Calibri"
        @world.ctx.fillText("You Jumped #{@world.getMaxHeight()} cm!", 150, 670)
        @world.ctx.fillStyle = "rgb(241, 241, 242)"
        @world.ctx.fillText("You got all splatted on", 75, 500)
        @world.ctx.fillText("the Hard Ground little Fox!", 85, 550)
        @world.ctx.font = "Bold 15px Calibri"
        @world.ctx.fillText("(refresh?)", 300, 600)
      requestAnimFrame(@animate)
    
  # Create a new game world and keyboard input handler
  setup: ->
    @world = new World
    @inputHandler = new InputHandler(@world)

  # Updates are handled by the input handler.
  update: (modifier) -> @inputHandler.update(modifier)

  # Nothing is reset at this level so just ask the world to reset itself.
  reset: -> @world.reset()
  
  # The main game loop. Establish the time since the loop last ran
  # in seconds and pass that through to the update method for recalculating
  # sprite positions. After recalculation positions, render the sprites.
  main: =>
    now = Date.now()
    delta = now - @lastUpdate
    @lastUpdate = now
    @lastElapsed = delta
    @update(delta / 100)
    @render()

  # Tell the world to rerender itself.
  render: -> @world.render(@lastUpdate, @lastElapsed)

# ## World
# The World class manages the game world and what can be seen
# by the player.
class World
  width: 480
  height: 6000
  viewWidth: 640
  viewHeight: 720
  endgame: false
  worldX: -80#(@width - @viewWidth)/2
  worldY: 5500
  sprites: []
  plats: []
  springs: []
  particles: []
  lastPlatY: 5200
  renderParticles: false
  particleColor: "#2af"
  debugText: ""

  # When the world is created it adds a canvas to the page and
  # inserts all the sprites that are needed into the sprite array.
  constructor: ->
    @ctx = @createCanvas()
    @makefirstplatforms num for num in [6..0]
    @player = new Player(this)
    @sprites.push(@player)
    @sprites.push(new Grass(this))

  # Get the Canvas Coordinates from world coordinates
  getCX: (wx) -> return wx - @worldX
  getCY: (wy) -> return wy - @worldY

  makefirstplatforms: (num) ->
    plat = new Platform(this, 5800 - 100 * num, 100)
    @plats.push(plat)
 
  createPlatform: ->
    rand = 5 * Math.floor(Math.random()*33) #Between 0 and 32
    plat = new Platform(this, @lastPlatY - 180 - rand, 100)
    @lastPlatY -= 70 + rand
    if Math.floor(Math.random()*18) is 1 and @worldY < 6000
      @springs.push(new Spring(plat))
    @plats.push(plat)

  evalPlats: ->
    newPlats = []
    newPlats.push plat for plat in @plats when plat.isAlive
    @plats = newPlats
    @createPlatform()




  # Adjust Camera
  adjustWX: (dx) -> @worldX += dx
  adjustWY: (dy) -> @worldY += dy

  # Create an HTML5 canvas element and append it to the document
  createCanvas: ->
    canvas = document.createElement("canvas")
    canvas.width = @viewWidth
    canvas.height = @viewHeight
    $(".game").append(canvas)
    canvas.getContext("2d")

  # Tell all the sprites to render.
  render: (lastUpdate, lastElapsed) ->
    #SKY
    @ctx.fillStyle = "#b6d4e4"
    @ctx.fillRect(0,0,@viewWidth,@viewHeight)
    #PARTICLES
    @particleCreator() if @renderParticles
    #SPRITES
    plat.draw() for plat in @plats
    spring.draw() for spring in @springs
    sprite.draw() for sprite in @sprites
    @player.foxtail.draw()
    #
    @ctx.fillStyle = "rgba(255, 255, 255, 0.5)"
    @ctx.fillRect(0,0,(@viewWidth-@width)/2,@viewHeight)
    @ctx.fillRect(@viewWidth-(@viewWidth-@width)/2,0,(@viewWidth-@width)/2,@viewHeight)
    @renderDebugOverlay(lastElapsed)
    
  
  # Show the frames per second at the top of the view.
  renderDebugOverlay: (lastElapsed) ->
    @ctx.save()
    @ctx.fillStyle = "rgb(241, 241, 242)"
    @ctx.font = "Bold 24px Monospace"
    @ctx.fillText("#{@getHeight()}cm", 90, 20)
    @ctx.fillText("#{@debugText}", 90, 50)
    #@ctx.fillText("#{@particles.length}", 10, 50)
    @player.update(lastElapsed/20)
    @ctx.restore()
  getMaxHeight: ->
    Math.round((6000-@player.maxHeight)/60)
  getHeight: ->
    Math.round((6000-@player.wy)/60)
    
  particleCreator: ->
    @ctx.fillStyle = @particleColor
    newParticles = []
    if(@player.flying)
      @particles.push(new Particle(this,@player.wx+@player.sw /3,@player.wy+@player.sh,8.0))
      @particles.push(new Particle(this,@player.wx+@player.sw * 2/3,@player.wy+@player.sh,8.0))
    #Draw Particles in @particles
    for p in @particles when p.life > 0
      newParticles.push(p)
      p.draw()
    if newParticles.length is 0
      @suspendParticles()
    else
      @particles = newParticles

  createParticles: (color) ->
    @particleColor = color
    @renderParticles = true

  suspendParticles: ->
    @renderParticles = false
    @particles.length = 0
  # Pass any keyboard events that come in from the input
  # handler off to the hero.
  left: (mod) -> @player.left(mod)
  right: (mod) -> @player.right(mod)

  # Only the hero (player character) needs to be reset.
  reset: -> @resetCount++

  # Find the sprites that have collision detection enabled.
  activePlats: -> plat for plat in @plats when plat.isActive
  activeSprings: -> spring for spring in @springs when spring.plat.isActive

# ## InputHandler
# Responsible for dealing with keyboard input.
class InputHandler
  keysDown: {}
  mousedown: false
  clickX: 0
  orientationX: 0 #[-1, 1] right to left
  useOrientation: true

  # Listen for keys being presses and being released. As this happens
  # add and remove them from the key store.
  constructor: (@world) ->
    $("body").keydown (e) => @keysDown[e.keyCode] = true
    $("body").keyup (e)   => delete @keysDown[e.keyCode]
    if @useOrientation
      $(window).bind 'deviceorientation', (event) =>
        @orientationX = event.gamma
    else
      $("body").bind 'mousedown', (event) =>
        @clickX = event.offsetX
        @mousedown = true
      $("body").bind 'mouseup', (event) =>
        @mousedown = false


  d: ->
    delete @keysDown[68]
    @world.debug()

  # Every time update is called from the game loop act on the currently
  # pressed keys by passing the events on to the world.
  update: (modifier) ->
    @world.left(modifier)  if 37 of @keysDown
    @world.right(modifier) if 39 of @keysDown
    if @useOrientation
      @world.left(modifier) if @orientationX > .2 #tilt left
      @world.right(modifier) if @orientationX < -.2 #tilt right
    else
      if @mousedown
        @world.left(modifier) if @clickX < 80
        @world.right(modifier) if @clickX > 560 and @clickX < 640
    @debug() if 68 of @keysDown

# ## SpriteImage
# Wraps sprite loading.
class SpriteImage
  ready: false
  url: "img/sheet2.png"

  # Create a new image based on the sprite file and set
  # ready to true when loaded.
  constructor: ->
    image = new Image
    image.src = @url
    image.onload = => @ready = true
    @image = image

# ## Sprite
class Sprite
  # The base class from which all sprites get their draw function
  # and default values from.
  # 
  # Configure sane defaults for sprite positions and dimensions.
  name: "Plat"
  sx: 0 # Source x position
  sy: 0 # Source y position
  sw: 0 # Source width
  sh: 0 # Source height
  wx:  0 # Position x in the world
  wy:  0 # Position y in the world
  image: new SpriteImage
  isplat: false

  constructor: (@world) ->
  
  # If the image is loaded then draw the sprite on to the canvas.
  drawImage: ->
    if @image.ready
      @world.ctx.drawImage(@image.image, @sx, @sy, @sw, @sh, @world.getCX(@wx), @world.getCY(@wy), @sw, @sh)


class Grass
  constructor: (@world) ->
    @name = "Grass"
    @isplat = false

  draw: ->
    @world.ctx.fillStyle = "#177c00"
    @world.ctx.fillRect(0,@world.getCY(@world.height),@world.viewWidth,@world.viewHeight)

class Platform extends Sprite
  constructor: (@world, y, w) ->
    @isAlive = true
    @ismoving = y < 5000 and Math.floor(Math.random()*5) is 1
    @sh = 10
    @sw = w
    @wy = y
    @wx = Math.floor(Math.random()*13) * (@world.width - @sw) / 20
    @vx = if @ismoving then 4 else 0
    @typeplat = Math.floor(Math.random()*3)
    @sx = @typeplat*100 + (100 - @sw) /2
    @sy = if @ismoving then 100 else 90
    super(@world)
  
  isActive: ->
    return @isAlive and @world.getCY(@wy) > -10
  
  jumpoff: ->
    @typeplat--
    @sx = @typeplat*100 + (100 - @sw) /2
    if @typeplat is -1
      @isAlive = false
      # Now we have declared our plat "dead"
      @world.evalPlats()

  draw: ->
    if @world.getCY(@wy) > @world.viewHeight
      @isAlive = false
      # Now we have declared our plat "dead"
      @world.evalPlats()
      return
    if @isActive()
      @drawImage()
      if @ismoving
        @vx *= -1 if ((@wx + @sw + @vx) > @world.width and @vx > 0) or ((@wx + @vx) < 0 and @vx < 0)
        @wx += @vx

class Particle
  constructor: (@world, @wx, @wy, @life) ->
    @wx += - @life/2 + 4 - Math.floor(Math.random()*9)
    @wy += - @life/2 + 4 - Math.floor(Math.random()*9)
  draw: ->
    @world.ctx.fillRect(@world.getCX(@wx),@world.getCY(@wy),@life,@life)
    @life -= .5


class Spring extends Sprite
  springDepressed: true
  constructor: (@plat) ->
    @sx = 303
    @sy = 0
    @sw = 21
    @sh = 30
    @wx = @plat.wx + @plat.sw/2 - @sw/2
    @wy = @plat.wy - @sh
    super(@plat.world)
  
  jumpoff: ->
    @plat.world.createParticles("#fff")
    if(@springDepressed)
      @springDepressed = false
    
 
  draw: ->
    if(@plat.isActive())
      if(@plat.ismoving)
        @wx = @plat.wx + @plat.sw/2
        @wy = @plat.wy - @sh
      @sx = if(@springDepressed) then 303 else 328
      @drawImage()
    else if !@plat.isAlive
      @springDepressed = false
  


# ##########################################################################################################
# ## The Fox ##############################################################################################
class Player extends Sprite
  gravity: .6
  jumpHeight: 20
  maxHeight: 0
  speed: 5
  airRes: .98
  frame: 0
  jumping: 0
  flying: false
  vx: 0
  vy: 0

  constructor: (@world) ->
    @sw = 50
    @sh = 90
    @wx = @world.width / 2 - @sw/2
    @wy = 5700
    @foxtail = new Foxtail(@world, this, @image)
    @isplat = false
    @name = "Player"
    @maxHeight = @wy
    super (@world)

  jump: ->
      @vy = -@jumpHeight
  
  spring: ->
      @vy = -1.5 * @jumpHeight
      @flying = true

  update: (mod) ->
    return if !mod

    @vy += @gravity * mod

    # COLLISION CHECKS
    if @vy > 0
      @flying = false
      @jump() if @platCollision()
    else
      @maxHeight = @wy if @wy < @maxHeight
      
    
    @spring() if @springCollision()
    #

    if @wy > @world.height - @sh and @vy > 0
      if(@world.getMaxHeight() < 15)
        @jump()
      else
        @world.endgame = true
    
    @wy += @vy * mod
    @wx += @vx * mod
    @vx *= @airRes


    # Camera Adjustment
    @world.adjustWY(@vy) if @world.getCY(@wy) > @world.viewHeight - 100 and @vy > 0 or @world.getCY(@wy) < 300 and @vy < 0


  draw: ->
    @frame = 2
    @frame = 3 if @vx > 2
    @frame = 4 if @vx > 6
    @frame = 1 if @vx < -2
    @frame = 0 if @vx < -6
    @sx = @sw * @frame
    @sy = if @vy < 0 then 0 else 110
    @drawImage()
    
  cy: -> @world.getCY(@wy)
  cx: -> @world.getCX(@wx)
  
  platCollision: ->
    for o in @world.activePlats()
      if (@wy+70) > o.wy - 10 and (@wy+70) < o.wy + o.sh and @wx > o.wx - @sw and @wx < o.wx + o.sw
        o.jumpoff()
        return true
  springCollision: ->
    for o in @world.activeSprings() when o.springDepressed
      if (@wy+70) > o.wy - 10 and (@wy+70) < o.wy + o.sh and @wx > o.wx - @sw and @wx < o.wx + o.sw
        o.jumpoff()
        return true
    

  left: (mod) ->
    if(!mod)
      return
    @vx -= @speed * mod
    @vx = -8 if @vx < -8
  right: (mod) ->
    if(!mod)
      return
    @vx += @speed * mod
    @vx = 8 if @vx > 8

class Foxtail
  sx: 275 - 15 # Source x position
  sy: 5 # Source y position
  sw: 30 # Source width
  sh: 70 # Source height
    
  constructor: (@world, @player, @image) ->

  draw: ->
    angle = Math.atan2(@player.vx,-@player.vy)
    @world.ctx.translate(@player.cx() + @player.sw / 2,@player.cy() + @player.sh / 2 + 16)
    @world.ctx.rotate(angle)
    @world.ctx.translate(-15,0)
    # #Draw Image
    @world.ctx.drawImage(@image.image, @sx, @sy, @sw, @sh, 0, 0, @sw, @sh)
    # #Reset
    @world.ctx.translate(15,0)
    @world.ctx.rotate(-angle)
    @world.ctx.translate(-@player.cx() - @player.sw / 2,-@player.cy() - @player.sh / 2 - 16)