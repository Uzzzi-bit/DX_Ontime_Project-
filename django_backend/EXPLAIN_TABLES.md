# 생성된 테이블 설명

## 정상적인 테이블 목록

Django 프로젝트를 처음 마이그레이션하면 다음과 같은 테이블들이 자동으로 생성됩니다:

### 1. Django 기본 테이블 (필수)
- `django_migrations` - 마이그레이션 기록
- `django_content_type` - 콘텐츠 타입 관리
- `django_session` - 세션 관리
- `django_admin_log` - 관리자 로그

### 2. Django 인증 시스템 테이블 (필수)
- `auth_user` - 사용자 정보
- `auth_group` - 그룹 정보
- `auth_permission` - 권한 정보
- `auth_user_groups` - 사용자-그룹 관계
- `auth_user_user_permissions` - 사용자-권한 관계
- `auth_group_permissions` - 그룹-권한 관계

### 3. 우리가 만든 앱의 테이블 (실제 데이터 저장)
- `members_member` - 회원 정보 테이블 ✅
- `members_memberpregnancy` - 임신 정보 테이블 ✅

## 결론

**총 12개의 테이블이 생성되는 것이 정상입니다!**

- **10개**: Django가 자동으로 생성하는 기본 테이블 (필수)
- **2개**: 우리가 만든 실제 데이터 저장 테이블

이 테이블들은 Django의 기본 기능(인증, 세션, 관리자 등)을 위해 필요합니다.
실제로 우리가 사용하는 테이블은 `members_member`와 `members_memberpregnancy` 두 개뿐입니다.

## 걱정하지 마세요!

이것은 모든 Django 프로젝트에서 정상적으로 나타나는 현상입니다.
추가로 앱을 만들면 그 앱의 테이블들도 추가로 생성됩니다.

