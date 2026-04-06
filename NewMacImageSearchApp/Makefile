# NewMacImageSearchApp Makefile
# 提供便捷的构建命令

PROJECT_NAME = NewMacImageSearchApp
BUILD_SCRIPT = ./build.sh

.PHONY: all build run clean package install automate help

all: build

build:
	@$(BUILD_SCRIPT) build

run:
	@$(BUILD_SCRIPT) run

clean:
	@$(BUILD_SCRIPT) clean

package:
	@$(BUILD_SCRIPT) package

install:
	@$(BUILD_SCRIPT) install

automate:
	@$(BUILD_SCRIPT) automate

help:
	@$(BUILD_SCRIPT) help

# 开发相关命令
dev: clean run

# 发布命令
release: clean package install

# 快速测试
test: build
	@echo "运行测试..."
	@if [ -f .build/release/NewMacImageSearchApp ]; then \
		./.build/release/NewMacImageSearchApp --test; \
	elif [ -f .build/NewMacImageSearchApp ]; then \
		./.build/NewMacImageSearchApp --test; \
	else \
		echo "未找到可执行文件"; \
	fi

# 监控文件变化并自动重建
watch:
	@echo "监控文件变化..."
	@fswatch -o Sources/**/*.swift Package.swift | xargs -n1 -I{} make build
