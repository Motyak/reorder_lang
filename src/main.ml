#!/usr/bin/env monlang

"=== mlp: BEGIN src/smallstd.mlp =============================================="

var tern (cond, if_true, if_false):{
    var res _
    cond && {res := if_true}
    cond || {res := if_false}
    res
}

-- var !tern (cond, if_false, if_true):{
    tern(cond, if_true, if_false)
}

var not (bool):{
    $false == bool
}

var <> (a, b):{
    a == b == $false
}

var <= (a, b):{
    a > b == $false
}

var >= (a, b):{
    a > b || a == b
}

var < (a, b):{
    (a > b || a == b) == $false
}

var CaseAnalysis (pred):{
    var end $false
    var fn (val, do):{
        end <> $nil || die("additional case succeeding a fallthrough case")
        "NOTE: don't eval val if end"
        end == $false && {
            val == $nil && {
                _ := do
                end := $nil
            }
            val == $nil || {
                end ||= pred(val) && {
                    _ := do
                    $true
                }
            }
        }
        ;
    }
    fn
}

var until (cond, do):{
    var 1st_it? $true
    var loop _
    loop := ():{
        cond() || {
            do(1st_it?)
            1st_it? := $false
            _ := loop()
        }
    }
    loop()
    ;
}

var do_while (do, cond):{
    var 1st_it? $true
    do(1st_it?)
    1st_it? := $false

    var loop _
    loop := ():{
        cond() && {
            do(1st_it?)
            _ := loop()
        }
    }
    loop()
    ;
}

var - (varargs...):{
    var sub-1 (n):{
        n + n * -2
    }
    var sub-2 (a, b):{
        a + b + b * -2
    }
    tern($#varargs == 1, sub-1(varargs...), {
        tern($#varargs == 2, sub-2(varargs...), {
            die("-() takes either 1 or 2 args")
        })
    })
}

var .. (from, to):{
    var dispatcher (msg):{
        tern(msg == 'from, from, {
            tern(msg == 'to, to, {
                die("unknown range msg: `" + msg + "`")
            })
        })
    }
    dispatcher
}

