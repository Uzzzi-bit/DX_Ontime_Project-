# django_backend/members/image_views.py
import json
import traceback

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone

from .models import Image


@csrf_exempt
def save_image(request):
    """
    이미지 정보 저장 또는 조회
    POST /api/images/ - 이미지 저장
    GET /api/images/?member_id={member_id}&image_type={image_type} - 이미지 조회
    
    POST body 예시:
    {
      "member_id": "firebase-uid-123",
      "image_url": "https://firebasestorage.googleapis.com/...",
      "image_type": "meal",
      "source": "meal_form",
      "ingredient_info": null
    }
    """
    print(f'>>> save_image 호출됨: method={request.method}, path={request.path}')
    
    if request.method == 'GET':
        return get_images(request)
    
    if request.method != 'POST':
        return JsonResponse({'error': 'POST or GET only'}, status=405)

    try:
        body = json.loads(request.body.decode())
        print(f'>>> 요청 본문: {body}')
    except json.JSONDecodeError as e:
        print(f'>>> JSON 디코딩 오류: {e}')
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    member_id = body.get('member_id')
    image_url = body.get('image_url')
    image_type = body.get('image_type')
    source = body.get('source')
    ingredient_info = body.get('ingredient_info')

    print(f'>>> 파싱된 데이터:')
    print(f'   - member_id: {member_id}')
    print(f'   - image_type: {image_type}')
    print(f'   - source: {source}')
    print(f'   - image_url 길이: {len(image_url) if image_url else 0}')

    if not (member_id and image_url and image_type and source):
        print(f'>>> 필수 필드 누락')
        return JsonResponse({'error': '필수 필드 누락: member_id, image_url, image_type, source'}, status=400)

    try:
        # 이미지 정보 저장
        print(f'>>> DB에 이미지 저장 시도...')
        image = Image.objects.create(
            member_id=member_id,
            image_url=image_url,
            image_type=image_type,
            source=source,
            ingredient_info=ingredient_info,
            created_at=timezone.now(),
        )
        print(f'>>> ✅ 이미지 저장 성공: id={image.id}, member_id={image.member_id}')

        return JsonResponse({
            'ok': True,
            'id': image.id,
            'image_id': image.id,  # image_id는 id와 동일
            'member_id': image.member_id,
            'image_url': image.image_url,
            'image_type': image.image_type,
            'source': image.source,
            'created_at': image.created_at.isoformat(),
        }, status=201)

    except Exception as e:
        print(f'>>> ❌ 이미지 저장 실패: {e}')
        traceback.print_exc()
        return JsonResponse(
            {'error': 'Server error in save_image', 'detail': str(e)},
            status=500,
        )


@csrf_exempt
def update_image(request, image_id):
    """
    이미지 정보 업데이트 (주로 ingredient_info 업데이트)
    PUT /api/images/<image_id>/
    
    body 예시:
    {
      "ingredient_info": "{...json...}"
    }
    """
    if request.method != 'PUT':
        return JsonResponse({'error': 'PUT only'}, status=405)

    try:
        body = json.loads(request.body.decode())
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    try:
        image = Image.objects.get(id=image_id)
    except Image.DoesNotExist:
        return JsonResponse({'error': 'image not found'}, status=404)

    try:
        # ingredient_info 업데이트
        if 'ingredient_info' in body:
            image.ingredient_info = body.get('ingredient_info')
            image.save(update_fields=['ingredient_info'])

        return JsonResponse({
            'ok': True,
            'id': image.id,
            'image_id': image.id,
            'ingredient_info': image.ingredient_info,
        })

    except Exception as e:
        traceback.print_exc()
        return JsonResponse(
            {'error': 'Server error in update_image', 'detail': str(e)},
            status=500,
        )


def get_images(request):
    """
    이미지 목록 조회
    GET /api/images/?member_id={member_id}&image_type={image_type}
    """
    member_id = request.GET.get('member_id')
    image_type = request.GET.get('image_type')

    if not member_id:
        return JsonResponse({'error': 'member_id is required'}, status=400)

    try:
        images = Image.objects.filter(member_id=member_id)
        
        if image_type:
            images = images.filter(image_type=image_type)
        
        images = images.order_by('-created_at')

        results = []
        for img in images:
            results.append({
                'id': img.id,
                'image_id': img.id,
                'member_id': img.member_id,
                'image_url': img.image_url,
                'ingredient_info': img.ingredient_info,
                'image_type': img.image_type,
                'source': img.source,
                'created_at': img.created_at.isoformat(),
            })

        return JsonResponse({
            'ok': True,
            'results': results,
            'count': len(results),
        })

    except Exception as e:
        traceback.print_exc()
        return JsonResponse(
            {'error': 'Server error in get_images', 'detail': str(e)},
            status=500,
        )

