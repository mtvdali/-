import SwiftUI

struct ContentView: View {
    @StateObject private var searchHelper = ImageSearchHelper()
    @State private var searchResults: [SearchResult] = []
    @State private var selectedImageURL: URL?
    @State private var showingImagePicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("图片搜索引擎")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // 系统信息
            if !searchHelper.isRunning {
                InfoView(searchHelper: searchHelper)
            }
            
            // 进度指示器
            if searchHelper.isRunning {
                ProgressView(
                    value: searchHelper.progress,
                    label: { Text(searchHelper.currentOperation) }
                )
                .padding()
            }
            
            // 操作按钮
            HStack(spacing: 20) {
                Button("验证环境") {
                    Task {
                        await verifySetup()
                    }
                }
                .disabled(searchHelper.isRunning)
                
                Button("重建索引") {
                    Task {
                        await rebuildIndex()
                    }
                }
                .disabled(searchHelper.isRunning)
                
                Button("选择图片搜索") {
                    showingImagePicker = true
                }
                .disabled(searchHelper.isRunning)
                
                if searchHelper.isRunning {
                    Button("取消") {
                        searchHelper.cancel()
                    }
                }
            }
            .padding()
            
            // 搜索结果
            if !searchResults.isEmpty {
                SearchResultsView(results: $searchResults)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImageSelection(result)
        }
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            Task {
                await verifySetup()
            }
        }
    }
    
    private func verifySetup() async {
        do {
            try await searchHelper.verifySetup()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func rebuildIndex() async {
        do {
            let output = try await searchHelper.rebuildIndex()
            print("索引完成: \(output)")
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func handleImageSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    do {
                        searchResults = try await searchHelper.searchSimilarImages(to: url.path)
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct InfoView: View {
    @ObservedObject var searchHelper: ImageSearchHelper
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("系统信息")
                .font(.headline)
            
            ForEach(Array(searchHelper.getSystemInfo().sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                HStack {
                    Text("\(key):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SearchResultsView: View {
    @Binding var results: [SearchResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("搜索结果 (\(results.count) 个)")
                .font(.headline)
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150))
                ], spacing: 20) {
                    ForEach(results) { result in
                        SearchResultCard(result: result)
                    }
                }
                .padding()
            }
        }
        .padding()
    }
}

struct SearchResultCard: View {
    let result: SearchResult
    
    var body: some View {
        VStack {
            if let nsImage = NSImage(contentsOf: result.fileURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading) {
                Text(result.filename)
                    .font(.caption)
                    .lineLimit(1)
                
                Text("相似度: \(result.displayScore)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, alignment: .leading)
        }
        .contextMenu {
            Button("在Finder中显示") {
                NSWorkspace.shared.selectFile(result.filepath, inFileViewerRootedAtPath: "")
            }
            Button("复制路径") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.filepath, forType: .string)
            }
        }
    }
}
