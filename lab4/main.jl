include("parser/parser.jl")
include("helpers.jl")
include("grammar.jl")

function read_from_file(file_test::String)
    file_path = joinpath("lab4/tests", file_test)
    f = open(file_path, "r")
    lines = readlines(f)
    close(f)

    for line in lines
        splitted = split(line)
        if length(splitted) < 2
            println("[FAIL] Строка без ответа: $line")
            continue
        end
        regex = String(splitted[1])
        ans_str = splitted[2]
        ans = parse(Int, ans_str)

        (parsed, tree) = check_regex(regex)
        if (parsed == "OK" && ans == 1) || (parsed != "OK" && ans == 0)
            println("[OK] Regex: $regex -> Result: $parsed")
        else
            println("[FAIL] Regex: $regex -> Result: $parsed")
        end
    end
end

function read_from_input()
    regex_index = 1
    while true
        print("Enter regex (or exit to quit..): ")
        reg = readline(stdin)
        reg = String(strip(reg))
        if isempty(reg) || reg == "exit"
            println("Goodbye")
            break
        end
        (answer, tree) = check_regex(reg)
        println("Regex: $reg")
        println("Answer: $answer")

        if tree !== nothing
            save_tree_image(tree, "lab4/output/regex_$(regex_index)")
            regex_index += 1
            grammar = CFG(tree)
            print_grammar(grammar)
        end
    end
end

function main()
    println("Enter working mode. 0 for input, 1 for tests:")
    mode_str = readline(stdin)
    if isempty(mode_str)
        mode_str = "0"
    end
    working_mode = try
        parse(Int, mode_str)
    catch
        0
    end

    if working_mode == 0
        read_from_input()
    elseif working_mode == 1
        println("Enter file name: ")
        fname = readline(stdin)
        read_from_file(fname)
    else
        println("Incorrect mode: $mode_str")
    end
end

main()