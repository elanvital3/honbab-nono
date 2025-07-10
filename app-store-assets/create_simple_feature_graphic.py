#!/usr/bin/env python3
"""
혼밥노노 심플한 Feature Graphic - 아이콘 중앙 배치
"""

from PIL import Image
import os

def create_simple_feature_graphic():
    """아이콘을 중앙에 놓고 배경색만 채운 심플한 Feature Graphic"""
    
    # 캔버스 생성 (1024 x 500)
    width, height = 1024, 500
    
    # 아이콘에서 추출한 정확한 배경색
    icon_background_color = (196, 154, 96)  # 실제 아이콘 배경색
    
    # 배경 생성
    img = Image.new('RGB', (width, height), icon_background_color)
    
    # 아이콘 이미지 불러오기
    icon_path = "/Users/elanvital3/Projects/2025_honbab-nono/flutter-app/assets/images/icon.png"
    
    try:
        # 아이콘 열기
        icon = Image.open(icon_path)
        
        # 아이콘 크기 조정 (더 크게 만들기)
        # 세로는 여전히 500px이지만, 가로도 더 크게 확대
        icon_height = height  # 500px 전체 높이
        aspect_ratio = icon.width / icon.height
        base_icon_width = int(icon_height * aspect_ratio)
        
        # 아이콘을 1.3배 더 크게 확대
        scale_factor = 1.3
        icon_width = int(base_icon_width * scale_factor)
        icon_height = int(icon_height * scale_factor)
        
        # 아이콘 리사이즈 (확대)
        icon_resized = icon.resize((icon_width, icon_height), Image.Resampling.LANCZOS)
        
        # 아이콘을 중앙에 배치
        icon_x = (width - icon_width) // 2
        icon_y = (height - icon_height) // 2
        
        # 아이콘 붙이기 (알파 채널 처리)
        if icon_resized.mode == 'RGBA':
            img.paste(icon_resized, (icon_x, icon_y), icon_resized)
        else:
            img.paste(icon_resized, (icon_x, icon_y))
        
        # 출력 경로
        output_path = "/Users/elanvital3/Projects/2025_honbab-nono/app-store-assets/feature_graphic_simple.png"
        
        # 이미지 저장
        img.save(output_path, 'PNG', quality=95)
        print(f"✅ 심플한 Feature Graphic 생성 완료: {output_path}")
        print(f"   크기: {width} x {height}")
        print(f"   아이콘 크기: {icon_width} x {icon_height}")
        
    except Exception as e:
        print(f"❌ 에러 발생: {e}")

if __name__ == "__main__":
    create_simple_feature_graphic()