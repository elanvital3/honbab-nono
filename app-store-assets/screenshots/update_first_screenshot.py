#!/usr/bin/env python3
"""
1번 스크린샷만 글자 크기를 키워서 다시 처리하는 스크립트
"""

from PIL import Image, ImageDraw, ImageFont
import os

def add_text_to_image_large(image_path, output_path, title, subtitle):
    """1번 스크린샷용 큰 글자 버전"""
    try:
        # 이미지 열기
        img = Image.open(image_path)
        
        # 이미지 크기 가져오기
        width, height = img.size
        
        # 프레임 크기 설정 (Google Play Store 스타일)
        frame_width = width + 200  # 좌우 여백
        frame_height = height + 300  # 상하 여백 (텍스트 영역 포함)
        
        # 혼밥노노 브랜드 컬러
        brand_beige = (210, 180, 140)  # #D2B48C
        brand_beige_light = (240, 220, 190)  # 연한 베이지
        text_dark = (80, 60, 40)  # 어두운 브라운
        text_white = (255, 255, 255)  # 흰색
        
        # 새로운 프레임 캔버스 생성
        frame = Image.new('RGB', (frame_width, frame_height), brand_beige_light)
        
        # 스마트폰 프레임 그리기
        phone_x = 100
        phone_y = 230
        phone_width = width
        phone_height = height
        
        # 스마트폰 배경 (그림자 효과)
        shadow_offset = 8
        shadow_color = (0, 0, 0, 50)
        shadow_frame = Image.new('RGBA', (frame_width, frame_height), (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow_frame)
        shadow_draw.rounded_rectangle(
            [phone_x + shadow_offset, phone_y + shadow_offset, 
             phone_x + phone_width + shadow_offset, phone_y + phone_height + shadow_offset], 
            radius=30, fill=shadow_color
        )
        
        # 스마트폰 프레임 (둥근 모서리)
        phone_frame = Image.new('RGBA', (frame_width, frame_height), (0, 0, 0, 0))
        phone_draw = ImageDraw.Draw(phone_frame)
        phone_draw.rounded_rectangle(
            [phone_x, phone_y, phone_x + phone_width, phone_y + phone_height], 
            radius=30, fill=(40, 40, 40)
        )
        
        # 스마트폰 스크린 영역 (내부 패딩)
        screen_padding = 8
        screen_x = phone_x + screen_padding
        screen_y = phone_y + screen_padding
        screen_width = phone_width - (screen_padding * 2)
        screen_height = phone_height - (screen_padding * 2)
        
        # 레이어 합성
        frame = Image.alpha_composite(frame.convert('RGBA'), shadow_frame)
        frame = Image.alpha_composite(frame, phone_frame)
        
        # 스크린샷 이미지 크기 조정 및 삽입
        screen_img = img.resize((screen_width, screen_height), Image.Resampling.LANCZOS)
        screen_mask = Image.new('L', (screen_width, screen_height), 0)
        screen_mask_draw = ImageDraw.Draw(screen_mask)
        screen_mask_draw.rounded_rectangle([0, 0, screen_width, screen_height], radius=22, fill=255)
        
        frame.paste(screen_img, (screen_x, screen_y), screen_mask)
        
        # 텍스트 추가
        draw = ImageDraw.Draw(frame)
        
        # 한국어 폰트 설정 (더 큰 크기 + SemiBold)
        try:
            # AppleSDGothicNeo SemiBold (중간 두께)
            title_font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 64, index=5)  # SemiBold
            subtitle_font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 42, index=5)  # SemiBold
        except:
            try:
                # Bold 시도
                title_font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 64, index=6)  # Bold
                subtitle_font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 42, index=6)  # Bold
            except:
                title_font = ImageFont.load_default()
                subtitle_font = ImageFont.load_default()
        
        # 텍스트 영역 (상단에 모든 텍스트 배치)
        text_start_y = 55
        
        # 제목 텍스트 (첫 번째 줄)
        title_bbox = draw.textbbox((0, 0), title, font=title_font)
        title_width = title_bbox[2] - title_bbox[0]
        title_x = max(20, (frame_width - title_width) // 2)  # 최소 여백 20px
        title_y = text_start_y
        
        # 제목이 너무 길면 자동으로 줄바꿈
        if title_width > frame_width - 40:  # 좌우 여백 20px씩
            words = title.split()
            lines = []
            current_line = ""
            
            for word in words:
                test_line = current_line + word + " "
                test_bbox = draw.textbbox((0, 0), test_line, font=title_font)
                test_width = test_bbox[2] - test_bbox[0]
                
                if test_width <= frame_width - 40:
                    current_line = test_line
                else:
                    if current_line:
                        lines.append(current_line.strip())
                        current_line = word + " "
                    else:
                        lines.append(word)
            
            if current_line:
                lines.append(current_line.strip())
            
            # 여러 줄 제목 그리기 (stroke 효과)
            for i, line in enumerate(lines):
                line_bbox = draw.textbbox((0, 0), line, font=title_font)
                line_width = line_bbox[2] - line_bbox[0]
                line_x = (frame_width - line_width) // 2
                line_y = text_start_y + (i * 72)
                
                # 메인 텍스트만 (stroke 없이)
                draw.text((line_x, line_y), line, font=title_font, fill=text_dark)
            
            subtitle_y_start = text_start_y + len(lines) * 72 + 30
        else:
            # 한 줄 제목 그리기 (stroke 없이)
            draw.text((title_x, title_y), title, font=title_font, fill=text_dark)
            subtitle_y_start = text_start_y + 72 + 30
        
        # 부제목 텍스트 (제목 바로 아래)
        subtitle_lines = subtitle.split('\n')
        for i, line in enumerate(subtitle_lines):
            line_bbox = draw.textbbox((0, 0), line, font=subtitle_font)
            line_width = line_bbox[2] - line_bbox[0]
            line_x = max(20, (frame_width - line_width) // 2)  # 최소 여백 20px
            line_y = subtitle_y_start + (i * 52)
            
            # 부제목은 stroke 없이 깔끔하게
            draw.text((line_x, line_y), line, font=subtitle_font, fill=text_dark)
        
        # 이미지 저장
        frame.convert('RGB').save(output_path, 'JPEG', quality=95)
        print(f"✅ 1번 스크린샷 큰 글자로 처리 완료: {output_path}")
        
    except Exception as e:
        print(f"❌ 에러 발생 ({image_path}): {e}")

# 1번 스크린샷만 처리
add_text_to_image_large(
    "/Users/elanvital3/Projects/2025_honbab-nono/app-store-assets/screenshots/original/01_home_restaurant_list.jpeg",
    "/Users/elanvital3/Projects/2025_honbab-nono/app-store-assets/screenshots/processed/01_home_restaurant_list.jpeg",
    "여행지 맛집을 한눈에 발견하세요",
    "구글 평점과 유튜브 추천 맛집을 모두 확인할 수 있어요"
)