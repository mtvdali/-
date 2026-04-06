#!/usr/bin/env python3
"""
图片搜索引擎 - macOS版本
"""

import os
import sys
import json
import argparse
from pathlib import Path
import hashlib
from PIL import Image
import numpy as np

# 临时关闭 SSL 验证（仅测试用）
import ssl
ssl._create_default_https_context = ssl._create_unverified_context

# 导入 PyTorch 相关库
import torch
import torchvision.transforms as transforms
from torchvision.models import vgg16

# 配置
DB_PATH = str(Path.home() / "Library" / "Application Support" / "com.image.search" / "image_search.json")

class FeatureExtractor:
    def __init__(self):
        # 使用 PyTorch 预训练的 VGG16 模型
        self.model = vgg16(pretrained=True)
        # 移除最后的分类层，只使用特征提取部分
        self.model = torch.nn.Sequential(*list(self.model.children())[:-1])
        # 设置为评估模式
        self.model.eval()
        
        # 图像预处理
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
        ])

    def extract(self, img):
        """
        Extract a deep feature from an input image
        Args:
            img: from PIL.Image.open(path)

        Returns:
            feature (np.ndarray): deep feature
        """
        # 预处理图像
        img = img.resize((224, 224))
        img = img.convert('RGB')
        img_tensor = self.transform(img).unsqueeze(0)  # 添加批次维度
        
        # 使用模型提取特征
        with torch.no_grad():
            feature = self.model(img_tensor)
        
        # 展平特征并归一化
        feature = feature.squeeze().numpy()
        return feature / np.linalg.norm(feature)

# 全局特征提取器实例
fe = None

def get_feature_extractor():
    """获取特征提取器实例"""
    global fe
    if fe is None:
        print("🔧 初始化特征提取器...", file=sys.stderr)
        fe = FeatureExtractor()
        print("✅ 特征提取器初始化完成", file=sys.stderr)
    return fe

def get_image_folders():
    """获取要索引的目录列表"""
    folders = [
        str(Path.home() / "Pictures"),
        str(Path.home() / "Downloads"),
        str(Path.home() / "Desktop")
    ]
    
    # 只返回存在的目录
    return [f for f in folders if os.path.exists(f)]

def calculate_image_feature(image_path):
    """计算图片的特征向量"""
    try:
        with Image.open(image_path) as img:
            extractor = get_feature_extractor()
            feature = extractor.extract(img)
            return feature.tolist()  # 转换为列表以便JSON存储
            
    except Exception as e:
        print(f"⚠️ 无法处理图片 {image_path}: {e}", file=sys.stderr)
        return None

def load_database():
    """加载数据库"""
    if os.path.exists(DB_PATH):
        with open(DB_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {"images": [], "indexed_at": 0}

def save_database(data):
    """保存数据库"""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with open(DB_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def index_images():
    """索引所有图片"""
    print("🔍 开始扫描图片目录...", file=sys.stderr)
    
    # 初始化特征提取器
    get_feature_extractor()
    
    database = load_database()
    indexed_images = {img['filepath']: img for img in database.get('images', [])}
    
    image_count = 0
    new_images = 0
    
    for folder in get_image_folders():
        print(f"📁 扫描目录: {folder}", file=sys.stderr)
        
        for root, _, files in os.walk(folder):
            for filename in files:
                if filename.lower().endswith(('.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp')):
                    filepath = os.path.join(root, filename)
                    
                    # 检查文件是否已索引
                    if filepath in indexed_images:
                        continue
                    
                    # 计算特征
                    feature = calculate_image_feature(filepath)
                    if feature is None:
                        continue
                    
                    # 添加到数据库
                    indexed_images[filepath] = {
                        "filepath": filepath,
                        "filename": filename,
                        "directory": os.path.basename(root),
                        "feature": feature,
                        "size": os.path.getsize(filepath),
                        "modified": os.path.getmtime(filepath)
                    }
                    
                    new_images += 1
                    image_count += 1
                    
                    if image_count % 100 == 0:
                        print(f"✅ 已处理 {image_count} 张图片", file=sys.stderr)
    
    # 更新数据库
    database['images'] = list(indexed_images.values())
    database['indexed_at'] = int(os.path.time())
    
    save_database(database)
    
    print(f"🎉 索引完成！总共 {len(database['images'])} 张图片，新增 {new_images} 张", file=sys.stderr)

def calculate_similarity(feature1, feature2):
    """计算两个特征向量之间的相似度"""
    feature1 = np.array(feature1)
    feature2 = np.array(feature2)
    return np.dot(feature1, feature2)  # 余弦相似度

def search_image(query_image_path, top_k=5):
    """搜索相似图片"""
    if not os.path.exists(query_image_path):
        return []
    
    # 计算查询图片的特征
    query_feature = calculate_image_feature(query_image_path)
    if query_feature is None:
        return []
    
    database = load_database()
    results = []
    
    for img in database.get('images', []):
        img_feature = img.get('feature', [])
        if not img_feature:
            continue
        
        # 计算相似度
        score = calculate_similarity(query_feature, img_feature)
        
        results.append({
            "filepath": img['filepath'],
            "filename": img['filename'],
            "directory": img['directory'],
            "score": round(score, 4),
            "size": img.get('size', 0),
            "modified": img.get('modified', 0)
        })
    
    # 按相似度排序
    results.sort(key=lambda x: x['score'], reverse=True)
    
    return results[:top_k]

def main():
    parser = argparse.ArgumentParser(description="图片搜索引擎")
    parser.add_argument("action", choices=["index", "search"], help="执行的动作")
    parser.add_argument("--image", help="要搜索的图片路径")
    parser.add_argument("--top-k", type=int, default=5, help="返回的结果数量")
    parser.add_argument("--json", action="store_true", help="输出JSON格式")
    
    args = parser.parse_args()
    
    if args.action == "index":
        index_images()
        
    elif args.action == "search":
        if not args.image:
            print("❌ 请提供图片路径: --image /path/to/image.jpg", file=sys.stderr)
            sys.exit(1)
        
        results = search_image(args.image, args.top_k)
        
        if args.json:
            # JSON输出
            print(json.dumps(results, ensure_ascii=False))
        else:
            # 人类可读输出
            if results:
                print(f"\n🔍 找到 {len(results)} 个结果:", file=sys.stderr)
                print("-" * 80, file=sys.stderr)
                
                for i, result in enumerate(results):
                    print(f"{i+1}. [{result['score']:.2%}] {result['filename']}", file=sys.stderr)
                    print(f"   路径: {result['filepath']}", file=sys.stderr)
            else:
                print("❌ 未找到相似图片", file=sys.stderr)

if __name__ == "__main__":
    main()
