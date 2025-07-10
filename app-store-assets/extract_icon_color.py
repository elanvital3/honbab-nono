#!/usr/bin/env python3
"""
아이콘에서 정확한 배경색 추출
"""

from PIL import Image
import collections

def extract_dominant_color():
    """아이콘에서 가장 많이 사용된 색상 추출"""
    
    icon_path = "/Users/elanvital3/Projects/2025_honbab-nono/flutter-app/assets/images/icon.png"
    
    try:
        # 아이콘 열기
        icon = Image.open(icon_path)
        
        # RGB 모드로 변환
        if icon.mode != 'RGB':
            icon = icon.convert('RGB')
        
        # 색상 데이터 가져오기
        colors = icon.getdata()
        
        # 색상별 빈도 계산
        color_counts = collections.Counter(colors)
        
        # 가장 많이 사용된 색상 5개
        most_common = color_counts.most_common(5)
        
        print("🎨 아이콘에서 가장 많이 사용된 색상들:")
        for i, (color, count) in enumerate(most_common):
            print(f"{i+1}. RGB{color} - {count}픽셀")
            
        # 가장 많이 사용된 색상 (배경색일 가능성 높음)
        dominant_color = most_common[0][0]
        print(f"\n✅ 추출된 배경색: RGB{dominant_color}")
        
        return dominant_color
        
    except Exception as e:
        print(f"❌ 에러: {e}")
        return (210, 180, 140)  # 기본값

if __name__ == "__main__":
    extract_dominant_color()