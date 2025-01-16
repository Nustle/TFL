include("parser/node.jl")

mutable struct CFG
    node_to_nt::Dict{Node,String}                 
    group_numbers::Dict{Int,String}              
    grammar::Dict{String,Vector{Vector{String}}} 
    nt_index::Vector{Int}                        
    start::String                                
end

function CFG(tree::Node)
    node_to_nt = Dict{Node,String}()
    group_numbers = Dict{Int,String}()
    grammar = Dict{String,Vector{Vector{String}}}()
    nt_index = [1]
    start = "S"
    cfg = CFG(node_to_nt, group_numbers, grammar, nt_index, start)
    cfg.node_to_nt[tree] = cfg.start
    make_rules(cfg, tree, cfg.start)

    return cfg
end

function new_nt(cfg::CFG)::String
    name = "A$(cfg.nt_index[1])"
    cfg.nt_index[1] += 1
    return name
end

function node_nt(cfg::CFG, node::Node)::String
    if haskey(cfg.node_to_nt, node)
        return cfg.node_to_nt[node]
    else
        current_nt = new_nt(cfg)
        cfg.node_to_nt[node] = current_nt
        make_rules(cfg, node, current_nt)
        return current_nt
    end
end

function make_rules(cfg::CFG, node::Node, nt::String)
    if !haskey(cfg.grammar, nt)
        cfg.grammar[nt] = Vector{Vector{String}}()
    end

    if node isa NodeSymbol
        symbol = node.symbol
        push!(cfg.grammar[nt], [symbol])

    elseif node isa NodeConcat
        left_nt = node_nt(cfg, node.left)
        right_nt = node_nt(cfg, node.right)
        push!(cfg.grammar[nt], [left_nt, right_nt])

    elseif node isa NodeOR
        left_nt = node_nt(cfg, node.left)
        right_nt = node_nt(cfg, node.right)
        push!(cfg.grammar[nt], [left_nt])
        push!(cfg.grammar[nt], [right_nt])

    elseif node isa NodeKleeneStar
        child_nt = node_nt(cfg, node.val)
        push!(cfg.grammar[nt], String[])
        push!(cfg.grammar[nt], [child_nt, nt])

    elseif node isa NodeCatchGroup
        gnum = node.group_num
        if haskey(cfg.group_numbers, gnum)
            group_nt = cfg.group_numbers[gnum]
            if !haskey(cfg.grammar, group_nt)
                cfg.grammar[group_nt] = Vector{Vector{String}}()
            end
            if isempty(cfg.grammar[group_nt])
                push!(cfg.grammar[group_nt], [node_nt(cfg, node.val)])
            end
        else
            group_nt = "G$gnum"
            cfg.group_numbers[gnum] = group_nt
            cfg.grammar[group_nt] = [[node_nt(cfg, node.val)]]
        end
        push!(cfg.grammar[nt], [cfg.group_numbers[gnum]])

    elseif node isa NodeNonCatchGroup
        val_nt = node_nt(cfg, node.val)
        push!(cfg.grammar[nt], [val_nt])

    elseif node isa NodeLinkString
        num = node.group_num
        if !haskey(cfg.group_numbers, num)
            cfg.group_numbers[num] = "G$num"
        end
        push!(cfg.grammar[nt], [cfg.group_numbers[num]])

    elseif node isa NodeLinkExpression
        num = node.group_num
        if !haskey(cfg.group_numbers, num)
            cfg.group_numbers[num] = "G$num"
        end
        push!(cfg.grammar[nt], [cfg.group_numbers[num]])

    else
        push!(cfg.grammar[nt], ["Unknown"])
    end
end

function print_grammar(cfg::CFG)
    start_rules = get(cfg.grammar, cfg.start, Vector{Vector{String}}())
    println("$(cfg.start) -> ", make_alternatives(start_rules))
    for nt ∈ keys(cfg.grammar)
        if nt == cfg.start
            continue
        end
        rules = cfg.grammar[nt]
        println("$(nt) -> ", make_alternatives(rules))
    end
end

function make_alternatives(alternatives::Vector{Vector{String}})::String
    parts = String[]
    for alt ∈ alternatives
        if isempty(alt)
            push!(parts, "ε")
        else
            push!(parts, join(alt, " "))
        end
    end
    return join(parts, " | ")
end