# django_backend/members/ai_chat_views.py
"""
AI 채팅 세션 및 메시지 관리 API
"""
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.db.models import Q
from .models import AiChatSession, AiChat, Image


@csrf_exempt
def create_session(request):
    """
    POST /api/ai-chat/sessions/
    body: { "member_id": "firebase-uid" }
    응답: { "session_id": 1, "started_at": "2025-12-03T10:00:00Z" }
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        body = json.loads(request.body.decode('utf-8'))
        member_id = body.get('member_id')

        if not member_id:
            return JsonResponse({'error': 'member_id is required'}, status=400)

        # 새 세션 생성
        session = AiChatSession.objects.create(
            member_id=member_id,
            started_at=timezone.now(),
        )

        return JsonResponse({
            'session_id': session.id,
            'member_id': session.member_id,
            'started_at': session.started_at.isoformat(),
        }, status=201)

    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def get_session(request, session_id):
    """
    GET /api/ai-chat/sessions/{session_id}/
    응답: { "session_id": 1, "member_id": "...", "started_at": "...", "ended_at": null }
    """
    if request.method != 'GET':
        return JsonResponse({'error': 'GET only'}, status=405)

    try:
        session = AiChatSession.objects.get(id=session_id)

        return JsonResponse({
            'session_id': session.id,
            'member_id': session.member_id,
            'started_at': session.started_at.isoformat(),
            'ended_at': session.ended_at.isoformat() if session.ended_at else None,
        })

    except AiChatSession.DoesNotExist:
        return JsonResponse({'error': 'Session not found'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def list_sessions(request, member_id):
    """
    GET /api/ai-chat/sessions/{member_id}/
    사용자의 모든 세션 목록 조회 (최신순)
    응답: [{ "session_id": 1, "started_at": "...", "ended_at": null, ... }, ...]
    """
    if request.method != 'GET':
        return JsonResponse({'error': 'GET only'}, status=405)

    try:
        sessions = AiChatSession.objects.filter(
            member_id=member_id
        ).order_by('-started_at')[:20]  # 최근 20개만

        sessions_data = [{
            'session_id': s.id,
            'member_id': s.member_id,
            'started_at': s.started_at.isoformat(),
            'ended_at': s.ended_at.isoformat() if s.ended_at else None,
        } for s in sessions]

        return JsonResponse({'sessions': sessions_data})

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def end_session(request, session_id):
    """
    POST /api/ai-chat/sessions/{session_id}/end/
    body: {}
    세션 종료 (ended_at 업데이트)
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        session = AiChatSession.objects.get(id=session_id)
        session.ended_at = timezone.now()
        session.save()

        return JsonResponse({
            'session_id': session.id,
            'ended_at': session.ended_at.isoformat(),
        })

    except AiChatSession.DoesNotExist:
        return JsonResponse({'error': 'Session not found'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def reactivate_session(request, session_id):
    """
    POST /api/ai-chat/sessions/{session_id}/reactivate/
    body: {}
    세션 재활성화 (ended_at을 null로 설정하여 대화 이어가기)
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        session = AiChatSession.objects.get(id=session_id)
        session.ended_at = None
        session.save()

        return JsonResponse({
            'session_id': session.id,
            'ended_at': None,
            'started_at': session.started_at.isoformat(),
        })

    except AiChatSession.DoesNotExist:
        return JsonResponse({'error': 'Session not found'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def save_message(request):
    """
    POST /api/ai-chat/messages/
    body: {
        "session_id": 1,
        "member_id": "firebase-uid",
        "type": "user" | "ai",
        "content": "메시지 내용",
        "image_pk": null | 123  // optional
    }
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        print(f">>> save_message 호출됨: method={request.method}, path={request.path}")
        body = json.loads(request.body.decode('utf-8'))
        print(f">>> save_message 요청 body: {body}")
        
        session_id = body.get('session_id')
        member_id = body.get('member_id')
        msg_type = body.get('type')
        content = body.get('content')
        image_pk = body.get('image_pk')

        if not all([session_id, member_id, msg_type, content]):
            print(f">>> ❌ 필수 필드 누락: session_id={session_id}, member_id={member_id}, type={msg_type}, content={content}")
            return JsonResponse({
                'error': 'session_id, member_id, type, content are required'
            }, status=400)

        if msg_type not in ['user', 'ai']:
            return JsonResponse({'error': 'type must be "user" or "ai"'}, status=400)

        # 세션 확인
        try:
            session = AiChatSession.objects.get(id=session_id)
            print(f">>> ✅ 세션 확인 완료: session_id={session_id}")
        except AiChatSession.DoesNotExist:
            print(f">>> ❌ 세션 없음: session_id={session_id}")
            return JsonResponse({'error': 'Session not found'}, status=404)

        # 이미지 확인 (있으면)
        image = None
        if image_pk:
            try:
                image = Image.objects.get(id=image_pk)
                print(f">>> ✅ 이미지 확인 완료: image_pk={image_pk}")
            except Image.DoesNotExist:
                print(f">>> ❌ 이미지 없음: image_pk={image_pk}")
                return JsonResponse({'error': 'Image not found'}, status=404)

        # 메시지 저장
        print(f">>> 메시지 저장 시도: session_id={session_id}, member_id={member_id}, type={msg_type}")
        chat = AiChat.objects.create(
            member_id=member_id,
            session=session,
            type=msg_type,
            content=content,
            image=image,
        )
        print(f">>> ✅ 메시지 저장 성공: chat_id={chat.id}, session_id={chat.session.id}")

        return JsonResponse({
            'chat_id': chat.id,
            'session_id': session.id,
            'type': chat.type,
            'content': chat.content,
            'image_pk': chat.image.id if chat.image else None,
            'created_at': chat.created_at.isoformat(),
        }, status=201)

    except json.JSONDecodeError as e:
        print(f">>> ❌ JSON 파싱 오류: {e}")
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    except Exception as e:
        print(f">>> ❌ 메시지 저장 실패: {e}")
        import traceback
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def get_messages(request, session_id):
    """
    GET /api/ai-chat/sessions/{session_id}/messages/
    세션의 모든 메시지 조회 (시간순)
    응답: [{ "chat_id": 1, "type": "user", "content": "...", ... }, ...]
    """
    if request.method != 'GET':
        return JsonResponse({'error': 'GET only'}, status=405)

    try:
        # 세션 확인
        try:
            session = AiChatSession.objects.get(id=session_id)
        except AiChatSession.DoesNotExist:
            return JsonResponse({'error': 'Session not found'}, status=404)

        # 메시지 조회
        messages = AiChat.objects.filter(session_id=session_id).order_by('created_at')

        messages_data = [{
            'chat_id': m.id,
            'member_id': m.member_id,
            'type': m.type,
            'content': m.content,
            'image_pk': m.image.id if m.image else None,
            'created_at': m.created_at.isoformat(),
        } for m in messages]

        return JsonResponse({'messages': messages_data})

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

