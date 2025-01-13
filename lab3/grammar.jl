include("helpers.jl")

mutable struct CFG
    k::Int
    rules::Vector{Rule}
    start::String
    Σ::Set{String}
    nt::Set{String}
    first::Dict{String,Set{String}}
    follow::Dict{String,Set{String}}
    ll_table::Dict{String,Dict{String,Vector{Rule}}}
end

function CFG(k::Int, input_rules::Vector{String})
    rules_ = make_rules(input_rules)
    start_ = rules_[1].left
    Σ_ = Set(["ε"])
    nt_ = Set{String}()
    cfg = CFG(k, rules_, start_, Σ_, nt_, Dict{String,Set{String}}(), Dict{String,Set{String}}(), Dict{String,Dict{String,Vector{Rule}}}())
    get_tnt(cfg)
    delete_useless_nt(cfg)
    left_rec(cfg)
    right_branching(cfg)
    refactor_new_nt(cfg)
    for n in cfg.nt
        cfg.ll_table[n] = Dict{String,Vector{Rule}}()
    end
    return cfg
end

function make_rules(input_rules::Vector{String})::Vector{Rule}
    rules = Rule[]
    for rule ∈ input_rules
        if rule == ""
            continue
        end
        left_right = split(rule, "->")
        left = strip(left_right[1])
        right_part = strip(left_right[2])

        right = String[]
        open_bracket = false

        i = 1
        while i <= lastindex(right_part)
            token = right_part[i]

            if token == ' '
                i += 1
                continue
            elseif token == '|'
                push!(rules, Rule(left, copy(right)))
                empty!(right)
                i += 1
            elseif token == '['
                open_bracket = true
                push!(right, "[")
                i += 1
            elseif token == ']'
                open_bracket = false
                right[end] *= "]"
                i += 1
            elseif isdigit(token)
                right[end] *= token
                i += 1
            elseif open_bracket
                right[end] *= token
                i += 1
            else
                push!(right, string(token))
                i += 1
            end
        end
        push!(rules, Rule(left, copy(right)))
    end
    return rules
end

function get_tnt(cfg::CFG)
    for rule ∈ cfg.rules
        push!(cfg.nt, rule.left)
        for token ∈ rule.right
            if is_terminal(token[1])
                push!(cfg.Σ, token)
            else
                push!(cfg.nt, token)
            end
        end
    end
end

function direct_left_rec(cfg::CFG, non_terminal::String)
    alpha_rules = Vector{Vector{String}}()
    beta_rules = Vector{Vector{String}}()

    for rule ∈ cfg.rules
        if rule.left == non_terminal
            if !isempty(rule.right) && rule.right[1] == non_terminal
                push!(alpha_rules, rule.right[2:end])
            else
                push!(beta_rules, rule.right)
            end
        end
    end

    if !isempty(alpha_rules)
        non_terminal_new = make_nt_new(non_terminal, cfg.nt)
        push!(cfg.nt, non_terminal_new)

        cfg.rules = [r for r ∈ cfg.rules if r.left != non_terminal]

        for beta ∈ beta_rules
            push!(cfg.rules, Rule(non_terminal, vcat(beta, [non_terminal_new])))
        end

        for alpha ∈ alpha_rules
            push!(cfg.rules, Rule(non_terminal_new, vcat(alpha, [non_terminal_new])))
        end

        push!(cfg.rules, Rule(non_terminal_new, ["ε"]))
    end
end

function nt_sort(cfg::CFG)::Vector{String}
    nt_sorted = String[]
    for rule ∈ cfg.rules
        if !(rule.left ∈ nt_sorted)
            push!(nt_sorted, rule.left)
        end
    end
    return nt_sorted
end

function get_generating_nt(cfg::CFG)::Set{String}
    generating_nt = Set{String}()

    for rule ∈ cfg.rules
        is_base_generating = true
        for term ∈ rule.right
            if term ∈ cfg.nt
                is_base_generating = false
                break
            end
        end
        if is_base_generating
            push!(generating_nt, rule.left)
        end
    end

    changed = true
    while changed
        changed = false
        for rule ∈ cfg.rules
            is_generating = true
            for term ∈ rule.right
                if term ∈ cfg.nt && term ∉ generating_nt
                    is_generating = false
                    break
                end
            end
            if is_generating && rule.left ∉ generating_nt
                push!(generating_nt, rule.left)
                changed = true
            end
        end
    end

    return generating_nt
end

function get_reachable_nt(cfg::CFG)::Set{String}
    reachable_nt = Set([cfg.start])

    changed = true
    while changed
        changed = false
        for rule ∈ cfg.rules
            if rule.left ∈ reachable_nt
                for term ∈ rule.right
                    if term ∈ cfg.nt && term ∉ reachable_nt
                        push!(reachable_nt, term)
                        changed = true
                    end
                end
            end
        end
    end

    return reachable_nt
