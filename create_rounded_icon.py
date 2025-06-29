#!/usr/bin/env python3
"""
Flutter 스플래시와 동일한 둥근 모서리 + 그림자 아이콘 생성
"""

from PIL import Image, ImageDraw, ImageFilter
import os

def create_rounded_icon_with_shadow():
    # 원본 아이콘 로드
    icon_path = 'ui-reference/icon.png'
    if not os.path.exists(icon_path):
        print(f"❌ 아이콘 파일을 찾을 수 없습니다: {icon_path}")
        return None
    
    # 원본 아이콘 로드
    original_icon = Image.open(icon_path)
    
    # 고해상도로 작업 (최종 크기의 4배)
    final_size = 120
    work_size = final_size * 4  # 480px
    
    # 아이콘을 작업 크기로 리사이즈
    icon = original_icon.resize((work_size, work_size), Image.Resampling.LANCZOS)
    
    # 그림자를 위한 여유 공간 추가
    shadow_offset = 32  # 8px * 4 (고해상도)
    shadow_blur = 80    # 20px * 4 (고해상도)
    canvas_size = work_size + shadow_blur + shadow_offset
    
    # 투명 캔버스 생성
    canvas = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    
    # 둥근 모서리를 위한 마스크 생성
    mask = Image.new('L', (work_size, work_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = 96  # 24px * 4 (고해상도)
    mask_draw.rounded_rectangle(
        [(0, 0), (work_size-1, work_size-1)], 
        radius=corner_radius, 
        fill=255
    )
    
    # 아이콘에 둥근 모서리 적용
    rounded_icon = Image.new('RGBA', (work_size, work_size), (0, 0, 0, 0))
    rounded_icon.paste(icon, (0, 0))
    rounded_icon.putalpha(mask)
    
    # 그림자 생성
    shadow = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    
    # 그림자 위치 계산
    shadow_x = (canvas_size - work_size) // 2
    shadow_y = shadow_x + shadow_offset  # Y축으로 8px 오프셋
    
    # 그림자 그리기 (검은색, 10% 투명도)
    shadow_draw.rounded_rectangle(
        [(shadow_x, shadow_y), (shadow_x + work_size, shadow_y + work_size)],
        radius=corner_radius,
        fill=(0, 0, 0, int(255 * 0.1))  # 10% opacity
    )
    
    # 그림자 블러 적용
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=shadow_blur//4))
    
    # 최종 이미지 조합
    final_canvas = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    final_canvas.paste(shadow, (0, 0), shadow)
    
    # 아이콘을 중앙에 배치
    icon_x = (canvas_size - work_size) // 2
    icon_y = icon_x  # 그림자와 달리 Y 오프셋 없음
    final_canvas.paste(rounded_icon, (icon_x, icon_y), rounded_icon)
    
    # 최종 크기로 리사이즈
    final_icon = final_canvas.resize((final_size * 2, final_size * 2), Image.Resampling.LANCZOS)
    
    # 출력 경로들
    output_paths = {
        'mdpi': 'flutter-app/android/app/src/main/res/drawable-mdpi/splash_icon_styled.png',
        'hdpi': 'flutter-app/android/app/src/main/res/drawable-hdpi/splash_icon_styled.png',
        'xhdpi': 'flutter-app/android/app/src/main/res/drawable-xhdpi/splash_icon_styled.png',
        'xxhdpi': 'flutter-app/android/app/src/main/res/drawable-xxhdpi/splash_icon_styled.png',
        'xxxhdpi': 'flutter-app/android/app/src/main/res/drawable-xxxhdpi/splash_icon_styled.png'
    }
    
    # 각 해상도별 이미지 생성
    sizes = {
        'mdpi': final_size,           # 120px
        'hdpi': int(final_size * 1.5), # 180px
        'xhdpi': final_size * 2,      # 240px
        'xxhdpi': final_size * 3,     # 360px
        'xxxhdpi': final_size * 4     # 480px
    }
    
    for density, path in output_paths.items():
        # 디렉토리 생성
        os.makedirs(os.path.dirname(path), exist_ok=True)
        
        # 해당 해상도로 리사이즈
        size = sizes[density]
        resized = final_canvas.resize((size, size), Image.Resampling.LANCZOS)
        
        # PNG로 저장
        resized.save(path, 'PNG')
        print(f"✅ {density} 아이콘 생성: {path} ({size}x{size})")
    
    return output_paths

if __name__ == "__main__":
    create_rounded_icon_with_shadow()