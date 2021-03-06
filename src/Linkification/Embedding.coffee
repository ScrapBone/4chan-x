Embedding =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Embedding']

    if Conf['Floating Embeds']
      @dialog = UI.dialog 'embedding', 'top: 50px; right: 0px;',
        <%= importHTML('Linkification/Embed') %>
      @media = $ '#media-embed', @dialog

      $.on d, '4chanXInitFinished', @ready

    Post.callbacks.push
      name: 'Embedding'
      cb:   @node

  node: ->
    anchors = $$ '.linkified', @nodes.comment
    return if !anchors.length or @isClone and !@origin.embeds

    for anchor in anchors
      for service in Embedding.services
        if result = service.regex.exec anchor.href
          break
      continue unless result
      embed = new Embed @, anchor, service, result
      do (embed) ->
        $.on embed.toggle, 'click', (e) ->
          Embedding.toggle embed, e
    return

  ready: ->
    $.off d, '4chanXInitFinished', Embedding.ready
    $.addClass Embedding.dialog, 'empty'
    $.on $('.close', Embedding.dialog), 'click',     Embedding.toggleFloat
    $.on $('.move',  Embedding.dialog), 'mousedown', Embedding.dragEmbed
    $.on $('.jump',  Embedding.dialog), 'click', ->
      Header.scrollTo Embedding.lastEmbed.post.nodes.root
    $.add d.body, Embedding.dialog

  toggle: (embed, e) ->
    e.preventDefault()
    e.stopPropagation()
    return unless navigator.onLine
    if embed.isEmbedded
      embed.rmEmbed()
      embed.toggle.textContent = 'Embed'
      return
    else if embed.isLoading
      return
    embed.isLoading = true
    embed.service.embedURL.call embed

  toggleFloat: (e, embed) ->
    return unless div = Embedding.media.firstChild
    if el = embed?.el
      {href} = $ '[title="Link to this post"]', embed.post.nodes.info
      $.replace div, el
      Embedding.lastEmbed = embed
      $.rmClass Embedding.dialog, 'empty'
      return
    delete Embedding.lastEmbed
    $.addClass Embedding.dialog, 'empty'
    $.replace div, $.el 'div'

  dragEmbed: (e) ->
    # only webkit can handle a blocking div
    {style} = Embedding.media
    if Embedding.dragEmbed.mouseup
      $.off d, 'mouseup', Embedding.dragEmbed
      Embedding.dragEmbed.mouseup = false
      style.visibility = ''
      return
    $.on d, 'mouseup', Embedding.dragEmbed
    Embedding.dragEmbed.mouseup = true
    style.visibility = 'hidden'

  cb:
    toggle: (embed, el) ->
      embed.el = el
      {style} = embed.service
      if style
        $.extend el.style, style
      if Conf['Floating Embeds']
        Embedding.toggleFloat null, embed
        embed.isLoading = false
        return
      div = $.el 'div',
        className: 'media-embed'
      $.add div, el
      $.after embed.span, div
      embed.toggle.textContent = 'Unembed'
      embed.isLoading  = false
      embed.isEmbedded = true

  services: [
      name: 'YouTube'
      style:
        border: 'none'
        width:  '640px'
        height: '360px'
      regex: /^https?:\/\/(?:(?:www\.|m\.)?you.+v[=\/]|#p\/[a-z]\/.+\/|youtu\.be\/)([a-z0-9_-]+)(?:.*[#&\?]t=([0-9hms]+))?/i
      title: -> @entry.title.$t
      titleURL: -> "https://gdata.youtube.com/feeds/api/videos/#{@result[1]}?alt=json&fields=title/text(),yt:noembed,app:control/yt:state/@reasonCode"
      preview:  ->
        "https://img.youtube.com/vi/#{@}/0.jpg"
      embedURL: ->
        [_, name, time] = @result
        time = if time
          match = /((\d+)h)?((\d+)m)?(\d+)?/.exec time
          time = parseInt(match[2] or 0) * 3600 + parseInt(match[4] or 0) * 60 + parseInt match[5] or 0
          "&start=#{time}"
        else
          ''
        el = $.el 'iframe',
          src: "https://youtube.com/embed/#{name}?rel=1&autohide=1&iv_load_policy=3#{time}"
        Embedding.cb.toggle @, el
    ,
      name: 'SoundCloud'
      regex: /(?:s(?:nd\.sc|oundcloud\.com)|www\.s(?:nd\.sc|oundcloud\.com)|m\.soundcloud\.com)\/([^#\&\?]+)/i
      title: -> @title
      titleURL: -> "https://soundcloud.com/oembed?&format=json&url=#{@anchor.href}"
      embedURL: ->
        url  = "https://soundcloud.com/oembed?show_artwork=false&maxwidth=500px&show_comments=false&format=json&iframe=true&url=#{@anchor.href}"
        that = @
        $.cache url, ->
          if @status in [200, 304]
            el = $.el 'div',
              innerHTML: JSON.parse(@response).html
            Embedding.cb.toggle that, el
            return
          that.isLoading = false
        return
    ,
      name: 'Vocaroo'
      style:
        border: 'none'
        width:  '150px'
        height: '45px'
      regex: /vocaroo\.com\/i\/([a-zA-Z0-9]+)/i
      embedURL: ->
        el = $.el 'iframe',
          src: "http://vocaroo.com/player.swf?autoplay=0&playMediaID=#{@result[1]}"
        Embedding.cb.toggle @, el
    ,
      name: 'Vimeo'
      style:
        border: 'none'
        width:  '640px'
        height: '360px'
      regex: /vimeo\.com\/(?:m\/)?(\d+)(?:.*[#&\?](t=\d+))?/i
      title: -> @title
      titleURL: -> "https://vimeo.com/api/oembed.json?url=#{@anchor.href}"
      embedURL: ->
        el = $.el 'iframe',
          src: "https://player.vimeo.com/video/#{@result[1]}"
        Embedding.cb.toggle @, el
    ,
      name: 'Pastebin'
      style:
        border: 'none'
        width:  '640px'
        height: '500px'
      regex: /pastebin\.com\/(?!u\/)(?:raw.php\?i=)?([a-zA-Z0-9]+)/i
      embedURL: ->
        el = $.el 'iframe',
          src: "http://pastebin.com/embed_iframe.php?i=#{@result[1]}"
        Embedding.cb.toggle @, el
    ,
      name: 'Gist'
      style:
        border: 'none'
        width:  '640px'
        height: '500px'
      regex: /gist\.github\.com\/\w+\/(\w+)/i
      title: ->
       response = @files
       return file for file of response when response.hasOwnProperty file
      titleURL: -> "https://api.github.com/gists/#{@result[1]}"
      embedURL: ->
        el = $.el 'iframe',
          src: "data:text/html,<script src='https://gist.github.com/#{@result[1]}.js'></script>"
        Embedding.cb.toggle @, el
    ,
      name: 'InstallGentoo'
      style:
        border: 'none'
        width:  '640px'
        height: '360px'
      regex: /paste\.installgentoo\.com\/view\/(?:raw\/)?([a-zA-Z0-9]+)/i
      embedURL: ->
        el = $.el 'iframe',
          src: "http://paste.installgentoo.com/view/embed/#{@result[1]}"
        Embedding.cb.toggle @, el
    ,
      name: 'imgur'
      style:
        border: 'none'
        cursor: 'pointer'
      regex: /imgur\.com\/(?!a\/)([a-zA-Z0-9]{7})(?:\.(?:a?png|jpg|gif))?/i
      embedURL: ->
        el = $.el 'img',
          # imgur/browser doesn't care about filetype so we
          # use this to embed files without type specified.
          src: "http://i.imgur.com/#{@result[1]}.png"
          className: 'image-embed'
        unless Embedding.style
          Embedding.style = $.addStyle null
          Embedding.services[7].resize()
          $.on window, 'resize', Embedding.services[7].resize
        {toggle} = @
        unless Conf['Floating Embeds']
          $.on el, 'click', ->
            $.rm el.parentNode
            toggle.textContent = 'Embed'
        Embedding.cb.toggle @, el
      resize: ->
        Embedding.style.textContent =
          ".media-embed .image-embed { max-height: #{parseInt innerHeight * .8}px; max-width: #{parseInt innerWidth * .8}px; }"
    ,
      name: 'LiveLeak'
      style:
        border: 'none'
        width:  '640px'
        height: '360px'
      regex: /liveleak\.com\/view.+i=([a-z0-9]{3}_\d+)/i
      embedURL: ->
        el = $.el 'iframe',
          src: "http://www.liveleak.com/e/#{@result[1]}"
        Embedding.cb.toggle @, el
    ,
      name: 'TwitchTV'
      style:
        border: 'none'
        width:  '640px'
        height: '360px'
      regex: /twitch\.tv\/(\w+)\/(?:b\/)?(\d+)/i
      embedURL: ->
        [_, channel, archive] = @result
        el = $.el 'object',
          data: 'http://www.twitch.tv/widgets/archive_embed_player.swf'
          innerHTML: """
            <param name='allowFullScreen' value='true' />
            <param name='flashvars' value='channel=#{channel}&start_volume=25&auto_play=false&archive_id=#{archive}' />
          """
        Embedding.cb.toggle @, el
    ,
      name: 'Vine'
      style:
        border: 'none'
        width:  '500px'
        height: '500px'
      regex: /vine\.co\/(v\/[a-z0-9]+)/i
      embedURL: ->
        el = $.el 'iframe',
          src: "https://vine.co/#{@result[1]}/card"
        Embedding.cb.toggle @, el
    ,
      name: 'Dailymotion'
      style:
        border: 'none'
        width:  '620px'
        height: '352px'
      regex: /(?:dailymotion\.com\/video|dai.ly)\/([a-z0-9]+)(?:.+start=([0-9]+))?/i
      title: -> @title
      titleURL: -> "https://api.dailymotion.com/video/#{@result[1]}"
      embedURL: ->
        [_, name, time] = @result
        time = if time then time else ''
        el = $.el 'iframe',
          src: "https://www.dailymotion.com/embed/video/#{name}?logo=0#{time}"
        Embedding.cb.toggle @, el
    ,
      name: 'StrawPoll'
      style:
        border: 'none'
        width:  '600px'
        height: '406px'
      regex: /strawpoll\.me\/(?:embed_\d+\/)?(\d+)/i
      embedURL: ->
        el = $.el 'iframe',
          src: "http://strawpoll.me/embed_1/#{@result[1]}"
        Embedding.cb.toggle @, el
  ]
