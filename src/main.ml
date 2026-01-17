#!/usr/bin/env monlang

"=== mlp: BEGIN src/smallstd.ml ==============================================="

var tern (cond, if_true, if_false):{
    var res _
    cond && {res := if_true}
    cond || {res := if_false}
    res
}

-- var !tern (cond, if_false, if_true):{
    tern(cond, if_true, if_false)
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

var while (cond, do):{
    var 1st_it $true
    var loop _
    loop := ():{
        cond() && {
            do(1st_it)
            1st_it := $false
            _ := loop()
        }
    }
    loop()
    ;
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
"=== mlp: END src/smallstd.ml (finally back to /home/motyak/devv/playground/reorder_lang/src/main.mlp) ==="
"=== mlp: BEGIN src/utils/parsing.mlp ========================================="


var peekStr (input, str):{
    len(input) >= len(str) && input[#1..len_str] == str
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
"=== mlp: END src/utils/parsing.mlp (finally back to /home/motyak/devv/playground/reorder_lang/src/main.mlp) ==="

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
        sign := input[#1]
        input := input[#2..-1]
    }

    var nth 1
    while(():{input[#nth] in '0 .. '9}, (_):{
        nth += 1
    })
    
    var str tern(input == "", "", input[#1..<nth])
    str <> "" || die("Invalid line number in `" + input + "`")
    input := tern(nth > len(input), "", input[#nth..-1])
    var lineNb parseInt(str)

    ['sign:sign, 'lineNb:lineNb]
}

var interpretLineNb (_lineNb, OUT context):{
    var sign _lineNb.sign
    var lineNb _lineNb.lineNb
    TODO
}

var evalLineNb (OUT input, OUT context):{
    var lineNb consumeLineNb(&input)
    interpretLineNb(lineNb, &context)
}

var evalLines (OUT input, OUT context):{
    var fromRange? $false

    peekLineNb(input) && {
        evalLineNb(&input, &context)
        consumeExtra(&input)
        fromRange? := $true
    }

    peekStr("..") && {
        discard(&input, 2)
        consumeExtra(&input)
        var case CaseAnalysis(Bool)

        case(peekLineNb(input), {
            context['succeedsRange?] := $true
            peekStr("[") && {
                discard(&input, 1)
                context['exclusiveRange?] := $true
            }
            evalLineNb(&input, &context)
            context['succeedsRange?] := $false
            context['exclusiveRange?] := $false
        })

        case(fromRange? == $false, {
            "handle full range"
        })
    }
    





    var case CaseAnalysis(Bool)

    case(peekStr(input, ".."), {
        discard(&input, 2)
        consumeExtra(&input)
    })

    case(_, {

    })

    
    case(input[#1] in "+-", {
        len(input >= 2) || die()
        var sign input[#1]
        input := input[#2..-1]
        var lineNb consumeLineNb(&input)
        
    })

    

    case(_, {
        "starts with [0-9]"
    })
    
    case(input[#1] in "+-", {

    })
    peekStr(input, "..") || {
        
    }
}

var evalProgram _

var evalCommand (OUT input, OUT context):{
    var peek CaseAnalysis((c):{peekStr(input, c)})

    -- {
        peek("q") && evalQueueOp(&input, &context)
        peek("Q") && evalUnqueueOp(&input, &context)
        peek("s") && evalStackOp(&input, &context)
        peek("S") && evalUnstackOp(&input, &context)
        peek("{") && {
            context['subProgram?] == $false || die("Can't nest sub-programs")
            context['subProgram?] := $true
            evalProgram(&input, &context)
            context['subProgram?] := $false
        }
    }

    peek(_) && {
        var lines? peekStr(input, "..") || peekLineNb(input)
        lines? || die("Unknown operation in `" + input + "`")
        evalLines(&input, &context)
    }
    ;
}

evalProgram := (OUT input, OUT context):{
    consumeExtra(&input)
    until(():{input == ""}, (1st_it):{
        not(1st_it) && peek(input, ";") && {
            discard(&input, 1)
            consumeExtra(&input)
        }
        evalCommand(&input, &context)
        consumeExtra(&input)
    })
}

var prog $args[#1]

consumeExtra()


"interpret range"
{
    var range consumeRange(&prog)

    var curr 1
    var line _

    var loop _

    loop := ():{
        line := getline()
        curr == range.fromLine || {
            curr += 1
            loop()
        }
    }
    loop()
    line == $nil || print(line)

    loop := ():{
        line := getline()
        curr >= range.toLine || {
            print(line)
            curr += 1
            loop()
        }
    }
    loop()
}

"interpret line number"
-- {
    var lineNb consumeLineNb(&prog)
    var curr 1
    var line _

    var loop _
    loop := ():{
        line := getline()
        curr >= lineNb || {
            curr += 1
            loop()
        }
    }
    loop()

    print(line)
}
