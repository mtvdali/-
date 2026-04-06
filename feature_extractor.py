import ssl
# 临时关闭 SSL 验证（仅测试用）
ssl._create_default_https_context = ssl._create_unverified_context

from PIL import Image
import torch
import torchvision.transforms as transforms
from torchvision.models import vgg16
import numpy as np

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

