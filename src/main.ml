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
    var 1st_it $true
    var loop _
    loop := ():{
        cond() || {
            do(1st_it)
            1st_it := $false
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

```
    supposed to do a peekStr() before a discard()
```
var discard (OUT input, n):{
    input := tern(len(input) == n, "", {
        var n+1 n + 1
        input[#n+1..-1]
    })
}

var consumeStr (OUT input, str):{
    peekStr(input, str) || die("Failed to consume `" + str + "` in `" + input + "`")
    discard(&input, len(str))
}

var consumeOptStr (OUT input, optStr):{
    peekStr(input, str) && {
        discard(&input, len(str))
    }
    ;
}
"=== mlp: END src/utils/parsing.mlp (finally back to src/main.mlp) ============"

var builtin::print print
var builtin::getline getline

"override builtins"
var print print
var getline getline

var convertNegLineNb {
    var lines []
    var slurp_stdin _
    slurp_stdin := ():{
        var line builtin::getline()
        line == $nil || {
            lines += line
            _ := slurp_stdin()
        }
    }

    var i _
    var 1st_time_called? $true
    var convertNegLineNb (nb, context):{
        1st_time_called? && {
            i := context.currLineNb
            slurp_stdin()
            getline := ():{
                len(lines) > 0 || die()
                var line lines[#1]
                lines := tern(len(lines) == 1, [], lines[#2..-1])
                i += 1
                line
            }
            1st_time_called? := $false
        }
        nb <= len(lines) || die("Out of bounds: `-" + nb + "`")
        i + len(lines) - nb + 1
    }
    convertNegLineNb
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

var interpretLineNb (_lineNb, OUT context):{
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
        var line getline()

        "skip to first line number and print it"
        not(context.succeedsRange?) && i == lineEnd && {
            print(line)
        }

        "print all"
        context.succeedsRange? && {
            print(line)
        }
    })
}

var evalLineNb (OUT input, OUT context):{
    var lineNb consumeLineNb(&input)
    interpretLineNb(lineNb, &context)
}

var evalLines (OUT input, OUT context):{
    peekLineNb(input) && {
        evalLineNb(&input, &context)
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
            interpretLineNb(lineNb, &context)
            context.exclusiveRange? := $false
        })

        case(_, {
            peekStr(input, "[") && {
                discard(&input, 1)
                consumeExtra(&input)
                context.exclusiveRange? := $true
            }
            "handle open end range"
            interpretLineNb(['sign:"-", 'nb:1], &context)
            context.exclusiveRange? := $false
        })

        context.succeedsRange? := $false
    }
    ;
}

var evalProgram _

var evalCommand (OUT input, OUT context):{
    var peek CaseAnalysis((c):{peekStr(input, c)})

    -- {
        peek("q", evalQueueOp(&input, &context))
        peek("Q", evalUnqueueOp(&input, &context))
        peek("s", evalStackOp(&input, &context))
        peek("S", evalUnstackOp(&input, &context))
    }

    peek(_, {
        var lines? peekLineNb(input)
        lines? ||= peekStr(input, "..") || peekStr(input, "{")
        lines? || die("Unknown operation in `" + input + "`")
        evalLines(&input, &context)
    })
    ;
}

evalProgram := (OUT input, OUT context):{
    consumeExtra(&input)
    until(():{input == ""}, (1st_it):{
        not(1st_it) && peekStr(input, ";") && {
            discard(&input, 1)
            consumeExtra(&input)
        }
        evalCommand(&input, &context)
        consumeExtra(&input)
    })
}

var prog $args[#1]
var context [
    'currLineNb => 0
    'succeedsRange? => $false
    'exclusiveRange? => $false
]

evalProgram(&prog, &context)
