#!/usr/bin/env python3
"""
本地图片搜索引擎 - 支持JSON输出
"""

import os
import sys
import json
import argparse
from pathlib import Path
from qdrant_client import QdrantClient
from qdrant_client.http import models
from fastembed import ImageEmbedding
import hashlib

# 配置
MODEL_NAME = "snowflake/snowflake-arctic-embed-m-v1.5"
DB_PATH = "./qdrant_local_storage"
COLLECTION_NAME = "shopping_inventory"

def setup():
    """初始化模型和客户端"""
    print(f"🚀 加载模型: {MODEL_NAME}...", file=sys.stderr)
    try:
        model = ImageEmbedding(model_name=MODEL_NAME)
        client = QdrantClient(path=DB_PATH)
        return model, client
    except Exception as e:
        print(f"❌ 初始化失败: {e}", file=sys.stderr)
        sys.exit(1)

def get_image_folders():
    """返回要索引的目录列表"""
    folders = [
        str(Path.home() / "ShoppingDataOrganizer"),
        str(Path.home() / "sis"),
        str(Path.home() / "Pictures" / "OOTD"),
        str(Path.home() / "Pictures")
    ]
    
    # 过滤掉不存在的目录
    existing_folders = [f for f in folders if os.path.exists(f)]
    return existing_folders

def generate_id(filepath):
    """为文件路径生成唯一ID"""
    return int(hashlib.md5(filepath.encode()).hexdigest()[:8], 16)

def index_images(model, client):
    """索引所有图片"""
    print("🔍 扫描图片目录...", file=sys.stderr)
    
    image_paths = []
    for folder in get_image_folders():
        if not os.path.exists(folder):
            continue
            
        for root, _, files in os.walk(folder):
            for f in files:
                if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                    full_path = os.path.join(root, f)
                    image_paths.append(full_path)
    
    if not image_paths:
        print("❌ 没有找到图片", file=sys.stderr)
        return
    
    print(f"📸 找到 {len(image_paths)} 张图片", file=sys.stderr)
    
    # 创建集合
    try:
        client.delete_collection(collection_name=COLLECTION_NAME)
    except:
        pass
    
    # 使用第一张图片获取向量维度
    test_vector = list(model.embed([image_paths[0]]))[0]
    vector_size = len(test_vector)
    
    client.create_collection(
        collection_name=COLLECTION_NAME,
        vectors_config=models.VectorParams(
            size=vector_size,
            distance=models.Distance.COSINE
        )
    )
    
    # 分批处理
    batch_size = 20
    indexed = 0
    
    for i in range(0, len(image_paths), batch_size):
        batch = image_paths[i:i+batch_size]
        
        try:
            embeddings = list(model.embed(batch))
            points = []
            
            for j, (img_path, embedding) in enumerate(zip(batch, embeddings)):
                filename = os.path.basename(img_path)
                dir_name = os.path.basename(os.path.dirname(img_path))
                
                points.append(models.PointStruct(
                    id=generate_id(img_path),
                    vector=embedding.tolist(),
                    payload={
                        "filepath": img_path,
                        "filename": filename,
                        "directory": dir_name,
                        "indexed_at": os.path.getmtime(img_path)
                    }
                ))
            
            client.upsert(
                collection_name=COLLECTION_NAME,
                points=points
            )
            
            indexed += len(batch)
            print(f"✅ 已索引: {indexed}/{len(image_paths)}", file=sys.stderr)
            
        except Exception as e:
            print(f"⚠️ 处理批次失败: {e}", file=sys.stderr)
            continue
    
    print(f"🎉 索引完成！总共 {indexed} 张图片", file=sys.stderr)

def search_image(model, client, query_image_path, top_k=5):
    """搜索相似图片"""
    if not os.path.exists(query_image_path):
        return []
    
    try:
        query_vector = list(model.embed([query_image_path]))[0]
        
        results = client.search(
            collection_name=COLLECTION_NAME,
            query_vector=query_vector.tolist(),
            limit=top_k,
            with_payload=True
        )
        
        return results
    except Exception as e:
        print(f"❌ 搜索失败: {e}", file=sys.stderr)
        return []

def main():
    parser = argparse.ArgumentParser(description="本地图片搜索引擎")
    parser.add_argument("action", choices=["index", "search"], help="执行的动作")
    parser.add_argument("--image", help="要搜索的图片路径")
    parser.add_argument("--top-k", type=int, default=5, help="返回的结果数量")
    parser.add_argument("--json", action="store_true", help="输出JSON格式")
    
    args = parser.parse_args()
    
    model, client = setup()
    
    if args.action == "index":
        index_images(model, client)
        
    elif args.action == "search":
        if not args.image:
            print("❌ 请提供图片路径: --image /path/to/image.jpg", file=sys.stderr)
            sys.exit(1)
        
        results = search_image(model, client, args.image, args.top_k)
        
        if args.json:
            # JSON输出
            output = []
            for hit in results:
                payload = hit.payload
                output.append({
                    "filepath": payload.get('filepath', ''),
                    "filename": payload.get('filename', ''),
                    "directory": payload.get('directory', ''),
                    "score": float(hit.score),
                    "indexed_at": payload.get('indexed_at')
                })
            print(json.dumps(output, ensure_ascii=False))
        else:
            # 人类可读输出
            print(f"\n🔍 搜索结果:", file=sys.stderr)
            print("-" * 80, file=sys.stderr)
            
            for i, hit in enumerate(results):
                payload = hit.payload
                print(f"{i+1}. [{hit.score:.4f}] {payload.get('filename')}", file=sys.stderr)
                print(f"   路径: {payload.get('filepath')}", file=sys.stderr)

if __name__ == "__main__":
    main()
