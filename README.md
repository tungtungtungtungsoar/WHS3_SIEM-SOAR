# WHS3_SIEM-SOAR


## 프로젝트 개요

- 침해사고를 실시간 탐지하고 자동 대응 및 복구까지 수행하는 SIEM/SOAR 기반 프로젝트.
- AWS 인프라 위에 Wazuh와 YARA를 기반으로 한 탐지 규칙을 적용하고, Active Response와 Terraform을 이용해 IP 차단, 인스턴스 격리, 자동 복구를 구현하였다.
- MITRE ATT&CK 기반의 실전 공격 시나리오를 설계하여, 웹쉘 업로드·리버스쉘·랜섬웨어 같은 침해 위협을 재현하고 엔드투엔드(End-to-End) 보안 대응 체계를 완성하였다.

---

## 기술 스택   
- Infrastructure as Code : Terraform   
- Cloud : AWS
- Security Monitoring & Detection : Wazuh, YARA   
- Incident Response : Wazuh Active Response, Bash Script   
- Collaboration/Notification : Slack API

----

## 전체 인프라 구성
<img width="2579" height="1289" alt="전체 인프라" src="https://github.com/user-attachments/assets/02f0eb54-1292-45f8-8268-33e577890c60" />


---

## 공격 시나리오 타임라인
<img width="1490" height="546" alt="image" src="https://github.com/user-attachments/assets/ec587921-e843-4143-8628-57e216dfe3a4" />


---

## 주요 기능

### 공격 탐지 (Custom Rules)
- 웹쉘 업로드/수정/실행 탐지 (파일 무결성 + auditd)   
- 난독화 웹쉘 탐지 (YARA, evalhook)   
- 공격 도구(Gobuster) 사용 탐지 및 반복 스캔 차단   
- 리버스쉘 연결 탐지 (ESTABLISHED 소켓 필터)   
- PEM 키 접근 탐지 및 SSH 화이트리스트 기반 차단   
- 더미 계정 로그인 탐지 및 자동 격리   
- 랜섬웨어 탐지 (암호화 확장자, 랜섬노트 생성, 대량 파일 수정)

### 자동 대응 (Active Response + Terraform)
- 탐지 이벤트 발생 시 IP 차단, 네트워크 인터페이스 차단, 세션 종료   
- 더미 계정 로그인 시 DB 서버 자동 격리   
- 랜섬웨어 감염 시 Terraform으로 서비스 인스턴스 자동 복구 및 포렌식 환경 생성   

### Slack 알림
- Wazuh와 Slack Webhook 연동   
- Level 7 이상 경고 필터링 후 실시간 알림 전송   
- 탐지 룰명, 에이전트, 핵심 로그 정보 제공

---

## 성과
- 탐지 → 대응 → 복구까지 완전 자동화된 SOAR 프로세스 구현   
- YARA와 evalhook 기반의 난독화 웹쉘 탐지 도입
- Wazuh 공식팀에 룰셋 개선 사항 피드백
- 프로젝트 전체 코드 및 설정을 GitHub에 공개

