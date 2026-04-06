import Foundation

class ImageSearchHelper {
    
    let pythonScriptPath: String
    
    init() {
        // Python脚本在你的主目录
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        pythonScriptPath = "\(homeDirectory)/search_engine.py"
    }
    
    /// 重建图片索引
    func rebuildIndex() -> Bool {
        guard FileManager.default.fileExists(atPath: pythonScriptPath) else {
            print("Python脚本不存在: \(pythonScriptPath)")
            return false
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [pythonScriptPath, "index"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        do {
            print("开始重建图片索引...")
            try process.run()
            process.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("索引输出: \(output)")
            }
            
            return process.terminationStatus == 0
        } catch {
            print("执行Python脚本时出错: \(error)")
            return false
        }
    }
    
    /// 搜索相似图片
    func searchSimilarImages(to imagePath: String, topK: Int = 5) -> [(filepath: String, score: Double)] {
        guard FileManager.default.fileExists(atPath: pythonScriptPath),
              FileManager.default.fileExists(atPath: imagePath) else {
            print("脚本或图片文件不存在")
            return []
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [pythonScriptPath, "search", "--image", imagePath, "--top-k", "\(topK)"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }
            
            // 解析输出
            return parseSearchOutput(output)
        } catch {
            print("搜索时出错: \(error)")
            return []
        }
    }
    
    private func parseSearchOutput(_ output: String) -> [(filepath: String, score: Double)] {
        var results: [(String, Double)] = []
        
        let lines = output.split(separator: "\n")
        for line in lines {
            if line.contains("路径:") {
                let components = line.split(separator: ":")
                if components.count > 1 {
                    let filepath = String(components[1]).trimmingCharacters(in: .whitespaces)
                    
                    // 找到对应的分数行（上一行）
                    if let index = lines.firstIndex(of: line), index > 0 {
                        let scoreLine = lines[index - 1]
                        if let score = extractScore(from: String(scoreLine)) {
                            results.append((filepath, score))
                        }
                    }
                }
            }
        }
        
        return results
    }
    
    private func extractScore(from line: String) -> Double? {
        // 匹配类似 "[0.8564] 文件名" 的格式
        let pattern = #"\[(\d+\.\d+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        
        return Double(line[range])
    }
}
