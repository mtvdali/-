#!/usr/bin/env python3
"""
自动化脚本 - 用于监控、测试、部署和生成报告
"""

import os
import sys
import time
import argparse
import subprocess
import json
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(__file__).parent

# 子目录路径
WEB_APP_DIR = PROJECT_ROOT
MAC_APP_DIR = PROJECT_ROOT / "NewMacImageSearchApp"
PYTHON_SCRIPTS = ["offline.py", "server.py", "feature_extractor.py"]

class Automation:
    def __init__(self):
        pass
    
    def monitor(self):
        """监控文件变化"""
        print("🔍 开始监控文件变化...")
        
        # 要监控的文件类型
        extensions = ['.py', '.swift', '.html', '.css', '.js']
        
        # 初始文件状态
        file_states = {}
        
        # 收集所有要监控的文件
        for root, _, files in os.walk(PROJECT_ROOT):
            for file in files:
                if any(file.endswith(ext) for ext in extensions):
                    file_path = os.path.join(root, file)
                    file_states[file_path] = os.path.getmtime(file_path)
        
        print(f"✅ 已监控 {len(file_states)} 个文件")
        
        try:
            while True:
                time.sleep(2)
                changed = False
                
                # 检查文件变化
                for file_path in list(file_states.keys()):
                    if os.path.exists(file_path):
                        current_mtime = os.path.getmtime(file_path)
                        if current_mtime != file_states[file_path]:
                            print(f"🔄 文件已修改: {file_path}")
                            file_states[file_path] = current_mtime
                            changed = True
                    else:
                        print(f"❌ 文件已删除: {file_path}")
                        file_states.pop(file_path)
                        changed = True
                
                # 检查新文件
                for root, _, files in os.walk(PROJECT_ROOT):
                    for file in files:
                        if any(file.endswith(ext) for ext in extensions):
                            file_path = os.path.join(root, file)
                            if file_path not in file_states:
                                print(f"✅ 发现新文件: {file_path}")
                                file_states[file_path] = os.path.getmtime(file_path)
                                changed = True
                
                if changed:
                    print(f"📊 当前监控文件数: {len(file_states)}")
                    
        except KeyboardInterrupt:
            print("\n🛑 监控已停止")
    
    def test(self):
        """运行测试"""
        print("🧪 开始运行测试...")
        
        # 测试 Python 脚本语法
        print("\n1. 测试 Python 脚本语法...")
        for script in PYTHON_SCRIPTS:
            script_path = PROJECT_ROOT / script
            if script_path.exists():
                process = subprocess.Popen(["python3", "-m", "py_compile", str(script_path)], 
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                stdout, stderr = process.communicate()
                result = type('obj', (object,), {'returncode': process.returncode, 'stderr': stderr})()
                if result.returncode == 0:
                    print(f"✅ {script}: 语法正确")
                else:
                    print(f"❌ {script}: 语法错误")
                    print(result.stderr)
            else:
                print(f"⚠️ {script}: 文件不存在")
        
        # 测试 Web 服务器启动
        print("\n2. 测试 Web 服务器...")
        server_process = None
        try:
            server_process = subprocess.Popen(["python3", "server.py"], 
                                           cwd=str(WEB_APP_DIR),
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            time.sleep(3)  # 等待服务器启动
            
            # 检查服务器是否运行
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(("localhost", 5001))
            if result == 0:
                print("✅ Web 服务器启动成功")
                sock.close()
            else:
                print("❌ Web 服务器启动失败")
                if server_process:
                    print(server_process.stderr.read())
        except Exception as e:
            print(f"❌ 测试 Web 服务器时出错: {e}")
        finally:
            if server_process:
                server_process.terminate()
                server_process.wait()
        
        # 测试 Mac 应用代码结构
        print("\n3. 测试 Mac 应用代码结构...")
        mac_app_files = [
            "Package.swift",
            "Sources/NewMacImageSearchApp/NewMacImageSearchApp.swift",
            "search_engine.py"
        ]
        
        for file in mac_app_files:
            file_path = MAC_APP_DIR / file
            if file_path.exists():
                print(f"✅ {file}: 文件存在")
            else:
                print(f"❌ {file}: 文件不存在")
        
        print("\n🎉 测试完成！")
    
    def deploy(self):
        """部署应用"""
        print("🚀 开始部署应用...")
        
        # 1. 确保依赖已安装
        print("\n1. 检查依赖...")
        if not (PROJECT_ROOT / "requirements.txt").exists():
            print("❌ requirements.txt 文件不存在")
            return
        
        # 2. 构建 Mac 应用
        print("\n2. 构建 Mac 应用...")
        if MAC_APP_DIR.exists():
            print("⚠️ Mac 应用目录已存在")
        else:
            print("❌ Mac 应用目录不存在")
        
        # 3. 准备 Web 应用
        print("\n3. 准备 Web 应用...")
        if (WEB_APP_DIR / "server.py").exists():
            print("✅ Web 应用文件存在")
        else:
            print("❌ Web 应用文件不存在")
        
        # 4. 检查静态目录
        print("\n4. 检查静态目录...")
        static_dirs = ["static/img", "static/feature", "static/uploaded"]
        for dir_path in static_dirs:
            full_path = WEB_APP_DIR / dir_path
            if full_path.exists() and full_path.is_dir():
                print(f"✅ {dir_path}: 目录存在")
            else:
                print(f"⚠️ {dir_path}: 目录不存在，将创建")
                full_path.mkdir(parents=True, exist_ok=True)
        
        print("\n🎉 部署完成！")
        print("\n📋 部署说明:")
        print("1. 运行 Web 应用: python server.py")
        print("2. 访问: http://localhost:5001")
        print("3. 运行 Mac 应用: 在 Xcode 中打开 NewMacImageSearchApp 项目")
    
    def report(self):
        """生成报告"""
        print("📊 开始生成报告...")
        
        report = {
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "project": "Simple Image Search Engine",
            "components": {
                "web_app": {
                    "status": "unknown",
                    "files": []
                },
                "mac_app": {
                    "status": "unknown",
                    "files": []
                },
                "python_scripts": {
                    "status": "unknown",
                    "files": []
                }
            },
            "statistics": {
                "total_files": 0,
                "python_files": 0,
                "swift_files": 0,
                "other_files": 0
            }
        }
        
        # 统计文件
        total_files = 0
        python_files = 0
        swift_files = 0
        other_files = 0
        
        # 检查 Web 应用文件
        web_files = []
        for file in ["server.py", "offline.py", "feature_extractor.py", "search_engine.py"]:
            file_path = WEB_APP_DIR / file
            if file_path.exists():
                web_files.append(file)
                python_files += 1
                total_files += 1
        report["components"]["web_app"]["files"] = web_files
        if web_files:
            report["components"]["web_app"]["status"] = "ok"
        else:
            report["components"]["web_app"]["status"] = "error"
        
        # 检查 Mac 应用文件
        mac_files = []
        if MAC_APP_DIR.exists():
            for file in ["Package.swift", "Sources/NewMacImageSearchApp/NewMacImageSearchApp.swift", "search_engine.py"]:
                file_path = MAC_APP_DIR / file
                if file_path.exists():
                    mac_files.append(file)
                    if file.endswith(".swift"):
                        swift_files += 1
                    else:
                        python_files += 1
                    total_files += 1
        report["components"]["mac_app"]["files"] = mac_files
        if mac_files:
            report["components"]["mac_app"]["status"] = "ok"
        else:
            report["components"]["mac_app"]["status"] = "error"
        
        # 检查 Python 脚本
        python_scripts = []
        for file in PYTHON_SCRIPTS:
            file_path = WEB_APP_DIR / file
            if file_path.exists():
                python_scripts.append(file)
        report["components"]["python_scripts"]["files"] = python_scripts
        if python_scripts:
            report["components"]["python_scripts"]["status"] = "ok"
        else:
            report["components"]["python_scripts"]["status"] = "error"
        
        # 计算其他文件
        other_files = total_files - python_files - swift_files
        
        # 更新统计信息
        report["statistics"]["total_files"] = total_files
        report["statistics"]["python_files"] = python_files
        report["statistics"]["swift_files"] = swift_files
        report["statistics"]["other_files"] = other_files
        
        # 保存报告
        report_path = PROJECT_ROOT / "automation_report.json"
        with open(report_path, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        
        print(f"✅ 报告已保存到: {report_path}")
        
        # 显示报告摘要
        print("\n📋 报告摘要:")
        print(f"项目: {report['project']}")
        print(f"生成时间: {report['timestamp']}")
        print(f"总文件数: {report['statistics']['total_files']}")
        print(f"Python 文件: {report['statistics']['python_files']}")
        print(f"Swift 文件: {report['statistics']['swift_files']}")
        print(f"其他文件: {report['statistics']['other_files']}")
        
        print("\n组件状态:")
        for component, info in report['components'].items():
            status = "✅" if info['status'] == "ok" else "❌"
            print(f"{status} {component}: {info['status']}")
            if info['files']:
                print(f"   文件: {', '.join(info['files'])}")
        
        print("\n🎉 报告生成完成！")
    
    def all(self):
        """执行完整流程"""
        print("🏃‍♂️ 执行完整自动化流程...")
        
        # 1. 运行测试
        print("\n=== 1. 运行测试 ===")
        self.test()
        
        # 2. 部署应用
        print("\n=== 2. 部署应用 ===")
        self.deploy()
        
        # 3. 生成报告
        print("\n=== 3. 生成报告 ===")
        self.report()
        
        print("\n🎉 完整流程执行完成！")

def main():
    parser = argparse.ArgumentParser(description="自动化脚本")
    parser.add_argument("command", choices=["monitor", "test", "deploy", "report", "all"], 
                      help="要执行的命令")
    
    args = parser.parse_args()
    
    automation = Automation()
    
    if args.command == "monitor":
        automation.monitor()
    elif args.command == "test":
        automation.test()
    elif args.command == "deploy":
        automation.deploy()
    elif args.command == "report":
        automation.report()
    elif args.command == "all":
        automation.all()

if __name__ == "__main__":
    main()
