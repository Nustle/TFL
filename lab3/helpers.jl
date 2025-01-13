using PyCall

mutable struct Rule
    left::String
    right::Vector{String}
end

function is_terminal(term::Char)::Bool
    arith_op = Set(['+', '*', '(', ')', '/', '-'])
    return ('a' <= term <= 'z') || term == 'ε' || term in arith_op
end

function common_prefix(a1::Vector{String}, a2::Vector{String})::Vector{String}
    prefix = String[]
    for (x, y) in zip(a1, a2)
        if x == y
            push!(prefix, x)
        else
            break
        end
    end
    return prefix
end

function find_prefix(alts::Vector{Vector{String}})::Tuple{Vector{String}, Vector{Vector{String}}}
    best_prefix, best_group = String[], Vector{Vector{String}}()
    for i in 1:length(alts)
        for j in (i+1):length(alts)
            p = common_prefix(alts[i], alts[j])
            if length(p) > length(best_prefix)
                group = Vector{Vector{String}}()
                for rule in alts
                    if length(rule) >= length(p) && rule[1:length(p)] == p
                        push!(group, rule)
                    end
                end
                if length(group) >= 2
                    best_prefix = p
                    best_group = group
                end
            end
        end
    end
    return (best_prefix, best_group)
end

function compare_rule(rule1::Vector{String}, rule2::Vector{String})::Bool
    if length(rule1) != length(rule2)
        return false
    end
    for i in 1:length(rule1)
        if rule1[i] != rule2[i]
            return false
        end
    end
    return true
end

function make_nt_new(nt::String, cfg_nt::Set{String})::String
    nt_new = nt * "'"
    while nt_new in cfg_nt
        nt_new *= "'"
    end
    return nt_new
end

function concat(word1::String, word2::String)::String
    if word1 == "ε" || word1 == "\$"
        return word2
    elseif word2 == "ε" || word2 == "\$"
        return word1
    else
        return word1 * word2
    end
end

function get_nt_rule(rule::Rule, rules::Vector{Rule})::Union{Rule, Nothing}
    for r in rules
        if rule.left == r.left && compare_rule(rule.right, r.right)
            return r
        end
    end
    return nothing
end

function get_right_nt(rules::Vector{Rule}, nt::String)::Vector{Vector{String}}
    right = Vector{Vector{String}}()
    for rule in rules
        if rule.left == nt
            push!(right, rule.right)
        end
    end
    return right
end

function generate_table(file_name::String, parse_table::Dict{String, Dict{String, Vector{Rule}}}, start::String)
    not_terminals = collect(keys(parse_table))
    start_index = findfirst(x -> x == start, not_terminals)
    if start_index != nothing
        not_terminals[start_index], not_terminals[1] = not_terminals[1], not_terminals[start_index]
    end

    lookaheads_set = Set{String}()
    for nt in not_terminals
        union!(lookaheads_set, keys(parse_table[nt]))
    end

    lookaheads = sort(collect(lookaheads_set))
    end_index = findfirst(x -> x == "\$", lookaheads)
    if end_index != nothing
        lookaheads[end_index], lookaheads[end] = lookaheads[end], lookaheads[end_index]
    end

    html = String[]
    push!(html, "<html><head><meta charset='utf-8'></head><body>")
    push!(html, "<table border='1' cellspacing='0' cellpadding='4'>")

    push!(html, "<tr><th>Non-terminal / Lookahead</th>")
    for lookahead in lookaheads
        push!(html, "<th>$(lookahead)</th>")
    end
    push!(html, "</tr>")

    for nt in not_terminals
        push!(html, "<tr><th>$(nt)</th>")
        for lookahead in lookaheads
            rules = get(parse_table[nt], lookahead, Rule[])
            if isempty(rules)
                cell_text = ""
            else
                rule_texts = String[]
                for rule in rules
                    right_side = join(rule.right, " ")
                    push!(rule_texts, "$(rule.left) → $(right_side)")
                end
                cell_text = join(rule_texts, "<br/>")
            end
            push!(html, "<td>$(cell_text)</td>")
        end
        push!(html, "</tr>")
    end

    push!(html, "</table></body></html>")
    imgkit = pyimport("imgkit")
    output_file = "output/table_$file_name.png"
    imgkit["from_string"](join(html, "\n"), output_file)
    println("Table saved in $output_file")
end