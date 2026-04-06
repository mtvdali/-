import requests
import os

# 创建目录（如果不存在）
os.makedirs('static/img', exist_ok=True)

# 下载示例图像
for i in range(5):
    url = f'https://picsum.photos/200/30{i}'
    save_path = f'static/img/sample_{i+1}.jpg'
    
    try:
        response = requests.get(url)
        response.raise_for_status()  # 检查请求是否成功
        
        with open(save_path, 'wb') as f:
            f.write(response.content)
        
        print(f'Downloaded: {save_path}')
    except Exception as e:
        print(f'Error downloading {url}: {e}')

# 检查下载的文件
print('\nDownloaded files:')
for file in os.listdir('static/img'):
    if file.endswith('.jpg'):
        print(f'- {file}')
