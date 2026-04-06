#!/bin/bash

# 完整的自动化构建和运行脚本
# 支持多种构建模式和自动化功能

set -e  # 出错时退出

# 配置变量
PROJECT_NAME="NewMacImageSearchApp"
PROJECT_DIR="/Users/ootd/sis/NewMacImageSearchApp"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="$PROJECT_NAME.app"
APP_PATH="$BUILD_DIR/release/$APP_NAME"
EXECUTABLE_NAME="NewMacImageSearchApp"
PYTHON_SCRIPT="search_engine.py"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo "使用方法:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  build      编译项目 (默认)"
    echo "  run       编译并运行应用"
    echo "  clean     清理构建文件"
    echo "  package   创建可分发的 .app 包"
    echo "  install   安装应用到 Applications 文件夹"
    echo "  automate  设置自动化构建和运行"
    echo "  help      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 run        # 编译并运行应用"
    echo "  $0 install    # 安装应用到 Applications"
}

# 清理构建文件
clean_build() {
    log_info "清理构建文件..."
    rm -rf "$BUILD_DIR" "$PROJECT_DIR/DerivedData" 2>/dev/null || true
    log_success "清理完成"
}

# 构建项目
build_project() {
    log_info "开始构建项目: $PROJECT_NAME"
    
    cd "$PROJECT_DIR"
    
    # 检查 Package.swift
    if [ ! -f "Package.swift" ]; then
        log_error "未找到 Package.swift 文件"
        exit 1
    fi
    
    # 创建必要的目录
    mkdir -p "$BUILD_DIR"
    
    # 构建项目
    log_info "运行 swift build..."
    
    # 尝试多种构建方法
    if swift build --configuration release 2>/dev/null; then
        log_success "Swift Package Manager 构建成功"
    else
        log_warning "Swift Package Manager 构建失败，尝试直接编译..."
        
        # 直接编译所有 Swift 文件
        SWIFT_FILES=$(find Sources -name "*.swift")
        
        /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc \
            -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
            -target arm64-apple-macosx11.0 \
            -module-name "$EXECUTABLE_NAME" \
            $SWIFT_FILES \
            -o "$BUILD_DIR/$EXECUTABLE_NAME"
        
        if [ $? -eq 0 ]; then
            log_success "直接编译成功"
        else
            log_error "所有构建方法都失败了"
            exit 1
        fi
    fi
    
    log_success "构建完成"
}

# 创建 .app 包
create_app_bundle() {
    log_info "创建应用程序包..."
    
    # 创建应用程序目录结构
    mkdir -p "$APP_PATH/Contents/MacOS"
    mkdir -p "$APP_PATH/Contents/Resources"
    
    # 复制可执行文件
    if [ -f "$BUILD_DIR/release/$EXECUTABLE_NAME" ]; then
        cp "$BUILD_DIR/release/$EXECUTABLE_NAME" "$APP_PATH/Contents/MacOS/"
    elif [ -f "$BUILD_DIR/$EXECUTABLE_NAME" ]; then
        cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_PATH/Contents/MacOS/"
    else
        log_error "未找到可执行文件"
        exit 1
    fi
    
    # 设置可执行权限
    chmod +x "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
    
    # 创建 Info.plist
    cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.$PROJECT_NAME</string>
    <key>CFBundleName</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
    
    # 复制 Python 脚本（如果存在）
    if [ -f "$PROJECT_DIR/$PYTHON_SCRIPT" ]; then
        cp "$PROJECT_DIR/$PYTHON_SCRIPT" "$APP_PATH/Contents/Resources/"
        log_info "已复制 Python 脚本到应用程序包"
    fi
    
    log_success "应用程序包创建完成: $APP_PATH"
}

# 运行应用
run_app() {
    log_info "启动应用程序..."
    
    if [ -d "$APP_PATH" ]; then
        open "$APP_PATH"
        log_success "应用程序已启动"
    else
        log_warning "未找到应用程序包，正在创建..."
        build_project
        create_app_bundle
        open "$APP_PATH"
        log_success "应用程序已创建并启动"
    fi
}

