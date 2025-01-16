include("node.jl")
include("../tokenize.jl")

mutable struct Parser
    tokens::Vector{Token}
    pos::Int
    current_group_num::Int
end

function Parser(tokens::Vector{Token})::Parser
    return Parser(tokens, 1, 0)
end

function current_token(p::Parser)::Token
    if p.pos > length(p.tokens)
        return Token("End", nothing)
    else
        return p.tokens[p.pos]
    end
end

function next(p::Parser; token_name::Union{Nothing, String}=nothing)::Token
    token = current_token(p)
    if token_name !== nothing && token.token_name != token_name
        throw(ErrorException("Token was expected: $token_name; got token: $token"))
    end
    p.pos += 1
    return token
end

function parse_regex(p::Parser)
    node = parse_or(p)
    if current_token(p).token_name != "End"
        throw(ErrorException("Characters after parsing end: $(current_token(p))"))
    end
    return node
end

function parse_or(p::Parser)::Node
    left = parse_concat(p)
    while current_token(p).token_name == "OR"
        next(p; token_name="OR")
        right = parse_concat(p)
        left = NodeOR(left, right)
    end
    return left
end

function parse_concat(p::Parser)::Node
    left = parse_kleene_star(p)
    while true
        token = current_token(p).token_name
        if token ∈ ("End", "RightBracket", "OR")
            break
        end
        right = parse_kleene_star(p)
        left = NodeConcat(left, right)
    end
    return left
end

function parse_kleene_star(p::Parser)::Node
    node = parse_base(p)
    while current_token(p).token_name == "KleeneStar"
        next(p; token_name="KleeneStar")
        node = NodeKleeneStar(node)
    end
    return node
end

function parse_base(p::Parser)::Node
    tok = current_token(p)

    if tok.token_name == "Symbol"
        next(p; token_name="Symbol")
        return NodeSymbol(tok.value)

    elseif tok.token_name == "Digit"
        next(p; token_name="Digit")
        return NodeSymbol(tok.value)

    elseif tok.token_name == "LinkString"
        next(p; token_name="LinkString")
        return NodeLinkString(parse(Int, tok.value))

    elseif tok.token_name == "LeftBracket"
        next(p; token_name="LeftBracket")
        if current_token(p).token_name != "Question"
            p.current_group_num += 1
            group_num = p.current_group_num
            val = parse_or(p)
            next(p; token_name="RightBracket")
            return NodeCatchGroup(group_num, val)
        else
            next(p; token_name="Question")
            if current_token(p).token_name != "NonCatchGroup"
                digit_tok = next(p; token_name="Digit")
                group_num = parse(Int, digit_tok.value)
                next(p; token_name="RightBracket")
                return NodeLinkExpression(group_num)
            else
                next(p; token_name="NonCatchGroup")
                val = parse_or(p)
                next(p; token_name="RightBracket")
                return NodeNonCatchGroup(val)
            end
        end

    else
        throw(ErrorException("Unexpected base token: $tok"))
    end
end

function get_catch_groups(root::Node)
    catch_groups = Dict{Int, Node}()
    dfs(catch_groups, root)
    return catch_groups
end

function check_semantic_rec(node::Node, current_set::Set{Int}, catch_groups::Dict{Int, Node},
                            cache::Dict{Any, Set{Int}}, context::Set{Any})::Set{Int} 
    key = (objectid(node), copy(current_set))
    if haskey(cache, key)
        return cache[key]
    end
    if key ∈ context
        return current_set
    end
    push!(context, key)
    res::Set{Int} = Set(current_set)

    if node isa NodeSymbol
        res = Set(current_set)

    elseif node isa NodeOR
        left = check_semantic_rec(node.left, current_set, catch_groups, cache, context)
        right = check_semantic_rec(node.right, current_set, catch_groups, cache, context)
        res = intersect(left, right)

    elseif node isa NodeKleeneStar
        _ = check_semantic_rec(node.val, current_set, catch_groups, cache, context)
        res = Set(current_set)

    elseif node isa NodeLinkString
        if node.group_num ∉ current_set
            throw(ErrorException("Link on non-initialized group: " * string(node.group_num)))
        end
        res = Set(current_set)

    elseif node isa NodeConcat
        left = check_semantic_rec(node.left, current_set, catch_groups, cache, context)
        right = check_semantic_rec(node.right, left, catch_groups, cache, context)
        res = right

    elseif node isa NodeCatchGroup
        expr = check_semantic_rec(node.val, current_set, catch_groups, cache, context)
        catch_expr = Set(expr)
        push!(catch_expr, node.group_num)
        res = catch_expr

    elseif node isa NodeNonCatchGroup
        res = check_semantic_rec(node.val, current_set, catch_groups, cache, context)

    elseif node isa NodeLinkExpression
        if !(haskey(catch_groups, node.group_num))
            throw(ErrorException("LinkExpression (?$(node.group_num)) but group doesn't exist"))
        end
        expr = catch_groups[node.group_num]
        link_out = check_semantic_rec(expr, current_set, catch_groups, cache, context)
        res = link_out
    else
        res = Set(current_set)
    end

    cache[key] = res
    delete!(context, key)
    return res
end

function check_semantic(root::Node)
    catch_groups = get_catch_groups(root)
    cache = Dict{Any, Set{Int}}()
    context = Set{Any}()

    check_semantic_rec(root, Set{Int}(), catch_groups, cache, context)
end

function check_regex(regex::String)
    tokens = tokenize(regex)
    p = Parser(tokens)
    ast_root = nothing
    try
        ast_root = parse_regex(p)
    catch e
        return (e, nothing)
    end
    try
        check_semantic(ast_root)
    catch e
        return (e, nothing)
    end
    return ("OK", ast_root)
end