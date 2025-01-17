mutable struct CFG
   rules::Dict{String, Vector{String}}
   start::String
   Σ::Set{String}
   non_terminals::Set{String}
end

mutable struct Situation
    left::String
    right::String
    pointer::Int
    index::Int
end

function CFG(input_rules::Vector{String})
    start = "S'"
    rules = make_rules(start, input_rules)
    cfg = CFG(rules, start, Set(["ε"]), Set{String}())
    get_tnt(cfg)
    return cfg
end

function make_rules(start::String, input_rules::Vector{String})::Dict{String, Vector{String}}
    rules = Dict{String, Vector{String}}()
    rules[start] = Vector{String}()
    push!(rules[start], "S")
    for rule ∈ input_rules
        if rule == ""
            continue
        end
        rule_splited = split(rule, "->")
        left = strip(rule_splited[1])
        right = strip(rule_splited[2])
        right = replace(right, " " => "")
        if !haskey(rules, left)
            rules[left] = Vector{String}()
        end
        push!(rules[left], right)
    end

    return rules
end

function get_tnt(cfg::CFG)
    for left ∈ keys(cfg.rules)
        push!(cfg.non_terminals, left)
        for right ∈ cfg.rules[left]
            for j ∈ 1:length(right)
                symbol = right[j]
                if ('a' <= symbol <= 'z') || symbol == 'ε'
                    push!(cfg.Σ, string(symbol))
                else
                    push!(cfg.non_terminals, string(symbol))
                end
            end
        end
    end
end

function Situation(left::String, right::String, pointer::Int)
    situation = Situation(left, right, pointer)
    return situation
end

function check_situations(s1::Situation, s2::Situation)::Bool
    equal = false
    if s1.left == s2.left && s1.right == s2.right && s1.pointer == s2.pointer && s1.index == s2.index
        equal = true
    end
    return equal
end

function situation_in_set(s::Situation, D::Vector{Set{Situation}}, j::Int)::Bool
    in_set = false
    for situation ∈ D[j]
        if check_situations(s, situation)
            in_set = true
            break
        end
    end
    return in_set
end

function get_symbol(s::Situation)::Union{String, Nothing}
    if s.pointer > length(s.right)
        return nothing
    else
        return string(s.right[s.pointer])
    end
end

function scan(D::Vector{Set{Situation}}, cfg::CFG, j::Int, word::String)
    if j == 1
         return 
    end
    for situation ∈ D[j-1]
        current_symbol = get_symbol(situation)
        if current_symbol === nothing
            continue
        end
        if current_symbol ∈ cfg.Σ && string(word[j-1]) == current_symbol
            new_situation = Situation(situation.left, situation.right, situation.pointer+1, situation.index)
            push!(D[j], new_situation)
        end
    end
end

function complete(D::Vector{Set{Situation}}, cfg::CFG, j::Int, word::String)::Bool
    changed = false
    for complete_situation ∈ D[j]
        if complete_situation.pointer == length(complete_situation.right)+1
            for situation ∈ D[complete_situation.index]
                term = get_symbol(situation)
                if term === nothing
                    continue
                end
                if term ∈ cfg.non_terminals && term == complete_situation.left
                    new_situation = Situation(situation.left, situation.right, situation.pointer+1, situation.index)
                    if !situation_in_set(new_situation, D, j)
                        push!(D[j], new_situation)
                        changed = true
                    end
                end
            end
        end
    end
    return changed
end

function predict(D::Vector{Set{Situation}}, cfg::CFG, j::Int, word::String)
    changed = false
    for situation ∈ D[j]
        term = get_symbol(situation)
        if term === nothing
            continue
        end
        if term ∈ cfg.non_terminals
            for rule ∈ cfg.rules[term]
                new_situation = Situation(term, rule, 1, j)
                if rule == "ε"
                    new_situation.pointer += 1
                end
                if !situation_in_set(new_situation, D, j)
                    push!(D[j], new_situation)
                    changed = true
                end
            end
        end
    end
    return changed
end

function earley(cfg::CFG, word::String)::Bool
    n = length(word)
    D = [Set{Situation}() for _ in 1:n+1]
    start_situation = Situation(cfg.start, cfg.rules[cfg.start][1], 1, 1)
    push!(D[1], start_situation)
    for j ∈ 1:n+1
        scan(D, cfg, j, word)
        changed = true
        while changed
            changed_complete = complete(D, cfg, j, word)
            changed_predict = predict(D, cfg, j, word)
            changed = changed_complete || changed_predict
        end
    end
    final_situation = Situation(cfg.start, cfg.rules[cfg.start][1], 2, 1)
    recognized = false
    if situation_in_set(final_situation, D, n+1)
       recognized = true
    end
    return recognized
end

function main()
    grammar_path = "test/grammar.txt"
    input_rules = String[]
    open(grammar_path, "r") do f
        for line in readlines(f)
            push!(input_rules, strip(line))
        end
    end

    grammar = CFG(input_rules)

    while true
        print("Enter word...: ")
        word = readline(stdin)
        word = string(strip(word))
        if word == "exit"
            println("Goodbye")
            break
        end
        recognized = earley(grammar, word)
        if recognized
             println("$word ∈ L(G)")
        else
            println("$word ∉ L(G)")
        end
    end
end

main()