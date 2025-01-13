include("grammar.jl")

function marked_test(file_test::String, grammar::CFG)
    file_path = joinpath("tests", file_test)
    open(file_path, "r") do f
        for line in eachline(f)
            split_line = split(line)
            if length(split_line) == 2
                word = String(strip(split_line[1]))
                ans = parse(Int, strip(split_line[2]))
                is_parsed, position = parse_grammar(grammar, word)
                if is_parsed == ans
                    println("[OK] String: $word -> Result: $is_parsed")
                else
                    println(position)
                    println("[FAIL] String: $word -> Result: $is_parsed")
                end
            end
        end
    end
end

function main()
    file_name = "input2"
    file_path = joinpath("input", file_name * ".txt")

    k = 0
    input_rules = String[]

    open(file_path, "r") do f
        k = parse(Int, readline(f))
        if k == 0
            println("1 <= k <= 3")
            return
        end
        for line in readlines(f)
            push!(input_rules, strip(line))
        end
    end

    grammar = CFG(k, input_rules)
    
    construct_first(grammar)
    construct_follow(grammar)

    if !check_ll(grammar)
        println("Grammar not LL($k)")
    end

    construct_ll_table(grammar)
    generate_table(file_name, grammar.ll_table, grammar.start)
    file_test = "test_input2.txt"
    marked_test(file_test, grammar)
end

main()