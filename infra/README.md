# ColorTrip 인프라 (Terraform / IaC)

GCP 운영 인프라를 **Terraform**으로 관리합니다. 단일 프로젝트(`colortrip`)로 시작하며, 환경은 `dev`부터 만들고 **prod는 나중에 `envs/prod/`를 추가**해 확장합니다.

> 인프라 결정의 단일 출처(SOT)는 [docs/conventions/infra-deploy.md](../docs/conventions/infra-deploy.md)입니다.

## 구조

```text
infra/
├── modules/        # 재사용 모듈
│   └── network/    # VPC·서브넷·방화벽  (instance·database 모듈은 단계적으로 추가)
├── envs/
│   └── dev/        # dev 환경 (상태=GCS 백엔드 colortrip-tfstate, prefix=envs/dev)
└── scripts/
    └── db-proxy.sh # Cloud SQL Auth Proxy 로컬 실행 헬퍼
```

리소스 이름엔 환경 접두사(`colortrip-dev-*`)를 붙여, 같은 프로젝트에 prod가 들어와도 충돌하지 않게 합니다.

## 사전 준비

- gcloud 로그인 + ADC: `gcloud auth login` & `gcloud auth application-default login`
- Terraform >= 1.5

## 사용

```bash
cd infra/envs/dev
terraform init      # 백엔드(GCS)·프로바이더 초기화
terraform plan      # 변경 미리보기(아무것도 만들지 않음)
terraform apply     # 실제 생성/변경
```

## Cloud SQL 로컬 접속

Cloud SQL은 **Auth Proxy**로 연결합니다. 로컬에서 DB에 붙을 때:

```bash
./scripts/db-proxy.sh        # localhost:5432 로 프록시 오픈
```

상세 사전 준비는 스크립트 상단 주석을 참고하세요.

## 상태(state)

원격 상태는 GCS 버킷 `colortrip-tfstate`(버전 관리 활성)의 `envs/dev` prefix에 저장됩니다. 로컬에 `*.tfstate`를 두지 않습니다.
