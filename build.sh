#!/usr/bin/env bash



# coding=utf-8
import sys
from optparse import OptionParser
import os
import commands
import time
from config import *
from scanner import scanAllRisk
import subprocess

#日志方法
def log(str, highlight = False):

    #strftime: 格式化时间    localtime()以当前时间为转换标准，格式化时间戳为本地时间
    nowtime = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())

    if highlight:
        # \033[前景色1;31m     背景色m
        print nowtime + ' -- \033[1;31m%s\033[0m' % str
    else:
        print nowtime + ' -- ' + str

#帮助方法
def help():

    log("")
    log("*" * 100)
    log("该脚本用于编译导航SDK产物")
    log("使用方法:python %s [-l:s]" % sys.argv[0])
    for option in navi_build_config["options"]:
    
        log("%s %s\t\t\t%s" % (navi_build_config["options"][option]["short_option"], navi_build_config["options"][option]["long_option"], navi_build_config["options"][option]["usage"]))
    
    log("*" * 100)

def newExecComand(exec_command, tag, logTime = False):
    """
    新的执行命令并打屏方法
    exec_command：shell命令行
    tag：命令描述描述
    logTime：log时间
    """
    if logTime:
        log("start to " + tag)

    log("Command is " + exec_command)
    
    p = subprocess.Popen(exec_command, shell=True, stdout=subprocess.PIPE)
    outputScreen = p.stdout.readlines()

    for line in outputScreen:
        print line.strip()

#执行命令 参数= XXX ，用默认值False
def execCommand(exec_command, tag, logTime = False):
    
    logTime = True
    if logTime:
        log("start to " + tag)
    
    log("command is " + exec_command)
    
    err, output = commands.getstatusoutput(exec_command)
    if err != 0:
        log("*******************")
        log("[execCommand - output] %s" % (output))
        log("*******************")
        raise Exception("%s get error %s " % (tag, output))
    if logTime:
        log("end of " + tag)

#获取引擎产物
def getEngineBuildOutput():
    
    local_path = os.path.dirname(os.path.abspath(__file__))
    #获取引擎代码
    execCommand("git clone ssh://git@icode.baidu.com:8235/%s lib && cd lib && git checkout %s" % (navi_build_config["engine"]["code_path"], navi_build_config["engine"]["branch_name"]), "get navi engine code", True)
    execCommand("mv %s/lib ../../../../../" % (local_path), "copy navi engine code")
    
    #更新引擎头文件
    if navi_build_config["engine"]["update_header"]:
        execCommand("cd ../../../../../lib && sh get_comengine.sh", "update navi engine header", True)

    if not navi_build_config["engine"]["source_build"]:

        #获取AGILE目录，取得最新产物路径
        execCommand("wget -t1 --timeout=60 -q getprod@%s --user getprod --password getprod" % navi_build_config["engine"]["agile_output_path"], "get AGILE dir", True)
        
        execCommand("wget  -t2 --timeout=240 -r -nH --level=0 --cut-dirs=9 getprod@%s`cat index.html | grep latest | tr '\t' ' ' | tr -s ' ' | cut -d ' '  -f 10`/output/Release-iphoneos.zip  --user getprod --password getprod --preserve-permissions" % navi_build_config["engine"]["agile_output_path"], "get navi engine Release-iphoneos compile output", True)
        execCommand("wget  -t2 --timeout=240 -r -nH --level=0 --cut-dirs=9 getprod@%s`cat index.html | grep latest | tr '\t' ' ' | tr -s ' ' | cut -d ' '  -f 10`/output/navi_ver  --user getprod --password getprod --preserve-permissions" % navi_build_config["engine"]["agile_output_path"], "get navi engine vertion info", True)
        #拷贝产物
        execCommand("unzip output/Release-iphoneos.zip -d compile_output", "unzip compile output", True)
        execCommand("cp output/navi_ver compile_output", "copy navi version file", True)

        if navi_build_config["options"]["all_arm_output"]['open']:

            #获取最新产物
            execCommand("wget -r -nH --level=0 --cut-dirs=9 getprod@%s`cat index.html | grep latest | tr '\t' ' ' | tr -s ' ' | cut -d ' '  -f 10`/output/Debug-iphonesimulator.zip  --user getprod --password getprod --preserve-permissions" % navi_build_config["engine"]["agile_output_path"], "get navi engine Debug-iphonesimulator compile output", True)
            #拷贝产物
            execCommand("unzip output/Debug-iphonesimulator.zip -d compile_output", "unzip compile output", True)
            
    newExecComand("ls -l | tee", 'get 引擎代码完毕，check当前目录下文件', True)

