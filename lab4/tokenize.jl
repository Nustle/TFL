mutable struct Token
    token_name::String
    value::Union{String,Nothing}
end

function tokenize(regex::String)::Vector{Token}
    tokens = Token[]
    n = length(regex)
    pos = 1

    while pos <= n
        symbol = regex[pos]
        if symbol == ' '
            pos += 1
            continue
        elseif symbol == ')'
            push!(tokens, Token("RightBracket", ")"))
            pos += 1
        elseif symbol == '|'
            push!(tokens, Token("OR", "|"))
            pos += 1
        elseif symbol == '*'
            push!(tokens, Token("KleeneStar", "*"))
            pos += 1
        elseif isdigit(symbol)
            push!(tokens, Token("Digit", string(symbol)))
            pos += 1
        elseif symbol >= 'a' && symbol <= 'z'
            push!(tokens, Token("Symbol", string(symbol)))
            pos += 1
        elseif symbol == '('
            if pos < n && regex[pos+1] == '?'
                if pos+1 < n && pos+2 <= n && pos+2 <= n
                    next_symbol = regex[pos+2]
                    if next_symbol == ':'
                        push!(tokens, Token("LeftBracket", "("))
                        push!(tokens, Token("Question", "?"))
                        push!(tokens, Token("NonCatchGroup", ":"))
                        pos += 3
                    else
                        push!(tokens, Token("LeftBracket", "("))
                        push!(tokens, Token("Question", "?"))
                        pos += 2
                    end
                else
                    push!(tokens, Token("LeftBracket", "("))
                    push!(tokens, Token("Question", "?"))
                    pos += 2
                end
            else
                push!(tokens, Token("LeftBracket", "("))
                pos += 1
            end
        elseif symbol == '\\'
            if pos < n
                if pos+1 <= n
                    next_symbol = regex[pos+1]
                    if isdigit(next_symbol)
                        push!(tokens, Token("LinkString", string(next_symbol)))
                        pos += 2
                    else
                        push!(tokens, Token("Backslash", "\\"))
                        pos += 1
                    end
                else
                    push!(tokens, Token("Backslash", "\\"))
                    pos += 1
                end
            end
        else
            push!(tokens, Token("Unknown", string(symbol)))
            pos += 1
        end
    end
    push!(tokens, Token("End", nothing))
    return tokens
end