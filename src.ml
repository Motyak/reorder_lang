#!/usr/bin/env monlang

var tern (cond, if_true, if_false):{
    var res _
    cond && {res := if_true}
    cond || {res := if_false}
    res
}

var !tern (cond, if_false, if_true):{
    tern(cond, if_true, if_false)
}

-- var <> (a, b):{
    a == b == $false
}

-- var <= (a, b):{
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

var consumeLineNb (OUT input):{
    var nth 1
    var loop _
    loop := ():{
        nth > len(input) || input[#nth] < "0" || input[#nth] > "9" || {
            nth += 1
            loop()
        }
    }
    loop()
    
    var str tern(input == "", "", input[#1..<nth])
    input := tern(nth > len(input), "", input[#nth..-1])
    tern(str == "", $nil, parseInt(str))
}

var consumeRange (OUT input):{
    var fromLine consumeLineNb(&input)
    input := tern(len(input) > 2, input[#3..-1], "")
    var toLine consumeLineNb(&input)
    ['fromLine:fromLine, 'toLine:toLine]
}

var prog $args[#1]

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