#编译前的预处理
def preCompile():

    log( '开始编译预处理')
    pwd_shell = 'pwd'
    pwdstr =  commands.getoutput(pwd_shell)
    newExecComand('pwd', '--开始编译预处理时，当前下载目录是--')
    newExecComand('ls -l | tee', '--开始编译预处理时，当前目录下文件列表是--')

    #execCommand("rm -rf ../baiduNaviSDK/output && mkdir -p ../baiduNaviSDK/output && cp -fr ../pub ../baiduNaviSDK/output/", "pre compile process")
    execCommand("rm -rf ../baiduNaviSDK/output && mkdir -p ../baiduNaviSDK/output && cp -fr ../pub ../baiduNaviSDK/output/", "pre compile process")


    if navi_build_config["options"]["update_baseline_header"]['open']:
        newExecComand("开始译预处理", "cd ../.., git pub代码，更新基线头文件")
        execCommand("cd ../.. && git clone ssh://git@icode.baidu.com:8235/baidu/mapclient/iphone-com-pub --depth 1 --branch %s && cd iphone-com-pub/123Go && python update_libs.py \"auto_find\" \"iphone-com-pub\" --3rd --baseline --branch-name=\"%s\" && cd ../../ios && python update_baseline_header.py ../iphone-com-pub" % (navi_build_config["baseline"]["pub_branch_name"], navi_build_config["baseline"]["dev_branch_name"]), "start to update header", True)

#编译后处理
function afterCompile()
{
    
    log( '开始编译后处理')
    pwd_shell = 'pwd'
    pwdstr = commands.getoutput(pwd_shell)
    #newExecComand('pwd', '--开始编译后处理时，当前下载目录是--')
    #newExecComand('ls -l | tee', '--开始编译后处理时，当前目录下文件列表--')
    echo    "generate version info"
    cd ../ && git log -1 | grep commit | cut -d ' ' -f 2 >  baiduNaviSDK/output/navi_ver

    if [[ "" != $(json -f ${navi_build_config} "/engine/source_build") ]]; then
        echo    "generate version info"
        cd      ../../../../../lib && \
        git     log -1 | grep commit | cut -d ' ' -f 2 >> ../app/naviapp/baidu-navi/ios/baiduNaviSDK/output/navi_ver && \
        cd      ../app/naviapp/baidu-navi/ios/baiduNaviSDK/ && \
        date    +%Y-%m-%d-%H:%M:%S >> output/navi_ver
    else
        echo    "generate version info"
        cat     compile_output/navi_ver >> ../baiduNaviSDK/output/navi_ver  && \
        cd      ../baiduNaviSDK/                                            && \
        date    +%Y-%m-%d-%H:%M:%S >> output/navi_ver
    fi

    echo    "compress output"
    cd      ../baiduNaviSDK/output  &&  \
    cp      navi_ver pub            &&  \
    zip     -r pub.zip pub          &&  \
    rm      -rf pub

    if navi_build_config["options"]["scan_code_risk"]["open"]:

    scanAllRisk()

    echo  "scan code risk"
    mkdir   ../baiduNaviSDK/output/AssistInfo           && \
    mv      test_*  ../baiduNaviSDK/output/AssistInfo   && \
    mv      macro* ../baiduNaviSDK/output/AssistInfo
    
}

