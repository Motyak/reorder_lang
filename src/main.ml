#!/usr/bin/env monlang

"=== mlp: BEGIN src/rol.mlp ==================================================="

```
    ReOrder Lang (rol)
    ------------------

    PROGRAM := (COMMAND (';'? COMMAND)*)?

    COMMAND := STACK-OP | UNSTACK-OP
            | QUEUE-OP | UNQUEUE-OP
            | CARET-OP
            | LINES

    SUB-PROGRAM := '{' PROGRAM '}'
    LINES := (LINE-NB | RANGE | SUB-PROGRAM)
        | (LINE-NB | RANGE | SUB-PROGRAM) ',' LINES
    GROUPED-LINES := '(' LINES ')'

    RANGE := LINE-NB? '..' LINE-NB? '['?
    LINE-NB := ('-' | '+')? [0-9]+

    STACK-OP := 's' (
                    (LINE-NB | RANGE | SUB-PROGRAM | GROUPED-LINES)
                    (',' (LINE-NB | RANGE | SUB-PROGRAM | GROUPED-LINES))*
                )?

    UNSTACK-OP := 'S' '*'?

    QUEUE-OP := 'q' (
                    (LINE-NB | RANGE | SUB-PROGRAM | GROUPED-LINES)
                    (',' (LINE-NB | RANGE | SUB-PROGRAM | GROUPED-LINES))*
                )?

    UNQUEUE-OP := 'Q' '*'?

    CARET-OP := '^' (LINES | UNSTACK-OP | UNQUEUE-OP)?
```

"=== mlp: BEGIN src/smallstd.mlp =============================================="

var tern (cond, if_true, if_false):{
    var res _
    cond && {res := if_true}
    cond || {res := if_false}
    res
}