# 安装应用到 Applications 文件夹
install_app() {
    log_info "安装应用到 Applications 文件夹..."
    
    if [ ! -d "$APP_PATH" ]; then
        log_warning "应用程序包不存在，正在构建..."
        build_project
        create_app_bundle
    fi
    
    # 复制到 Applications
    DEST_PATH="/Applications/$APP_NAME"
    
    # 如果已存在，先删除
    if [ -d "$DEST_PATH" ]; then
        log_info "删除旧版本应用..."
        rm -rf "$DEST_PATH"
    fi
    
    # 复制应用
    cp -R "$APP_PATH" "/Applications/"
    
    # 设置权限
    sudo chmod -R 755 "/Applications/$APP_NAME" 2>/dev/null || true
    
    log_success "应用已安装到: /Applications/$APP_NAME"
    log_info "您可以在 Launchpad 或 Applications 文件夹中找到它"
}

# 设置自动化
setup_automation() {
    log_info "设置自动化构建和运行..."
    
    # 创建 launchd plist 文件（用于开机自启）
    LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
    PLIST_FILE="$LAUNCH_AGENT_DIR/com.$PROJECT_NAME.automate.plist"
    
    mkdir -p "$LAUNCH_AGENT_DIR"
    
    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.$PROJECT_NAME.automate</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_DIR/build.sh</string>
        <string>run</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>StandardOutPath</key>
    <string>/tmp/$PROJECT_NAME.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/$PROJECT_NAME.error.log</string>
</dict>
</plist>
EOF
    
    # 加载 launchd 任务
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"
    
    # 创建自动化脚本
    AUTOMATE_SCRIPT="$PROJECT_DIR/automate.sh"
    
    cat > "$AUTOMATE_SCRIPT" << 'EOF'
#!/bin/bash
# 自动化脚本 - 每日构建和运行

set -e

PROJECT_DIR="/Users/ootd/sis/NewMacImageSearchApp"
LOG_FILE="/tmp/NewMacImageSearchApp_automation.log"

echo "[$(date)] 开始自动化构建..." >> "$LOG_FILE"

cd "$PROJECT_DIR"

# 检查是否有代码更新
if git status --porcelain 2>/dev/null | grep -q "."; then
    echo "[$(date)] 检测到代码更新，开始构建..." >> "$LOG_FILE"
    ./build.sh run >> "$LOG_FILE" 2>&1
    echo "[$(date)] 自动化构建完成" >> "$LOG_FILE"
else
    echo "[$(date)] 代码无更新，跳过构建" >> "$LOG_FILE"
fi

# 发送通知
osascript -e 'display notification "NewMacImageSearchApp 自动化任务已完成" with title "自动化构建"'
EOF
    
    chmod +x "$AUTOMATE_SCRIPT"
    
    # 创建定时任务（每天上午10点运行）
    CRON_JOB="0 10 * * * $AUTOMATE_SCRIPT"
    (crontab -l 2>/dev/null | grep -v "$AUTOMATE_SCRIPT"; echo "$CRON_JOB") | crontab -
    
    log_success "自动化设置完成"
    log_info "1. 开机自启已设置"
    log_info "2. 每日定时构建已设置 (上午10点)"
    log_info "3. 自动化脚本位置: $AUTOMATE_SCRIPT"
    log_info "4. 日志文件: /tmp/NewMacImageSearchApp*.log"
}

# 主函数
main() {
    ACTION="${1:-build}"
    
    case "$ACTION" in
        "build")
            clean_build
            build_project
            ;;
        "run")
            clean_build
            build_project
            create_app_bundle
            run_app
            ;;
        "clean")
            clean_build
            ;;
        "package")
            build_project
            create_app_bundle
            ;;
        "install")
            build_project
            create_app_bundle
            install_app
            ;;
        "automate")
            setup_automation
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log_error "未知选项: $ACTION"
            show_usage
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
