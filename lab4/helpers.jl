using PyCall
@pyimport graphviz as gv

function dfs(catch_groups::Dict{Int,Node}, node::Node)
    if node isa NodeCatchGroup
        catch_groups[node.group_num] = node.val
        dfs(catch_groups, node.val)

    elseif node isa NodeConcat
        dfs(catch_groups, node.left)
        dfs(catch_groups, node.right)

    elseif node isa NodeOR
        dfs(catch_groups, node.left)
        dfs(catch_groups, node.right)

    elseif node isa NodeKleeneStar
        dfs(catch_groups, node.val)

    elseif node isa NodeNonCatchGroup
        dfs(catch_groups, node.val)
    end
end

function draw_tree(node::Node, graph, parent_id::Union{Nothing,String}=nothing, node_id::Int=0)
    current_id = "node$(node_id)"
    node_id += 1

    label = get_label(node)
    graph.node(current_id, label)

    if parent_id !== nothing
        graph.edge(parent_id, current_id)
    end

    if node isa NodeConcat || node isa NodeOR
        node_id = draw_tree(node.left, graph, current_id, node_id)
        node_id = draw_tree(node.right, graph, current_id, node_id)
    elseif node isa NodeKleeneStar || node isa NodeNonCatchGroup || node isa NodeCatchGroup
        node_id = draw_tree(node.val, graph, current_id, node_id)
    end

    return node_id
end

function get_label(node::Node)::String
    if node isa NodeSymbol
        return "Symbol: $(node.symbol)"
    elseif node isa NodeConcat
        return "Concat"
    elseif node isa NodeOR
        return "OR"
    elseif node isa NodeKleeneStar
        return "KleeneStar"
    elseif node isa NodeCatchGroup
        return "CatchGroup (num=$(node.group_num))"
    elseif node isa NodeNonCatchGroup
        return "NonCatchGroup"
    elseif node isa NodeLinkString
        return "LinkString (group_num=$(node.group_num))"
    elseif node isa NodeLinkExpression
        return "LinkExpression (group_num=$(node.group_num))"
    else
        return "Unknown Node"
    end
end

function save_tree_image(node::Node, filename::String)
    println("here")
    graph = gv.Digraph(format="png")
    draw_tree(node, graph)
    graph.render(filename, cleanup=true)
    println("AST saved as $(filename).png")
end