end

function delete_useless_nt(cfg::CFG)
    generating = get_generating_nt(cfg)
    reachable = get_reachable_nt(cfg)
    useful = union(generating, reachable)

    for nt_ ∈ collect(cfg.nt)
        if nt_ ∉ useful
            delete!(cfg.nt, nt_)
            cfg.rules = [r for r ∈ cfg.rules if r.left != nt_]
        end
    end

    cfg.Σ = Set{String}()
    for rule ∈ cfg.rules
        for token ∈ rule.right
            if length(token) == 1 && is_terminal(token[1])
                push!(cfg.Σ, token)
            end
        end
    end
end

function left_rec(cfg::CFG)
    sorted_nt = nt_sort(cfg)
    for i ∈ 1:length(sorted_nt)
        Ai = sorted_nt[i]
        for j ∈ 1:(i-1)
            Aj = sorted_nt[j]
            old_rules = copy(cfg.rules)
            for rule ∈ old_rules
                if rule.left == Ai && !isempty(rule.right) && rule.right[1] == Aj
                    gamma = rule.right[2:end]
                    filter!(r -> r !== rule, cfg.rules)
                    for rule_j ∈ cfg.rules
                        if rule_j.left == Aj
                            new_right = vcat(rule_j.right, gamma)
                            push!(cfg.rules, Rule(Ai, new_right))
                        end
                    end
                end
            end
        end
        direct_left_rec(cfg, Ai)
        delete_useless_nt(cfg)
    end
end

function right_branching(cfg::CFG)
    changed = true
    grammar_nt = collect(cfg.nt)
    while changed
        changed = false
        for nt_ ∈ grammar_nt
            rule_right = Vector{Vector{String}}()
            for r ∈ cfg.rules
                if r.left == nt_
                    push!(rule_right, r.right)
                end
            end
            prefix, group = find_prefix(rule_right)
            if !isempty(prefix)
                changed = true
                nt_new = make_nt_new(nt_, cfg.nt)
                push!(cfg.nt, nt_new)
                push!(cfg.rules, Rule(nt_, vcat(prefix, [nt_new])))

                for right_part ∈ group
                    old_rule = get_nt_rule(Rule(nt_, right_part), cfg.rules)
                    if old_rule !== nothing
                        filter!(r -> r !== old_rule, cfg.rules)
                    end
                    new_right = right_part[length(prefix)+1:end]
                    push!(cfg.rules, Rule(nt_new, new_right))
                end
            end
        end
    end
end

function refactor_new_nt(cfg::CFG)
    grammar_nt = collect(cfg.nt)
    for nt_ ∈ grammar_nt
        n = length(nt_)
        if nt_[end] == '\''
            index_ = 0
            for i ∈ 1:n
                if nt_[i] == '\''
                    index_ = i
                    break
                end
            end
            count_ = string(n - index_ + 1)
            new_nt = "[" * nt_[1:index_-1] * count_ * "]"
            delete!(cfg.nt, nt_)
            push!(cfg.nt, new_nt)
            for rule ∈ cfg.rules
                if rule.left == nt_
                    rule.left = new_nt
                end
                for i ∈ 1:length(rule.right)
                    if rule.right[i] == nt_
                        rule.right[i] = new_nt
                    end
                end
            end
        end
    end
end

function first_alpha(cfg::CFG, alpha::Vector{String})::Set{String}
    alpha_first = Set(["ε"])
    first_ = Set{String}()

    for i ∈ 1:length(alpha)
        alpha_term = alpha[i]
        if length(alpha_term) > 1
            is_alpha_terminal = false
        else
            is_alpha_terminal = is_terminal(alpha_term[1])
        end
        new_alpha_first = Set{String}()
        for word ∈ alpha_first
            if is_alpha_terminal
                push!(new_alpha_first, concat(word, alpha_term))
            else
                for first_word ∈ cfg.first[alpha_term]
                    push!(new_alpha_first, concat(word, first_word))
                end
            end
        end
        alpha_first = new_alpha_first
    end

    for word ∈ alpha_first
        if length(word) <= cfg.k
            push!(first_, word)
        else
            push!(first_, word[1:cfg.k])
        end
    end
    return first_
end

function construct_first(cfg::CFG)
    for nt_ ∈ cfg.nt
        cfg.first[nt_] = Set{String}()
    end

    changed = true
    while changed
        changed = false
        for rule ∈ cfg.rules
            for i ∈ 1:min(cfg.k, length(rule.right))
                alpha = rule.right[1:i]
                first_alpha_ = first_alpha(cfg, alpha)
                for word ∈ first_alpha_
                    if word ∉ cfg.first[rule.left]
                        push!(cfg.first[rule.left], word)
                        changed = true
                    end
                end
            end
        end
    end
