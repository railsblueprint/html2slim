require_relative 'hpricot_monkeypatches'

module HTML2Slim
  class Converter
    def to_s
      @slim
    end
  end
  class HTMLConverter < Converter
    def initialize(html)
      html=html.read

      html5tags = %w[header aside section nav svg g path main footer].join("|")

      html.gsub!(/<(#{html5tags})([^>]*)>/, "<div tag=\"\\1\"\\2>")
      html.gsub!(/<\/(#{html5tags})>/, %(</div>))

      @slim = Hpricot(html).to_slim
    end
  end
  class ERBConverter < Converter
    def initialize(file)
      erb = file.read

      erb.gsub!(/<%(.+?)\s*\{\s*(\|.+?\|)?\s*%>/){ %(<%#{$1} do #{$2}%>) }

      # case, if, for, unless, until, while, and blocks...
      erb.gsub!(/<%(-\s+)?((\s*(case|if|for|unless|until|while) .+?)|.+?do\s*(\|.+?\|)?\s*)-?%>/){ %(<span code="#{$2.gsub(/"/, '&quot;')}">) }
      # else
      erb.gsub!(/<%-?\s*else\s*-?%>/, %(</span><span code="else">))
      # elsif
      erb.gsub!(/<%-?\s*(elsif .+?)\s*-?%>/){ %(</span><span code="#{$1.gsub(/"/, '&quot;')}">) }
      # when
      erb.gsub!(/<%-?\s*(when .+?)\s*-?%>/){ %(</span><span code="#{$1.gsub(/"/, '&quot;')}">) }
      erb.gsub!(/<%\s*(end|}|end\s+-)\s*%>/, %(</span>))
      erb.gsub!(/<%-?(.+?)\s*-?%>/m){ %(<span code="#{$1.gsub(/"/, '&quot;')}"></span>) }

      @slim ||= Hpricot(erb).to_slim
    end
  end
end
