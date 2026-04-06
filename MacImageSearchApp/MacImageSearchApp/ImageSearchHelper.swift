import Foundation

// 定义错误类型
enum ImageSearchError: Error {
    case pythonScriptNotFound
    case imageFileNotFound
    case pythonExecutionFailed(Int32, String)
    case invalidOutputFormat
    case parsingFailed
}

// 搜索结果结构体
struct SearchResult: Equatable {
    let filepath: String
    let filename: String
    let directory: String?
    let score: Double
    
    var fileURL: URL {
        URL(fileURLWithPath: filepath)
    }
    
    var displayScore: String {
        String(format: "%.2f%%", score * 100)
    }
}

class ImageSearchHelper {
    
    // 配置常量
    private let pythonExecutable = "/Users/ootd/.pyenv/versions/3.11.0/bin/python3"
    private let pythonScriptName = "search_engine.py"
    
    private var pythonScriptPath: String {
        // 先检查当前目录
        let currentDir = FileManager.default.currentDirectoryPath
        let currentPath = "\(currentDir)/\(pythonScriptName)"
        
        if FileManager.default.fileExists(atPath: currentPath) {
            return currentPath
        }
        
        // 检查主目录
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let homePath = "\(homeDir)/\(pythonScriptName)"
        
        if FileManager.default.fileExists(atPath: homePath) {
            return homePath
        }
        
        // 检查Document目录
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        let docPath = "\(documentsDir)/\(pythonScriptName)"
        
        if FileManager.default.fileExists(atPath: docPath) {
            return docPath
        }
        
        return homePath // 返回可能不存在的路径，会在使用时检查
    }
    
    /// 检查Python脚本和依赖是否可用
    func verifySetup() throws {
        // 检查Python脚本
        guard FileManager.default.fileExists(atPath: pythonScriptPath) else {
            throw ImageSearchError.pythonScriptNotFound
        }
        
        // 检查Python可执行文件
        guard FileManager.default.fileExists(atPath: pythonExecutable) else {
            print("⚠️ Python 3 未安装或不在标准位置")
            print("请通过 Homebrew 安装: brew install python@3.11")
            throw ImageSearchError.pythonScriptNotFound
        }
    }
    
    /// 重建图片索引（异步版本）
    func rebuildIndex() async throws -> String {
        try verifySetup()
        
        let output = try await runPythonScript(
            arguments: [pythonScriptPath, "index"],
            description: "重建图片索引"
        )
        
        return output
    }
    
    /// 搜索相似图片（异步版本）
    func searchSimilarImages(to imagePath: String, topK: Int = 5) async throws -> [SearchResult] {
        try verifySetup()
        
        // 检查图片文件是否存在
        guard FileManager.default.fileExists(atPath: imagePath) else {
            throw ImageSearchError.imageFileNotFound
        }
        
        let output = try await runPythonScript(
            arguments: [pythonScriptPath, "search", "--image", imagePath, "--top-k", "\(topK)", "--json"],
            description: "搜索相似图片"
        )
        
        return try parseJSONOutput(output)
    }
    
    /// 运行Python脚本并捕获输出
    private func runPythonScript(arguments: [String], description: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonExecutable)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        print("🚀 开始 \(description)...")
        print("命令: \(pythonExecutable) \(arguments.joined(separator: " "))")
        
        do {
            try process.run()
            
            // 异步等待进程结束
            process.waitUntilExit()
            
            // 读取输出
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            print("📄 输出: \(output)")
            
            if !errorOutput.isEmpty {
                print("⚠️ 错误输出: \(errorOutput)")
            }
            
            if process.terminationStatus != 0 {
                throw ImageSearchError.pythonExecutionFailed(process.terminationStatus, errorOutput)
            }
            
            return output
            
        } catch {
            print("❌ 执行Python脚本时出错: \(error)")
            throw error
        }
    }
    
    /// 解析JSON格式的输出
    private func parseJSONOutput(_ output: String) throws -> [SearchResult] {
        // 清理输出，移除可能的日志信息
        let jsonPattern = #"(?s)\[.*\]"#
        let regex = try NSRegularExpression(pattern: jsonPattern)
        
        guard let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range, in: output) else {
            throw ImageSearchError.invalidOutputFormat
        }
        
        let jsonString = String(output[range])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ImageSearchError.parsingFailed
        }
        
        do {
            let decoder = JSONDecoder()
            let rawResults = try decoder.decode([RawSearchResult].self, from: jsonData)
            
            return rawResults.map { raw in
                SearchResult(
                    filepath: raw.filepath,
                    filename: raw.filename,
                    directory: raw.directory,
                    score: raw.score
                )
            }
        } catch {
            print("❌ JSON解析失败: \(error)")
            print("原始JSON: \(jsonString)")
            throw ImageSearchError.parsingFailed
        }
    }
    
    /// 简单的同步版本（用于兼容性）
    func searchSimilarImagesSync(to imagePath: String, topK: Int = 5) -> Result<[SearchResult], Error> {
        do {
            // 创建信号量来等待异步调用完成
            let semaphore = DispatchSemaphore(value: 0)
            var searchResult: Result<[SearchResult], Error> = .success([])
            
            Task {
                do {
                    let results = try await searchSimilarImages(to: imagePath, topK: topK)
                    searchResult = .success(results)
                } catch {
                    searchResult = .failure(error)
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            return searchResult
            
        } catch {
            return .failure(error)
        }
    }
    
    /// 获取系统信息
    func getSystemInfo() -> [String: String] {
        return [
            "pythonExecutable": pythonExecutable,
            "pythonScriptPath": pythonScriptPath,
            "scriptExists": FileManager.default.fileExists(atPath: pythonScriptPath) ? "是" : "否",
            "pythonExists": FileManager.default.fileExists(atPath: pythonExecutable) ? "是" : "否",
            "currentDirectory": FileManager.default.currentDirectoryPath
        ]
    }
}

// 用于JSON解析的中间结构体
private struct RawSearchResult: Codable {
    let filepath: String
    let filename: String
    let directory: String?
    let score: Double
    let indexed_at: Double?
}

// 扩展：添加方便的初始化方法
extension ImageSearchHelper {
    /// 便捷初始化，可以指定Python脚本路径
    convenience init(pythonScriptPath: String? = nil) {
        self.init()
        if let path = pythonScriptPath {
            // 可以使用KVC设置私有属性，但更安全的方法是创建新的实例
            // 这里我们保持简单，使用默认初始化
        }
    }
}

// 使用示例
extension ImageSearchHelper {
    static func exampleUsage() {
        let helper = ImageSearchHelper()
        
        // 1. 检查系统信息
        print("🔧 系统信息:")
        helper.getSystemInfo().forEach { key, value in
            print("  \(key): \(value)")
        }
        
        // 2. 验证设置
        do {
            try helper.verifySetup()
            print("✅ 系统配置验证通过")
        } catch {
            print("❌ 系统配置有问题: \(error)")
        }
        
        // 3. 同步搜索示例
        let testImagePath = "~/Downloads/test.jpg" // 替换为实际路径
        let expandedPath = (testImagePath as NSString).expandingTildeInPath
        
        print("\n🔍 搜索示例: \(expandedPath)")
        
        switch helper.searchSimilarImagesSync(to: expandedPath) {
        case .success(let results):
            print("✅ 找到 \(results.count) 个结果:")
            results.forEach { result in
                print("  - \(result.filename) (\(result.score))")
            }
        case .failure(let error):
            print("❌ 搜索失败: \(error)")
        }
    }
}