#编译导航SDK产物
def compileNaviSDK():
    
    preCompile()
    
    flag = "-s" if navi_build_config["engine"]["source_build"] else ""
    flag = "%s -b" % flag if navi_build_config["options"]["bitcode_compile"]['open'] else flag

    execCommand("sh buildSDK.sh %s" % flag, "compile iphone os Release version", True)
    
    #计算代码和产物大小
    execCommand("sh CodeNumAndSize.sh", "calculate code and output size")

    if navi_build_config["options"]["all_arm_output"]['open']:
        
        execCommand("sh buildSDK.sh -D -S %s" % flag, "compile iphone simulator Debug version", True)
    #execCommand("sh buildSDK.sh -D %s" % flag, "", True)

    afterCompile()

#设置可用选项
function setParamConfig()
    
    #parser = OptionParser()
    
    #设置选项
    for option in $(json -f "${navi_build_config}" "/options/*"); do
    
        option1 = $(json -f "${navi_build_config}" "/options/${option}/short_option")
        option2 = $(json -f "${navi_build_config}" "/options/${option}/long_option")
        pAction = "store_true"
        pDest = "${option}"
        pDefault = False
        pHelp = "open option ${option}"
        #parser.add_option(option1, option2, action = pAction, dest = pDest, default = pDefault, help = pHelp)  //  TODO
    done 
    
    #设置测试开关
    for key in $(json -f "${navi_build_config}" "/test_mode/*"); do
        option1 = ""
        option2 = "--${key}"
        pAction = "store"
        pDest = "${key}"
        pDefault = ""
        pHelp = "open ${key} Flag"
        #parser.add_option(option1, option2, action = pAction, dest = pDest, default = pDefault, help = pHelp)  //  TODO
    done

    (options, args) = parser.parse_args()

    #根据设置打开开关
    for key,value in options.__dict__.items(); do
       
        if value == "Default":
            continue
         
        if value == "True":
            navi_build_config["test_mode"][key]['open'] = True
        
        if value == "False":
            navi_build_config["test_mode"][key]['open'] = False

        if type(value) == type(True):
            navi_build_config["options"][key]['open'] = value
    done
    
    if navi_build_config["options"]["source_compile"]['open']:
        navi_build_config["engine"]["source_build"] = True

    if navi_build_config["options"]["source_compile_with_update_header"]['open']:
        navi_build_config["engine"]["source_build"] = True
        navi_build_config["engine"]["update_header"] = True

    if navi_build_config["options"]["update_header"]['open']:
        navi_build_config["engine"]["update_header"] = True

#设置测试模式
def setTestMode():

    for key in navi_build_config["test_mode"]:

        if navi_build_config["test_mode"][key].has_key('open'):
            
            for config in navi_build_config["test_mode"][key]['config']:

                filepath = config['define_path']
                definename = config['define_name']
                
                if navi_build_config["test_mode"][key]['isEngine']:
                    if navi_build_config["test_mode"][key]['open']:
                        execCommand("iconv -f latin1 -t utf-8 %s > temp && cat temp | sed 's/^\/\/#define %s$/#define %s/' > temp2 && iconv -f utf-8 -t latin1 temp2 > %s && rm temp && rm temp2" % (filepath, definename, definename, filepath), "open engine test flag %s" % definename, True)
                    else:
                        execCommand("iconv -f latin1 -t utf-8 %s > temp && cat temp | sed 's/^#define %s$/\/\/#define %s/' > temp2 && iconv -f utf-8 -t latin1 temp2 > %s && rm temp && rm temp2" % (filepath, definename, definename, filepath), "close engine test flag %s" % definename, True)
                else:
                    if navi_build_config["test_mode"][key]['open']:
                        execCommand("cat %s | sed 's/^\/\/#define %s$/#define %s/' > temp && mv temp %s" % (filepath, definename, definename, filepath), "open client test flag %s" % definename, True)
                    else:
                        execCommand("cat %s | sed 's/^#define %s$/\/\/#define %s/' > temp && mv temp %s" % (filepath, definename, definename, filepath), "close client test flag %s" % definename, True)
#main
if __name__ == "__main__":

    setParamConfig()
    
    if not navi_build_config["options"]["test_flag"]['open']:
        getEngineBuildOutput()
        setTestMode()
        compileNaviSDK()
    else:
        setTestMode()
