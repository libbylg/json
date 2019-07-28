package main

import (
    "fmt"
    "github.com/antchfx/jsonquery"
    "os"
    "strings"
    "io"
)

func showHelp(args []string) int {
    fmt.Println("Usage:")
    fmt.Println("	json -s|select  [-f|--file <FILE>] <XPATH-EXPR>")
    fmt.Println("	json -q|query   [-f|--file <FILE>] <XPATH-EXPR>")
    fmt.Println("	json -d|delete  [-f|--file <FILE>] <XPATH-EXPR>")
    fmt.Println("	json -u|update  [-f|--file <FILE>] <XPATH-EXPR> [<VALUE> [<TYPE>]]")
    fmt.Println("	json -v|--version|version")
    fmt.Println("	json -h|--help|help")
    fmt.Println("")
    fmt.Println("Options:")
    fmt.Println("   -s|select               列出所有满足表达式 <XPATH-EXPR> 的节点的标准路径")
    fmt.Println("   -q|query                查询指定表达式 <XPATH-EXPR> 下的节点的值，如果指 <XPATH-EXPR> 指向的")
    fmt.Println("                           不是叶子节点，输出空，返回 1")
    fmt.Println("   -d|delete               删除所有满足 <XPATH-EXPR> 定位表达式的节点")
    fmt.Println("   -u|update               修改指定表达式的叶子节点的值，并将修改后的结果输出到标准输出")
    fmt.Println("   [-f|--file <FILE>]      从指定的文件读取原json字符串，如果没有执行将尝试重标准输入读取")
    fmt.Println("   <XPATH-EXPR>            定位表达式")
    fmt.Println("   <VALUE>                 新的值，默认根据 <VALUE> 的字面值确定数据类型：")
    fmt.Println("                             - 如果字面值以数字打头，那么自动识别为整数或者浮点数")
    fmt.Println("                             - 如果是 true 或者 false，那么自动识别为 bool 类型")
    fmt.Println("                             - null 被自动识别为 null")
    fmt.Println("                             - 为空时，被识别为 string")
    fmt.Println("                             - 如果首字母为{，那么自动识别为对象类型")
    fmt.Println("                             - 如果首字母为[，那么自动识别为数组类型")
    fmt.Println("   <TYPE>                  当自动类型识别机制不能满足要求或者存在歧义时，可以指定数据类型，当前支持的")
    fmt.Println("                           类型有：string、bool、number、null、object、array")
    fmt.Println("   -v|--version|version    显示版本号")
    fmt.Println("   -h|--help|help          显示本帮助页")
    return 0
}

type cmdParams struct {
    command string
    file    string
    locate  string
    value   string
    typo    string
}

func (p *cmdParams) show(w io.Writer) {
    fmt.Fprintf(w, "command : %s\n", p.command)
    fmt.Fprintf(w, "file    : %s\n", p.file)
    fmt.Fprintf(w, "locate  : %s\n", p.locate)
    fmt.Fprintf(w, "value   : %s\n", p.value)
    fmt.Fprintf(w, "type    : %s\n", p.typo)
}

var commands = map[string]string{
    "-s":     "select",
    "select": "select",
    "-q":     "query",
    "query":  "query",
    "-d":     "delete",
    "delete": "delete",
    "-u":     "update",
    "update": "update",
}

func (p *cmdParams) init(args []string) error {
    //  先识别 command
    cmd, exist := commands[args[1]]
    if !exist {
        return fmt.Errorf("unsupported command '%s'", args[1])
    }
    p.command = cmd

    //  再识别参数
    for i := 2; i < len(args); i++ {
        if ("-f" == args[i]) || ("--file" == args[i]) {
            if len(args) <= (i + 1) {
                return fmt.Errorf("missing parameters for '%s'", args[i])
            }
            p.file = args[i+1]
            i++
            continue
        }

        p.locate = args[i]
        i++

        if len(args) <= i {
            break
        }
        p.value = args[i]
        i++

        if len(args) <= i {
            break
        }
        p.typo = args[i]
        i++

        return fmt.Errorf("unsupported parameter '%s'", args[i])
    }

    if "" == p.locate {
        return fmt.Errorf("missing xpath expresion, type -h for help")
    }

    return nil
}

func showVersion(args []string) int {
    fmt.Println("1.0.0")
    return 0
}

