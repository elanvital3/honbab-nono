#!/usr/bin/env python3
"""
Flutter 스플래시와 동일한 디자인의 네이티브 스플래시 이미지 생성
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_splash_image():
    # 이미지 크기 (모바일 화면 기준)
    width, height = 1080, 1920
    
    # 흰색 배경 생성
    image = Image.new('RGB', (width, height), '#FFFFFF')
    draw = ImageDraw.Draw(image)
    
    # 앱 아이콘 로드
    icon_path = 'ui-reference/icon.png'
    if os.path.exists(icon_path):
        app_icon = Image.open(icon_path)
        # 아이콘 크기 조정 (120px에 해당하는 크기)
        icon_size = 300  # 고해상도를 위해 큰 크기
        app_icon = app_icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
        
        # 아이콘을 중앙에 배치 (약간 위쪽)
        icon_x = (width - icon_size) // 2
        icon_y = height // 2 - 200
        image.paste(app_icon, (icon_x, icon_y), app_icon if app_icon.mode == 'RGBA' else None)
    
    # 폰트 설정 시도 (시스템 폰트 사용)
    try:
        # macOS의 시스템 폰트
        title_font = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 80)
        subtitle_font = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 40)
    except:
        try:
            # 기본 폰트 fallback
            title_font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 80)
            subtitle_font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 40)
        except:
            # 최후의 fallback
            title_font = ImageFont.load_default()
            subtitle_font = ImageFont.load_default()
    
    # "혼밥노노" 텍스트
    title_text = "혼밥노노"
    title_bbox = draw.textbbox((0, 0), title_text, font=title_font)
    title_width = title_bbox[2] - title_bbox[0]
    title_x = (width - title_width) // 2
    title_y = height // 2 + 150
    draw.text((title_x, title_y), title_text, fill='#333333', font=title_font)
    
    # "혼여는 좋지만 맛집은 함께 🥹" 텍스트
    subtitle_text = "혼여는 좋지만 맛집은 함께 🥹"
    subtitle_bbox = draw.textbbox((0, 0), subtitle_text, font=subtitle_font)
    subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
    subtitle_x = (width - subtitle_width) // 2
    subtitle_y = title_y + 100
    draw.text((subtitle_x, subtitle_y), subtitle_text, fill='#666666', font=subtitle_font)
    
    # 이미지 저장
    output_path = 'flutter-app/android/app/src/main/res/drawable/complete_splash.png'
    image.save(output_path, 'PNG', quality=95)
    print(f"✅ 완성된 스플래시 이미지 저장: {output_path}")
    print(f"   크기: {width}x{height}")
    
    return output_path

if __name__ == "__main__":
    create_splash_image()