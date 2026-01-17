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

var foreach {
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
