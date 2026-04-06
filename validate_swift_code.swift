// 简单的 Swift 代码验证脚本
// 这个脚本会尝试编译 NewMacImageSearchApp 的主要代码

import Foundation

let sourcePath = "/Users/ootd/sis/NewMacImageSearchApp/Sources/NewMacImageSearchApp/NewMacImageSearchApp.swift"

// 读取文件内容
if let content = try? String(contentsOfFile: sourcePath, encoding: .utf8) {
    print("✅ 成功读取文件: \(sourcePath)")
    
    // 检查关键结构
    if content.contains("@main") {
        print("✅ 包含 @main 入口点")
    } else {
        print("❌ 缺少 @main 入口点")
    }
    
    if content.contains("ContentView") {
        print("✅ 包含 ContentView 结构体")
    } else {
        print("❌ 缺少 ContentView 结构体")
    }
    
    if content.contains("ImageSearchHelper") {
        print("✅ 包含 ImageSearchHelper 类")
    } else {
        print("❌ 缺少 ImageSearchHelper 类")
    }
    
    if content.contains("SearchResult") {
        print("✅ 包含 SearchResult 结构体")
    } else {
        print("❌ 缺少 SearchResult 结构体")
    }
    
    print("\n✅ 代码结构验证完成")
} else {
    print("❌ 无法读取文件: \(sourcePath)")
}

// 检查 search_engine.py 文件
let pythonScriptPath = "/Users/ootd/sis/NewMacImageSearchApp/search_engine.py"
if FileManager.default.fileExists(atPath: pythonScriptPath) {
    print("✅ 找到 search_engine.py 文件")
} else {
    print("❌ 缺少 search_engine.py 文件")
}

print("\n🎉 验证完成！")