func main() {
    if len(os.Args) < 2 {
        fmt.Fprintln(os.Stderr, "Missing parameters, type -h for help")
        os.Exit(1)
    }

    if ("-h" == os.Args[1]) || ("--help" == os.Args[1]) || ("help" == os.Args[1]) {
        os.Exit(showHelp(os.Args))
    }

    if ("-v" == os.Args[1]) || ("--version" == os.Args[1]) || ("version" == os.Args[1]) {
        os.Exit(showVersion(os.Args))
    }

    os.Exit(mainImpl(os.Args))
}

func reverse(s []string) []string {
    //	特殊情况特殊处理
    if len(s) <= 1 {
        return s
    }

    //	复杂情况分配内存再拷贝
    target := make([]string, len(s))
    for i := 0; i < len(s); i++ {
        target[len(s)-1-i] = s[i]
    }

    return target
}

func pathOf(n *jsonquery.Node) []string {
    //	如果节点不是叶子节点
    paths := make([]string, 0, 3)
    for p := n; nil != p; p = p.Parent {
        //	如果遇到的是数组或者文档类型（数组和文档类型的节点名称为空）
        if "" == p.Data {
            //	如果是文档类型
            if jsonquery.DocumentNode == p.Type {
                break
            }

            //	如果遇到的是数组，先确定数组的索引，然后记录路径
            count := 1
            for v := p.PrevSibling; nil != v; v = v.PrevSibling {
                count++
            }
            paths = append(paths, fmt.Sprintf("*[%d]", count))
            continue
        }

        //	如果是命名节点
        paths = append(paths, p.Data)
    }

    return reverse(paths)
}

//func printNode(root string, n *jsonquery.Node) error {
//    if nil == n.FirstChild {
//        fmt.Printf("%s", n.Data)
//        return nil
//    }
//
//    if jsonquery.ElementNode == n.FirstChild.Type {
//        fmt.Printf("%s", n.Data)
//        return nil
//    }
//
//    if jsonquery.TextNode == n.FirstChild.Type {
//        fmt.Printf("%s", n.FirstChild.Data)
//        return nil
//    }
//
//    return fmt.Errorf("query result is a node: '%s'", n.Data)
//}

func loadDoc(filename string) (*jsonquery.Node, error) {

    if strings.HasPrefix(filename, "http://") || strings.HasPrefix(filename, "https://") {
        //	从网络读取 json 数据
        doc, err := jsonquery.LoadURL("http://www.example.com/feed?json")
        if nil != err {
            return nil, fmt.Errorf("load json content file '%s' failed, %s", filename, err.Error())
        }
        return doc, nil
    } else if "" == filename {
        //	从标准输入读取
        doc, err := jsonquery.Parse(os.Stdin)
        if nil != err {
            return nil, fmt.Errorf("load json content file 'stdin' failed, %s", err.Error())
        }
        return doc, nil
    } else {
        //	从本地文件读取
        f, err := os.Open(filename)
        if nil != err {
            return nil, fmt.Errorf("open file '%s' failed, %s\n", filename, err.Error())
        }
        defer func() {
            f.Close()
        }()

        doc, err := jsonquery.Parse(f)
        if nil != err {
            return nil, fmt.Errorf("load json content file '%s' failed, %s", filename, err.Error())
        }

        return doc, nil
    }
}

func mainImpl(args []string) int {
    //	识别命令行参数
    params := cmdParams{}
    err := params.init(args)
    if nil != err {
        fmt.Fprintln(os.Stderr, "%s", err.Error())
        return 1
    }

    //params.show(os.Stdout)

    //	打开输入文件
    doc, err := loadDoc(params.file)
    if nil != err {
        fmt.Fprintf(os.Stderr, "Load json document failed, %s\n", err.Error())
        return 3
    }

    //	根据表达式查找节点
    nodes, err := jsonquery.Find(doc, params.locate)
    if nil != err {
        fmt.Fprintf(os.Stderr, "Query json content failed, '%s' : '%s'\n", params.locate, err.Error())
        return 3
    }

    //if len(nodes) > 1 {
    //	fmt.Fprintf(os.Stderr, "Too much nodes(%d) matched\n", len(nodes))
    //	return 4
    //}

    //	将找到的节点打印出来
    for _, n := range nodes {
        //	如果n本身就是叶子节点
        if jsonquery.TextNode == n.Type {
            fmt.Println(n.Data)
            continue
        }

        //	如果n是叶子节点的key
        if (n.FirstChild == n.LastChild) && (n.FirstChild.Type == jsonquery.TextNode) {
            fmt.Println(n.FirstChild.Data)
            continue
        }

        paths := pathOf(n)
        fmt.Printf("/%s\n", strings.Join(paths, "/"))
        continue
    }

    return 0
}
