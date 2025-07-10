#!/usr/bin/env python3
"""
혼밥노노 Google Play Store Feature Graphic (1024x500) 생성 스크립트
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_feature_graphic():
    """간단하고 깔끔한 Feature Graphic 생성"""
    
    # 캔버스 생성 (1024 x 500)
    width, height = 1024, 500
    
    # 혼밥노노 브랜드 컬러
    brand_beige = (210, 180, 140)  # #D2B48C
    brand_beige_light = (240, 220, 190)  # 연한 베이지
    text_dark = (80, 60, 40)  # 어두운 브라운
    white = (255, 255, 255)
    
    # 배경 생성 (베이지 그라데이션)
    img = Image.new('RGB', (width, height), brand_beige_light)
    draw = ImageDraw.Draw(img)
    
    # 심플한 패턴 추가 (원형 요소들)
    # 왼쪽 큰 원
    draw.ellipse([50, 100, 350, 400], fill=brand_beige, outline=None)
    
    # 오른쪽 작은 원들
    draw.ellipse([850, 50, 950, 150], fill=brand_beige, outline=None)
    draw.ellipse([900, 320, 980, 400], fill=brand_beige, outline=None)
    
    # 중앙 콘텐츠 영역
    # 앱 이름
    try:
        # 타이틀 폰트 (더 크게)
        title_font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 90, index=7)  # Bold
        subtitle_font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 36, index=5)  # SemiBold
        tagline_font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 28, index=5)  # SemiBold
    except:
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
        tagline_font = ImageFont.load_default()
    
    # 메인 타이틀 "혼밥노노"
    title = "혼밥노노"
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_width = title_bbox[2] - title_bbox[0]
    title_x = (width - title_width) // 2
    title_y = 140
    
    # 타이틀 그림자 효과
    for dx in [-2, -1, 0, 1, 2]:
        for dy in [-2, -1, 0, 1, 2]:
            if dx != 0 or dy != 0:
                draw.text((title_x + dx, title_y + dy), title, font=title_font, fill=(200, 170, 130))
    
    # 메인 타이틀
    draw.text((title_x, title_y), title, font=title_font, fill=text_dark)
    
    # 서브타이틀
    subtitle = "맛집 동행 매칭 서비스"
    subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
    subtitle_x = (width - subtitle_width) // 2
    subtitle_y = title_y + 100
    
    draw.text((subtitle_x, subtitle_y), subtitle, font=subtitle_font, fill=text_dark)
    
    # 태그라인
    tagline = "혼자는 좋지만 맛집은 함께"
    tagline_bbox = draw.textbbox((0, 0), tagline, font=tagline_font)
    tagline_width = tagline_bbox[2] - tagline_bbox[0]
    tagline_x = (width - tagline_width) // 2
    tagline_y = subtitle_y + 70
    
    draw.text((tagline_x, tagline_y), tagline, font=tagline_font, fill=(120, 90, 60))
    
    # 아이콘 요소 추가 (간단한 심볼)
    # 포크와 나이프 심볼
    icon_y = 370
    icon_spacing = 200
    center_x = width // 2
    
    # 왼쪽 포크 아이콘 (심플한 선)
    fork_x = center_x - icon_spacing
    draw.line([(fork_x, icon_y), (fork_x, icon_y + 60)], fill=text_dark, width=4)
    draw.line([(fork_x - 10, icon_y), (fork_x - 10, icon_y + 20)], fill=text_dark, width=3)
    draw.line([(fork_x + 10, icon_y), (fork_x + 10, icon_y + 20)], fill=text_dark, width=3)
    
    # 중앙 하트
    heart_x = center_x
    heart_y = icon_y + 10
    # 하트 그리기 (두 개의 원과 삼각형)
    draw.ellipse([heart_x - 15, heart_y - 10, heart_x + 5, heart_y + 10], fill=(255, 100, 100))
    draw.ellipse([heart_x - 5, heart_y - 10, heart_x + 15, heart_y + 10], fill=(255, 100, 100))
    draw.polygon([(heart_x - 18, heart_y + 5), (heart_x + 18, heart_y + 5), (heart_x, heart_y + 30)], fill=(255, 100, 100))
    
    # 오른쪽 나이프 아이콘
    knife_x = center_x + icon_spacing
    draw.line([(knife_x, icon_y), (knife_x, icon_y + 60)], fill=text_dark, width=4)
    draw.polygon([(knife_x - 10, icon_y), (knife_x + 10, icon_y), (knife_x, icon_y - 15)], fill=text_dark)
    
    # 출력 경로
    output_path = "/Users/elanvital3/Projects/2025_honbab-nono/app-store-assets/feature_graphic.png"
    
    # 이미지 저장
    img.save(output_path, 'PNG', quality=95)
    print(f"✅ Feature Graphic 생성 완료: {output_path}")
    print(f"   크기: {width} x {height}")

if __name__ == "__main__":
    create_feature_graphic()