-- var foreach {
    var Container::foreach (OUT container, fn):{
        var nth 1
        until(():{nth > len(container)}, ():{
            fn(&container[#nth])
            nth += 1
        })
        container
    }

    var Range::foreach (range, fn):{
        var i range('from)
        var to range('to)
        until(():{i > to}, (_):{
            fn(i)
            i += 1
        })
    }

    var foreach (x, fn):{
        tern($type(x) == 'Lambda, Range::foreach(x, fn), {
            Container::foreach(&x, fn)
        })
    }

    (foreach)
}

var in {
    var Container::in (elem, container):{
        var nth 1
        var found $false
        until(():{found || nth > len(container)}, (_):{
            found := container[#nth] == elem
            nth += 1
        })
        found
    }

    var Range::in (elem, range):{
        elem >= range('from) && elem <= range('to)
    }

    var in (elem, x):{
        tern($type(x) == 'Lambda, Range::in(elem, x), {
            Container::in(elem, x)
        })
    }

    in
}

var !in (elem, container):{
    in(elem, container) == $false
}

var parseInt (str):{
    var to_digit (c):{
        Int(c - Byte("0"))
    }

    var res 0
    var i 0
    var loop _
    loop := ():{
        var nth len(str) - i
        nth == 0 || {
            var curr str[#nth]
            res += to_digit(curr) * 10 ** i
            i += 1
            loop()
        }
    }
    loop()

    res
}
"=== mlp: END src/smallstd.mlp (finally back to src/main.mlp) ================="
"=== mlp: BEGIN src/utils/parsing.mlp ========================================="

"include <smallstd.mlp>" -- mlp

var peekStr (input, str):{
    var len_str len(str)
    len(input) >= len_str && input[#1..len_str] == str
}

var peekAny (input, str):{
    len(str) > 0 && input[#1] in str
}

```
    supposed to do a peekStr() before a discard()
```
var discard (OUT input, n):{
    input := tern(len(input) == n, "", {
        var n+1 n + 1
        input[#n+1..-1]
    })
}

-- var consumeStr (OUT input, str):{
    peekStr(input, str) || die("Failed to consume `" + str + "` in `" + input + "`")
    discard(&input, len(str))
}

-- var consumeOptStr (OUT input, optStr):{
    peekStr(input, str) && {
        discard(&input, len(str))
    }
    ;
}
"=== mlp: END src/utils/parsing.mlp (finally back to src/main.mlp) ============"

var builtin::getline getline
var getline getline -- make it overridable

"stack of stacks (for nested programs)"
var g_stacks []

var convertNegLineNb _
var updateNegLineNb ():{die() -- "override from convertNegLineNb() didn't happen"}
{
    var lines []
    var slurp_stdin _
    slurp_stdin := ():{
        var line builtin::getline()
        line == $nil || {
            lines += [line]
            _ := slurp_stdin()
        }
    }

    var i _
    var lineEnd _
    var 1st_time_called? $true
    convertNegLineNb := (nb, context):{
        1st_time_called? && {
            i := context.currLineNb
            context.succeedsRange? || {
                slurp_stdin()
                getline := ():{
                    tern(len(lines) == 0, $nil, {
                        var line lines[#1]
                        lines := tern(len(lines) == 1, [], lines[#2..-1])
                        i += 1
                        line
                    })
                }
            }
            context.succeedsRange? && {
                ```
                    we only need to consume ahead <nb> lines..
                    .., and refresh the buffer on each new line so that..
                    ..it contains, at all time, the latest <nb> lines.
                    IF it's an exclusive range, we need one more line than <nb>.
                ```
                var n tern(context.exclusiveRange?, nb + 1, nb)
                n -= 1 -- "because we will complete the buffer at the beginning of getline()"
                {
                    var i 1
                    var loop _
                    loop := ():{
                        i > n || {
                            var line builtin::getline()
                            line == $nil || {
                                lines += [line]
                                i += 1
                                _ := loop()
                            }
                            i := n + 1 -- break the loop
                        }
                    }
                    loop()
                }
                {
                    lineEnd := tern(len(lines) < n, i -- trigger out of bounds, i + 1)
                    context.exclusiveRange? && {
                        lineEnd += 1 -- "cancels out future decrement (ugly)"
                    }
                } -- "TODO: i suppose ?"
                print("DEBUG lines " + lines)
                getline := ():{
                    {
                        var line builtin::getline()
                        line == $nil || {
                            lines += [line]
                            lineEnd += 1 -- make the end one step further
                        }
                    }
                    tern(len(lines) == 0, $nil, {
                        var line lines[#1]
                        lines := tern(len(lines) == 1, [], lines[#2..-1])
                        i += 1
                        line
                    })
                }
                updateNegLineNb := (OUT _lineEnd):{
                    _lineEnd := lineEnd
                }
            }
            1st_time_called? := $false
        }
        -- nb <= len(lines) || die("Out of bounds: `-" + nb + "`") -- "TODO: tmp"
        tern(lineEnd <> $nil, lineEnd, {
            i + len(lines) - nb + 1
        })
    }
}


var consumeExtra (OUT input):{
    var extras "\n" + " " + Byte(9)
    var nth 1
    until(():{nth > len(input) || input[#nth] !in extras}, (_):{
        nth += 1
    })

    input := tern(nth > len(input), "", input[#nth..-1])
}

var peekLineNb (input):{
    len(input) >= 1 && (input[#1] in "+-" || input[#1] in '0 .. '9)
}

var consumeLineNb (OUT input):{
    len(input) >= 1 || die()

    var sign ""
    input[#1] in "+-" && {
        len(input) >= 2 || die("Invalid line number in `" + input + "`")
        input[#2] in '0 .. '9 || die("Invalid line number in `" + input + "`")
        sign := input[#1]
        input := input[#2..-1]
    }

    var nth 1
    until(():{nth > len(input) || input[#nth] !in '0 .. '9}, (_):{
        nth += 1
    })
    
    var str tern(input == "", "", input[#1..<nth])
    str <> "" || die("Invalid line number in `" + input + "`")
    input := tern(nth > len(input), "", input[#nth..-1])
    var nb parseInt(str)

    ['sign:sign, 'nb:nb]
}

var interpretLineNb (_lineNb, OUT context, process):{
    var sign _lineNb.sign
    var nb _lineNb.nb
    let i context.currLineNb

    var lineEnd {
        var lineEnd nb
        "special case for negative line nb: line end may be temporary.."
        "..rather than definite (see updateNegLineNb())"
        sign == "-" && {lineEnd := convertNegLineNb(lineEnd, context)}
        context.exclusiveRange? && {lineEnd -= 1}
        sign == "+" && {lineEnd := i + lineEnd}
        lineEnd
    }

    print("DEBUG i", i)
    print("DEBUG lineEnd", lineEnd)
    exit(123)
    until(():{i == lineEnd}, (_):{
        i += 1
        var line getline()
        line == $nil && die("Out of bounds: `" + sign + nb + {
            tern(context.exclusiveRange?, "[", "") + "`"
        })

        "skip to first line number and process it"
        not(context.succeedsRange?) && i == lineEnd && process(line)

        "process all"
        context.succeedsRange? && process(line)

        sign == "-" && context.succeedsRange? && {
            updateNegLineNb(&lineEnd)
        }
        print("DEBUG i", i)
        print("DEBUG lineEnd", lineEnd)
    })
}

var evalLineNb (OUT input, OUT context, process):{
    var lineNb consumeLineNb(&input)
    interpretLineNb(lineNb, &context, process)
}

var evalProgram _

var evalLines (OUT input, OUT context, processLine):{
    do_while((1st_it?):{
        1st_it? || {
            discard(&input, 1) -- ","
            "make sure it's not a trailing comma"
            peekLineNb(input) || peekStr(input, "..") || {
                die("Trailing comma in `," + input + "`")
            }
            consumeExtra(&input)
        }

        peekLineNb(input) && {
            evalLineNb(&input, &context, processLine)
            consumeExtra(&input)
        }

        peekStr(input, "..") && {
            discard(&input, 2)
            consumeExtra(&input)
            context.succeedsRange? := $true
            var case CaseAnalysis(Bool)

            case(peekLineNb(input), {
                var lineNb consumeLineNb(&input)
                consumeExtra(&input)
                peekStr(input, "[") && {
                    discard(&input, 1)
                    consumeExtra(&input)
                    context.exclusiveRange? := $true
                }
                interpretLineNb(lineNb, &context, processLine)
                context.exclusiveRange? := $false
            })

            case(_, {
                peekStr(input, "[") && {
                    discard(&input, 1)
                    consumeExtra(&input)
                    context.exclusiveRange? := $true
                }
                "handle open end range"
                interpretLineNb(['sign:"-", 'nb:1], &context, processLine)
                context.exclusiveRange? := $false
            })

            context.succeedsRange? := $false
        }
    }, ():{peekStr(input, ",")})
}

var evalStackOp (OUT input, OUT context):{
    var processLine (line):{
        len(g_stacks) > 0 || die()
        g_stacks[#-1] += line
    }

    discard(&input, 1) -- "s"
    consumeExtra(&input)

    do_while((1st_it?):{
        1st_it? || {
            discard(&input, 1) -- ","
            "make sure it's not a trailing comma"
            peekLineNb(input) || peekStr(input, "..") || {
                peekAny(input, "{(") || {
                    die("Trailing comma in `," + input + "`")
                }
            }
            consumeExtra(&input)
        }

        var peek CaseAnalysis((c):{peekStr(input, c)})

        peek("(", {
            ; "TODO: will eval Lines"
        })

        peek("{", {
            ; "TODO: will eval Program"
        })

        peek(_, {
            var peekAny? $false

            peekLineNb(input) && {
                peekAny? := $true

                evalLineNb(&input, &context, processLine)
                consumeExtra(&input)
            }

            peekStr(input, "..") && {
                peekAny? := $true

                discard(&input, 2)
                consumeExtra(&input)
                context.succeedsRange? := $true
                var case CaseAnalysis(Bool)

                case(peekLineNb(input), {
                    var lineNb consumeLineNb(&input)
                    consumeExtra(&input)
                    peekStr(input, "[") && {
                        discard(&input, 1)
                        consumeExtra(&input)
                        context.exclusiveRange? := $true
                    }
                    interpretLineNb(lineNb, &context, processLine)
                    context.exclusiveRange? := $false
                })

                case(_, {
                    peekStr(input, "[") && {
                        discard(&input, 1)
                        consumeExtra(&input)
                        context.exclusiveRange? := $true
                    }
                    "handle open end range"
                    interpretLineNb(['sign:"-", 'nb:1], &context, processLine)
                    context.exclusiveRange? := $false
                })

                context.succeedsRange? := $false
            }

            peekAny? || {
                interpretLineNb(['sign:"+", 'nb:1], &context, processLine)
            }
        })
    }, ():{peekStr(input, ",")})
}

var evalUnstackOp (OUT input, OUT context, processLine):{
    discard(&input, 1) -- "S"
    consumeExtra(&input)

    let currStack g_stacks[#-1]
    len(g_stacks) > 0 && len(currStack) > 0 || {
        die("Unstacking an empty stack at `" + input + "`")
    }
    processLine(currStack[#-1])
    currStack := currStack[#1..<-1]
}

var evalCommand (OUT input, OUT context, processLine):{
    var peek CaseAnalysis((c):{peekStr(input, c)})

    -- {
        peek("q", evalQueueOp(&input, &context))
        peek("Q", evalUnqueueOp(&input, &context))
    }

    peek("s", evalStackOp(&input, &context))
    peek("S", evalUnstackOp(&input, &context, processLine))

    peek(_, {
        var lines? peekLineNb(input)
        lines? ||= peekStr(input, "..") || peekStr(input, "{")
        lines? || die("Unknown operation in `" + input + "`")
        evalLines(&input, &context, processLine)
    })
}

evalProgram := (OUT input, OUT context, processLine):{
    g_stacks += [[]]
    consumeExtra(&input)
    until(():{input == ""}, (1st_it?):{
        not(1st_it?) && peekStr(input, ";") && {
            discard(&input, 1)
            consumeExtra(&input)
        }
        evalCommand(&input, &context, processLine)
        consumeExtra(&input)
    })
    g_stacks := g_stacks[#1..<-1]
}

{
    var prog $args[#1]
    var context [
        'currLineNb => 0
        'succeedsRange? => $false
        'exclusiveRange? => $false
    ]
    var processLine print

    evalProgram(&prog, &context, processLine)
}

