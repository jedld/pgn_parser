class PgnParser

  def initialize(pgn_content)
    @pgn_content = pgn_content
    @headers = []
    @movelist = []
    @game_attributes = {}
  end

  def headers
    @headers
  end

  def attributes
    @game_attributes
  end

  def movelist
    @movelist
  end

  def parse
    current_index = 0
    state = :initial
    buffer = ''
    while (current_index < @pgn_content.size)
      current_char = @pgn_content[current_index]
      current_index+=1
      if state==:initial
        if current_char=='['
          state = :start_parse_header
          next
        elsif (current_char == ' ' || current_char == "\n" || current_char == "\r")
          next
        else
          break
        end
      end

      if state==:start_parse_header
        if current_char == ']'
          state = :initial
          hd = parse_header(buffer)
          @headers << hd
          @game_attributes[hd[:type]] = hd[:value]
          buffer = ''
          next
        else
          buffer << current_char
          next
        end
      end
    end


    @movelist = parse_moves(@pgn_content,current_index - 1)[0]
    {moves: @movelist}.merge(@game_attributes)
  end

  def parse_moves(content, current_index, initial_state = :parse_moves)
    state = initial_state
    buffer = ''
    state_before = nil
    current_move = {}
    current_alternative = {}
    movelist = []
    while (current_index < content.size)
      current_char = content[current_index]
      current_index+=1
      if state == :parse_moves
        if current_char == ' '
          next
        elsif current_char == '('
          x = nil
          x, current_index = parse_moves(content, current_index)
        elsif current_char == ')'
          current_index+=1
          break
        elsif current_char == '{'
          state = :start_parse_comment_section_paren
          next
        elsif current_char >= '0' && current_char <= '9'
          state =:parse_move_text_number
          buffer << current_char
          next
        end
      end

      if state == :parse_move_text_number
        if current_char == '.'
          current_move[:num] = buffer.to_i
          buffer = ''
          state = :parse_move_first_position
          next
        else
          buffer << current_char
          next
        end
      end

      if state == :parse_move_first_position
        if (current_char == ' ')
          next
        elsif (current_char == '.')
          state = :continuation_indicator
          current_move[:cont] = true
          next
        else
          buffer << current_char
          state = :begin_parse_move_first_position
          next
        end
      end

      if state == :continuation_indicator
        if (current_char == '.' )
          next
        elsif (current_char == ' ')
          state = :parse_move_second_position
          next
        else
          buffer << current_char
          state = :parse_move_second_position
        end
      end

      if state == :begin_parse_move_first_position
        if (current_char == ' ')
          current_move[:w] = buffer
          buffer = ''
          state = :parse_move_second_position
          next
        elsif (current_char == "\n")
           break
        else
          buffer << current_char
          next
         end
      end

      if state == :parse_move_second_position
        if (current_char == ' ')
          next
        elsif (current_char == ')')
          current_index+=1
          break
        elsif (current_char == '$')
          buf = ''
          while (content[current_index] >='0') &&  (content[current_index]<='9') && (current_index < content.size)
            buf << content[current_index]
            current_index+=1
          end
          current_move[:w_nag] = buf
          next
        elsif (current_char == '{')
          state = :start_parse_comment_section_paren
          next
        elsif (current_char == '(')
          current_move[:w_alt] = [] if current_move[:w_alt].nil?
          alternate, current_index = parse_moves(content, current_index + 1)
          current_move[:w_alt] << alternate
          next
        elsif (current_char >= '0' && current_char <= '9')
          buffer = ''
          movelist << current_move.dup
          current_move = {}
          buffer << current_char
          state = :parse_move_text_number
        else
          buffer << current_char
          state = :begin_parse_move_second_position
          next
        end
      end

      if state == :begin_parse_move_second_position
        if (current_char == ' ')
          current_move[:b] = buffer
          buffer = ''
          state = :start_comment_section
          next
        elsif (current_char == "\n")
          current_move[:b] = buffer
          movelist << current_move.dup
          break
        else
          buffer << current_char
          next
        end
      end

      if state == :start_comment_section
        if (current_char == ' ')
          next
        elsif (current_char == '$')
          buf = ''
          while (content[current_index] >='0') && (content[current_index]<='9') && (current_index < content.size)
            buf << content[current_index]
            current_index+=1
          end
          current_move[:b_nag] = buf
          next
        elsif (current_char == '{')
          state = :start_parse_comment_section_paren
          next
        elsif (current_char == ')')
          current_index+=1
          break
        elsif (current_char == '(')
          current_move[:b_alt] = [] if current_move[:b_alt].nil?
          alternate, current_index = parse_moves(content, current_index)
          current_move[:b_alt] << alternate
          next
        elsif current_char >= '0' && current_char <= '9'
          buffer = ''
          movelist << current_move.dup
          current_move = {}
          buffer << current_char
          state =:parse_move_text_number
          next
        end
      end

      if state == :start_parse_comment_section_paren
        if (current_char == '}')
          current_move[:comment] = buffer.dup
          buffer = ''
          movelist << current_move.dup
          current_move = {}
          state = :parse_moves
          next
        else
          buffer << current_char
          next
        end
      end
    end

    if state ==  :start_comment_section
      movelist << current_move.dup
    elsif state == :begin_parse_move_first_position
      current_move[:w] = buffer
      movelist << current_move.dup
    elsif state == :start_parse_comment_section
      movelist << current_move.dup
    elsif state == :parse_move_second_position
      movelist << current_move.dup
    end
    [movelist, current_index]
  end

  def parse_header(header)
    event_type = ""
    event_value = ""
    state = :parse_type
    current_index = 0
    buffer = ''
    while (current_index < header.size)
      current_char = header[current_index]
      current_index+=1
      if state==:parse_type
        if current_char == ' '
          event_type = buffer.dup
          buffer = ''
          state=:start_parse_value
          next
        else
          buffer << current_char
          next
        end
      elsif state==:start_parse_value
        if current_char=='"'
          state=:parse_value
          next
        else
          next
        end
      elsif state==:parse_value
        if current_char=='"'
          event_value = buffer.dup
          buffer = ''
        else
          buffer << current_char
        end

      end
    end
    {type: event_type, value: event_value}
  end
end