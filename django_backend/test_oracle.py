import oracledb

USER = "PREGNANT_APP"      # 네가 settings.py에 적은 USER 그대로
PASSWORD = "MyPass1234"    # 위랑 동일
DSN = "localhost:1521/XEPDB1"  # 또는 'localhost:1521/xe' (실제 사용하는 서비스 이름)

try:
    conn = oracledb.connect(user=USER, password=PASSWORD, dsn=DSN)
    print("✅ Connected to Oracle!")
    conn.close()
except Exception as e:
    print("❌ Oracle connect error:")
    print(e)