var !tern (cond, if_false, if_true):{
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

var foreach {
    var Container::foreach (OUT container, fn):{
        var nth 1
        until(():{nth > len(container)}, (_):{
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
"=== mlp: END src/smallstd.mlp (back to src/rol.mlp) =========================="
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
"=== mlp: END src/utils/parsing.mlp (back to src/rol.mlp) ====================="

var rol::evalProgram _
var rol::evalCommand _
var rol::evalStackOp _
var rol::evalUnstackOp _
var rol::evalQueueOp _
var rol::evalUnqueueOp _
var rol::evalLines _
var rol::evalLineNb _
{
    var original::nextLine _
    var nextLine _
    var convertNegLineNb _
    var interpretNegLineNbGradually _
    var setup_rol (_nextLine):{
        original::nextLine := tern(_nextLine == $nil, getline, _nextLine)
        nextLine := tern(_nextLine == $nil, getline, _nextLine)
        var lines [] -- buffer

        var slurp_input _
        slurp_input := ():{
            var line original::nextLine()
            line == $nil || {
                lines += [line]
                _ := slurp_input()
            }
        }

        var i _
        var 1st_time_called? $true
        convertNegLineNb := (nb, context):{
            1st_time_called? && {
                i := context.currLineNb
                slurp_input()
                nextLine := ():{
                    tern(len(lines) == 0, $nil, {
                        var line lines[#1]
                        lines := tern(len(lines) == 1, [], lines[#2..-1])
                        i += 1
                        line
                    })
                }
                1st_time_called? := $false
            }
            i + len(lines) - nb + 1
        }

        interpretNegLineNbGradually := (_lineNb, OUT context, processLine):{
            var sign _lineNb.sign
            var nb _lineNb.nb
            let i context.currLineNb

            "create buffer"
            {
                var n tern(context.exclusiveRange?, nb, nb - 1)
                var i 1
                var loop _
                loop := ():{
                    i > n || {
                        var line original::nextLine()
                        line == $nil || {
                            lines += [line]
                            i += 1
                            _ := loop()
                        }
                    }
                }
                loop()
                len(lines) < n && die("Out of bounds: `-" + nb + {
                    tern(context.exclusiveRange?, "[", "") + "`"
                })
            }

            {
                var loop _
                loop := ():{
                    var line original::nextLine()
                    line == $nil || {
                        lines += [line]
                        processLine(lines[#1])
                        lines := tern(len(lines) == 1, [], lines[#2..-1])
                        i += 1
                        _ := loop()
                    }
                }
                loop()
            }

            nextLine := ():{
                len(lines) == 0 && {
                    var line original::nextLine()
                    line == $nil || {lines += [line]}
                }
                tern(len(lines) == 0, $nil, {
                    var line lines[#1]
                    lines := tern(len(lines) == 1, [], lines[#2..-1])
                    -- i += 1 -- "we DONT increment it, caller will"
                    line
                })
            }
        }
    } -- "END of setup_rol"


    var consumeExtra {
        var whitespaces "\n" + " " + Byte(9)
        var consumeWhitespaces (OUT input):{
            var nth 1
            until(():{nth > len(input) || input[#nth] !in whitespaces}, (_):{
                nth += 1
            })
            input := tern(nth > len(input), "", input[#nth..-1])
        }
        var consumeComment (OUT input):{
            var nth 1
            var loop _
            loop := ():{
                nth > len(input) || {
                    input[#nth] == "\n" || {
                        nth += 1
                        _ := loop()
                    }
                    nth += 1 -- \n
                }
            }
            loop()
            input := tern(nth > len(input), "", input[#nth..-1])
        }
        var consumeExtra (OUT input):{
            var loop _
            loop := ():{
                consumeWhitespaces(&input)
                peekStr(input, "--") && {
                    consumeComment(&input)
                    _ := loop()
                }
            }
            loop()
        }
        consumeExtra
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

    "handle anything else than gradual neg line nb"
    var _interpretLineNb (_lineNb, OUT context, processLine):{
        var sign _lineNb.sign
        var nb _lineNb.nb
        let i context.currLineNb

        var lineEnd {
            var lineEnd nb
            sign == "-" && {lineEnd := convertNegLineNb(lineEnd, context)}
            context.exclusiveRange? && {lineEnd -= 1}
            sign == "+" && {lineEnd := i + lineEnd}
            lineEnd
        }

        until(():{i == lineEnd}, (_):{
            i += 1
            var line nextLine()
            line == $nil && die("Out of bounds: `" + sign + nb + {
                tern(context.exclusiveRange?, "[", "") + "`"
            })

            "skip to first line number and process it"
            not(context.succeedsRange?) && i == lineEnd && processLine(line)

            "process all"
            context.succeedsRange? && processLine(line)
        })
    }

    var interpretLineNb _
    interpretLineNb := (lineNb, OUT context, processLine):{
        var gradualMode {
            lineNb.sign == "-" && context.succeedsRange?
        }
        gradualMode && {
            interpretNegLineNbGradually(lineNb, &context, processLine)
        }
        gradualMode || {
            _interpretLineNb(lineNb, &context, processLine)
        }
        lineNb.sign == "-" && {
            "gradual mode can't happen anymore => no longer need to check"
            interpretLineNb := _interpretLineNb
        }
    }

    var evalLineNb (OUT input, OUT context, processLine):{
        var lineNb consumeLineNb(&input)
        interpretLineNb(lineNb, &context, processLine)
    }

    var evalProgram _

    var evalLines (OUT input, OUT context, processLine):{
        do_while((1st_it?):{
            1st_it? || {
                discard(&input, 1) -- ","
                consumeExtra(&input)
                "make sure it's not a trailing comma"
                peekLineNb(input) || peekStr(input, "..") || {
                    die("Trailing comma in `," + input + "`")
                }
            }

            var peek CaseAnalysis((c):{peekStr(input, c)})
            peek("{", {
                discard(&input, 1) -- "{"
                consumeExtra(&input)

                var backup context.subProgram?
                context.subProgram? := $true
                evalProgram(&input, &context, processLine)
                context.subProgram? := backup

                peekStr(input, "}") || {
                    die("Missing closing brace in `" + input + "`")
                }
                discard(&input, 1) -- "}"
                consumeExtra(&input)
            })

            peek(_, {
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
            })
        }, ():{peekStr(input, ",")})
    }

    var evalStackOp (OUT input, OUT context):{
        var processLine (line):{
            len(context.stacks) > 0 || die()
            context.stacks[#-1] += [line]
        }

        discard(&input, 1) -- "s"
        consumeExtra(&input)

        do_while((1st_it?):{
            1st_it? || {
                discard(&input, 1) -- ","
                consumeExtra(&input)
                "make sure it's not a trailing comma"
                peekLineNb(input) || peekStr(input, "..") || {
                    peekAny(input, "{(") || {
                        die("Trailing comma in `," + input + "`")
                    }
                }
            }

            var peek CaseAnalysis((c):{peekStr(input, c)})

            peek("(", {
                discard(&input, 1) -- "("
                consumeExtra(&input)

                var groupedLines []
                var processLine (line):{
                    groupedLines += [line]
                }
                evalLines(&input, &context, processLine)

                peekStr(input, ")") || {
                    die("Missing closing parentheses in `" + input + "`")
                }
                discard(&input, 1) -- ")"
                consumeExtra(&input)

                context.stacks[#-1] += [groupedLines]
            })

            peek("{", {
                discard(&input, 1) -- "{"
                consumeExtra(&input)

                var lines []
                var processLine (line):{
                    lines += [line]
                }
                var backup context.subProgram?
                context.subProgram? := $true
                evalProgram(&input, &context, processLine)
                context.subProgram? := backup

                peekStr(input, "}") || {
                    die("Missing closing brace in `" + input + "`")
                }
                discard(&input, 1) -- "}"
                consumeExtra(&input)

                context.stacks[#-1] += lines
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

        len(context.stacks) > 0 || die()
        let currStack context.stacks[#-1]
        var peek CaseAnalysis((c):{peekStr(input, c)})

        peek("*", {
            discard(&input, 1) -- "*"
            consumeExtra(&input)
            until(():{len(currStack) == 0}, (_):{
                $type(currStack[#-1]) == 'List && {
                    foreach(currStack[#-1], processLine)
                    ;
                }
                $type(currStack[#-1]) == 'Str && {
                    processLine(currStack[#-1])
                }
                currStack := currStack[#1..<-1]
            })
        })

        peek(_, {
            len(currStack) > 0 || {
                die("Unstacking an empty stack at `" + input + "`")
            }
            $type(currStack[#-1]) == 'List && {
                foreach(currStack[#-1], processLine)
                ;
            }
            $type(currStack[#-1]) == 'Str && {
                processLine(currStack[#-1])
            }
            currStack := currStack[#1..<-1]
        })
    }

    var evalQueueOp (OUT input, OUT context):{
        var processLine (line):{
            len(context.queues) > 0 || die()
            context.queues[#-1] += [line]
        }

        discard(&input, 1) -- "q"
        consumeExtra(&input)

        do_while((1st_it?):{
            1st_it? || {
                discard(&input, 1) -- ","
                consumeExtra(&input)
                "make sure it's not a trailing comma"
                peekLineNb(input) || peekStr(input, "..") || {
                    peekAny(input, "{(") || {
                        die("Trailing comma in `," + input + "`")
                    }
                }
            }

            var peek CaseAnalysis((c):{peekStr(input, c)})

            peek("(", {
                discard(&input, 1) -- "("
                consumeExtra(&input)

                var groupedLines []
                var processLine (line):{
                    groupedLines += [line]
                }
                evalLines(&input, &context, processLine)

                peekStr(input, ")") || {
                    die("Missing closing parentheses in `" + input + "`")
                }
                discard(&input, 1) -- ")"
                consumeExtra(&input)

                context.queues[#-1] += [groupedLines]
            })

            peek("{", {
                discard(&input, 1) -- "{"
                consumeExtra(&input)

                var lines []
                var processLine (line):{
                    lines += [line]
                }
                var backup context.subProgram?
                context.subProgram? := $true
                evalProgram(&input, &context, processLine)
                context.subProgram? := backup

                peekStr(input, "}") || {
                    die("Missing closing brace in `" + input + "`")
                }
                discard(&input, 1) -- "}"
                consumeExtra(&input)

                context.queues[#-1] += lines
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

    var evalUnqueueOp (OUT input, OUT context, processLine):{
        discard(&input, 1) -- "Q"
        consumeExtra(&input)

        len(context.queues) > 0 || die()
        let currQueue context.queues[#-1]
        var peek CaseAnalysis((c):{peekStr(input, c)})

        peek("*", {
            discard(&input, 1) -- "*"
            consumeExtra(&input)
            until(():{len(currQueue) == 0}, (_):{
                $type(currQueue[#1]) == 'List && {
                    foreach(currQueue[#1], processLine)
                    ;
                }
                $type(currQueue[#1]) == 'Str && {
                    processLine(currQueue[#1])
                }
                currQueue := tern(len(currQueue) == 1, [], currQueue[#2..-1])
            })
        })

        peek(_, {
            len(currQueue) > 0 || {
                die("Unqueueing an empty queue at `" + input + "`")
            }
            $type(currQueue[#1]) == 'List && {
                foreach(currQueue[#1], processLine)
                ;
            }
            $type(currQueue[#1]) == 'Str && {
                processLine(currQueue[#1])
            }
            currQueue := tern(len(currQueue) == 1, [], currQueue[#2..-1])
        })
    }

    var evalCaretOp (OUT input, OUT context):{
        discard(&input, 1) -- "^"
        consumeExtra(&input)

        var processLine context.rootProcessLine
        var peek CaseAnalysis((c):{peekStr(input, c)})
        peek("S", evalUnstackOp(&input, &context, processLine))
        peek("Q", evalUnqueueOp(&input, &context, processLine))
        peek(_, {
            var lines? peekLineNb(input)
            lines? ||= peekStr(input, "..") || peekStr(input, "{")
            lines? || die("Unknown operation in `" + input + "`")
            evalLines(&input, &context, processLine)
        })
    }

    var evalCommand (OUT input, OUT context, processLine):{
        var peek CaseAnalysis((c):{peekStr(input, c)})

        peek("s", evalStackOp(&input, &context))
        peek("S", evalUnstackOp(&input, &context, processLine))
        peek("q", evalQueueOp(&input, &context))
        peek("Q", evalUnqueueOp(&input, &context, processLine))
        peek("^", evalCaretOp(&input, &context))
        peek(_, {
            var lines? peekLineNb(input)
            lines? ||= peekStr(input, "..") || peekStr(input, "{")
            lines? || die("Unknown operation in `" + input + "`")
            evalLines(&input, &context, processLine)
        })
    }

    evalProgram := (OUT input, OUT context, processLine):{
        context.subProgram? || {
            context['rootProcessLine] := processLine
        }
        context.stacks += [[]]
        context.queues += [[]]
        consumeExtra(&input)
        until(():{input == "" || context.subProgram? && input[#1] == "}"}, (1st_it?):{
            not(1st_it?) && peekStr(input, ";") && {
                discard(&input, 1)
                consumeExtra(&input)
            }
            evalCommand(&input, &context, processLine)
            consumeExtra(&input)
        })
        context.stacks := context.stacks[#1..<-1]
        context.queues := context.queues[#1..<-1]
    }

    "now exporting local symbols"
    var setup_and_call (fn):{
        (nextLine):{
            (varargs...):{
                setup_rol(nextLine) -- reset internal state
                fn(varargs...)
            }
        }
    }
    rol::evalProgram := setup_and_call(evalProgram)
    rol::evalCommand := setup_and_call(evalCommand)
    rol::evalStackOp := setup_and_call(evalStackOp)
    rol::evalUnstackOp := setup_and_call(evalUnstackOp)
    rol::evalQueueOp := setup_and_call(evalQueueOp)
    rol::evalUnqueueOp := setup_and_call(evalUnqueueOp)
    rol::evalLines := setup_and_call(evalLines)
    rol::evalLineNb := setup_and_call(evalLineNb)
} -- "END of rol::"
"=== mlp: END src/rol.mlp (finally back to src/main.mlp) ======================"

var nextLine {
    var str ```
        1
        2
        3
        4
        5
    ```

    var i 1
    var nextLine ():{
        tern(i > len(str), $nil, {
            var line ""
            var loop _
            loop := ():{
                i > len(str) || {
                    str[#i] == "\n" || {
                        line += str[#i]
                        i += 1
                        _ := loop()
                    }
                    i += 1 -- discard \n
                }
            }
            loop()
            line
        })
    }
    nextLine
}

var evalProgram {
    var nextLine getline -- toggle
    rol::evalProgram(nextLine)
}

{
    var prog $args[#1]
    var context [
        'currLineNb => 0
        'stacks => [] -- "stack of stacks (for nested programs)"
        'queues => [] -- "stack of queues (for nested programs)"
        'subProgram? => $false
        'succeedsRange? => $false
        'exclusiveRange? => $false
    ]
    var processLine print

    evalProgram(prog, context, processLine)
}