end

function construct_follow(cfg::CFG)
    for nt ∈ cfg.nt
        cfg.follow[nt] = Set{String}()
    end
    push!(cfg.follow[cfg.start], "\$")

    changed = true
    while changed
        changed = false
        for rule ∈ cfg.rules
            for i ∈ 1:length(rule.right)
                term = rule.right[i]
                if length(term) > 1 || !is_terminal(term[1])
                    first_gamma = Set(["ε"])

                    if i < length(rule.right)
                        slice_ = rule.right[i+1:end]
                        first_gamma = first_alpha(cfg, slice_)
                    end

                    if i == length(rule.right) || "ε" ∈ first_gamma
                        delete!(first_gamma, "ε")

                        for follow_word ∈ cfg.follow[rule.left]
                            if follow_word ∉ cfg.follow[term]
                                push!(cfg.follow[term], follow_word)
                                changed = true
                            end
                        end
                    end

                    for word ∈ first_gamma
                        if word ∉ cfg.follow[term]
                            push!(cfg.follow[term], word)
                            changed = true
                        end
                    end
                end
            end
        end
    end
end

function check_ll(grammar::CFG)::Bool
    for i ∈ 1:length(grammar.rules)
        rule1 = grammar.rules[i]
        for j ∈ (i+1):length(grammar.rules)
            rule2 = grammar.rules[j]
            if rule1.left == rule2.left
                first_rule1 = first_alpha(grammar, rule1.right)
                first_rule2 = first_alpha(grammar, rule2.right)
                if !isempty(intersect(first_rule1, first_rule2))
                    return false
                end
                if "ε" ∈ first_rule1
                    inter_ = intersect(first_rule2, grammar.follow[rule1.left])
                    if !isempty(inter_)
                        return false
                    end
                end
                if "ε" ∈ first_rule2
                    inter_ = intersect(first_rule1, grammar.follow[rule2.left])
                    if !isempty(inter_)
                        return false
                    end
                end
            end
        end
    end
    return true
end

function construct_ll_table(cfg::CFG)
    for rule ∈ cfg.rules
        first_alpha_ = first_alpha(cfg, rule.right)
        follow_a = cfg.follow[rule.left]
        words = Set{String}()
        for fw ∈ first_alpha_
            for fw2 ∈ follow_a
                x = concat(fw, fw2)
                push!(words, x)
            end
        end
        short_words = Set{String}()
        for x ∈ words
            push!(short_words, x[1:min(cfg.k, end)])
        end

        for x ∈ short_words
            if !haskey(cfg.ll_table[rule.left], x)
                cfg.ll_table[rule.left][x] = Rule[]
            end
            push!(cfg.ll_table[rule.left][x], rule)
        end
    end
end

function parse_grammar_rec(pos::Int, stack::Vector{String}, tokens::String, parse_table::Dict{String,Dict{String,Vector{Rule}}}, k::Int)
    if isempty(stack)
        if pos <= length(tokens) && tokens[pos] == '\$'
            return true, pos
        else
            return false, pos
        end
    end

    top = pop!(stack)
    if length(top) == 1 && is_terminal(top[1])
        if top == "ε"
            return parse_grammar_rec(pos, stack, tokens, parse_table, k)
        elseif pos <= length(tokens) && tokens[pos] == top[1]
            return parse_grammar_rec(pos+1, stack, tokens, parse_table, k)
        else
            return false, pos
        end
    else
        lookahead_size = min(pos+k, length(tokens))
        lookahead = tokens[pos:lookahead_size]

        rules = get(parse_table[top], lookahead, nothing)
        while rules === nothing && lookahead_size > pos
            lookahead_size -= 1
            lookahead = tokens[pos:lookahead_size]
            rules = get(parse_table[top], lookahead, nothing)
        end

        rules = rules === nothing ? Rule[] : rules

        for rule ∈ rules
            new_stack = copy(stack)
            for term ∈ reverse(rule.right)
                push!(new_stack, term)
            end
            success, new_pos = parse_grammar_rec(pos, new_stack, tokens, parse_table, k)
            if success
                return true, new_pos
            end
        end
        return false, pos
    end
end

function parse_grammar(grammar::CFG, word::String)
    tokens = word * "\$"
    pos = 1
    stack = [grammar.start]
    (success, final_pos) = parse_grammar_rec(pos, stack, tokens, grammar.ll_table, grammar.k)
    if success
        return 1, final_pos
    end
    return 0, final_pos
end