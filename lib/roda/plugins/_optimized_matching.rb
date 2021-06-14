# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The _optimized_matching plugin is automatically used internally to speed
    # up matching when a single argument String instance, String class, Integer
    # class, or Regexp matcher is passed to +r.on+, +r.is_+, or a verb method
    # such as +r.get+ or +r.post+.
    # 
    # The optimization works by avoiding the +if_match+ method if possible.
    # Instead of clearing the captures array on every call, and having the
    # matching append to the captures, it checks directly for the match,
    # and on succesful match, it yields directly to the block without using
    # the captures array.
    module OptimizedMatching 
      TERM = Base::RequestMethods::TERM

      module RequestMethods
        # Optimize the r.is method handling of a single string, String, Integer,
        # regexp, or true, argument.
        def is(*args, &block)
          case args.length
          when 1
            _is1(args, &block)
          when 0
            always(&block) if @remaining_path.empty?
          else
            if_match(args << TERM, &block)
          end
        end

        # Optimize the r.on method handling of a single string, String, Integer,
        # or regexp argument.  Inline the related matching code to avoid the
        # need to modify @captures.
        def on(*args, &block)
          case args.length
          when 1
            case matcher = args[0]
            when String
              always{yield} if _match_string(matcher)
            when Class
              if matcher == String
                rp = @remaining_path
                if rp.getbyte(0) == 47
                  if last = rp.index('/', 1)
                    @remaining_path = rp[last, rp.length]
                    always{yield rp[1, last-1]}
                  elsif (len = rp.length) > 1
                    @remaining_path = ""
                    always{yield rp[1, len]}
                  end
                end
              elsif matcher == Integer
                if matchdata = @remaining_path.match(/\A\/(\d+)(?=\/|\z)/)
                  @remaining_path = matchdata.post_match
                  always{yield(matchdata[1].to_i)}
                end
              else
                if_match(args, &block)
              end
            when Regexp
              if matchdata = @remaining_path.match(self.class.cached_matcher(matcher){matcher})
                @remaining_path = matchdata.post_match
                always{yield(*matchdata.captures)}
              end
            else
              if_match(args, &block)
            end
          when 0
            always(&block)
          else
            if_match(args, &block)
          end
        end

        private

        # Optimize the r.get/r.post method handling of a single string, String, Integer,
        # regexp, or true, argument.
        def _verb(args, &block)
          case args.length
          when 0
            always(&block)
          when 1
            _is1(args, &block)
          else
            if_match(args << TERM, &block)
          end
        end

        # Internals of r.is/r.get/r.post optimization.  Inline the related matching
        # code to avoid the need to modify @captures.
        def _is1(args, &block)
          case matcher = args[0]
          when String
            rp = @remaining_path
            if _match_string(matcher)
              if @remaining_path.empty?
                always{yield}
              else
                @remaining_path = rp
                nil
              end
            end
          when Class
            if matcher == String
              rp = @remaining_path
              if rp.getbyte(0) == 47 && !rp.index('/', 1) && (len = rp.length) > 1
                @remaining_path = ''
                always{yield rp[1, len]}
              end
            elsif matcher == Integer
              if matchdata = @remaining_path.match(/\A\/(\d+)\z/)
                @remaining_path = ''
                always{yield(matchdata[1].to_i)}
              end
            else
              if_match(args << TERM, &block)
            end
          when Regexp
            if (matchdata = @remaining_path.match(self.class.cached_matcher(matcher){matcher})) && (post_match = matchdata.post_match).empty?
              @remaining_path = ''
              always{yield(*matchdata.captures)}
            end
          when true
            always(&block) if @remaining_path.empty?
          else
            if_match(args << TERM, &block)
          end
        end
      end
    end

    register_plugin(:_optimized_matching, OptimizedMatching)
  end
end
