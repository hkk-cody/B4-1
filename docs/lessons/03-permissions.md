# 3. 계정·그룹·권한·ACL

[이전](02-network.md) · [목차](../README.md) · [다음: 앱 환경](04-application.md)

**목표:** 같은 경로에서 어떤 사람은 파일을 만들고 어떤 사람은 거부되는 이유를 설명한다.

## 3.1 계정과 그룹을 나누는 이유

사용자 계정은 “누가 하는 작업인가”를 나타낸다. 그룹은 여러 사용자에게 같은 접근 권한을 주기 위한 묶음이다. 모든 작업을 root로 하면 권한 설계가 맞는지 확인하기 어렵고 실수의 범위도 커진다.

| 계정 | 역할 | agent-common | agent-core |
| --- | --- | --- | --- |
| agent-admin | 앱·관제·cron 운영 | 포함 | 포함 |
| agent-dev | 스크립트 작성·관리 | 포함 | 포함 |
| agent-test | 업로드·테스트 | 포함 | 미포함 |

`agent-admin`이라는 **이름만으로 root 권한이 생기지는 않는다.** 이번 구성에서 이 계정에 특별히 허용한 sudo 명령은 UFW 상태 조회 하나다. 계정 생성·SSH 변경 같은 설치 작업은 VM의 기본 관리 계정에서 수행한다.

```bash
id agent-admin
getent group agent-core
```

`id`의 `uid`는 사용자 번호, `gid`는 기본 그룹 번호, `groups`는 그룹 목록이다. 숫자는 다른 환경에서 달라질 수 있다. 그룹 이름과 구성원이 맞는지가 중요하다.

`getent`는 시스템이 실제로 사용하는 계정 정보 조회 방식을 따른다. `/etc/nsswitch.conf`는 사용자·그룹 등을 파일이나 다른 서비스 중 어디에서 조회할지 정한다. 이 과제에서는 조회만 하면 되며 파일을 편집할 필요는 없다.

## 3.2 rwx와 숫자 권한

```text
-rwxr-x---  agent-dev  agent-core  monitor.sh
 ↑  ↑  ↑
 소유자 / 그룹 / 기타 사용자 각각의 rwx 묶음
```

첫 문자는 종류다. `-`는 일반 파일, `d`는 디렉토리, `l`은 심볼릭 링크다. 그 다음 9문자는 3개씩 끊어서 읽는다.

| 기호 | 숫자 | 파일에서 | 디렉토리에서 |
| --- | --- | --- | --- |
| r | 4 | 내용 읽기 | 항목 이름 목록 보기 |
| w | 2 | 내용 수정 | 항목 생성·삭제·이름 변경(보통 x도 필요) |
| x | 1 | 프로그램 실행 | 통과·진입 및 이름으로 항목 접근 |
| - | 0 | 해당 권한 없음 | 해당 권한 없음 |

7은 4+2+1이라 `rwx`, 5는 4+1이라 `r-x`다.

| 모드 | 뜻 | 현재 사용처 |
| --- | --- | --- |
| 750 | 소유자 rwx, 그룹 r-x, 기타 없음 | monitor.sh, bin |
| 660 | 소유자 rw, 그룹 rw, 기타 없음 | t_secret.key |
| 770 | 소유자 rwx, 그룹 rwx, 기타 없음 | 공유 디렉토리의 기본 접근 정책 |
| 2770 | 770 + setgid | 업로드·키·로그 디렉토리 |

`chmod`는 모드를 바꾸고 `chown`은 소유자·그룹을 바꾼다. `stat`과 `ls -l`은 확인한다. 예를 들어 `sudo chown agent-dev:agent-core 파일`은 해당 파일의 소유자와 그룹을 지정하는 **변경 명령**이다. 현재 설치본은 setup이 이미 적용했으므로 학습을 위해 반복 변경할 필요는 없다.

## 3.3 부모 디렉토리도 통과해야 한다

파일 하나를 열려면 거기까지 가는 모든 디렉토리를 통과할 수 있어야 한다.

```text
/home → /home/agent-admin → agent-app → upload_files
                     ↑
          여기서 x가 없으면 아래가 770이어도 접근 불가
```

현재 구성은 `/home/agent-admin`에 common 그룹의 `--x`만 추가한다. 홈 전체 목록을 공개하지 않고 알려진 앱 경로를 통과하게 한다.

```bash
sudo namei -l /home/agent-admin/agent-app/upload_files
sudo getfacl /home/agent-admin
```

`namei -l`은 경로 각 단계의 기본 권한을 보여 준다. 추가 ACL이 있으면 `getfacl`도 함께 봐야 한다.

디렉토리에 쓰기 권한이 있으면 그 안의 파일을 삭제할 수 있는 경우가 있다. 파일 내용 수정 권한과 디렉토리 항목 삭제 권한은 다르다. `agent-core`에게 키 디렉토리 R/W를 주는 것은 그 그룹을 신뢰한다는 정책이다.

## 3.4 ACL은 무엇을 더 해 주는가?

ACL(Access Control List)은 기본 소유자·그룹·기타 구분에 더해 특정 사용자나 그룹의 접근 규칙을 지정한다.

```bash
sudo getfacl /home/agent-admin/agent-app/upload_files
```

주요 줄을 읽어 보자.

```text
group:agent-common:rwx
mask::rwx
other::---
default:group:agent-common:rwx
default:mask::rwx
default:other::---
```

- `group:agent-common:rwx`: 지금 디렉토리에 적용하는 access ACL이다.
- `default:...`: 이 디렉토리 안에서 앞으로 생성하는 항목에 상속할 기준이다.
- `mask`: 소유 그룹과 이름을 지정한 사용자·그룹 ACL에 허용하는 최대 권한이다. 소유자와 기타 권한의 상한은 아니다.
- `other::---`: 그 밖의 사용자에게 허용하지 않는다.

예를 들어 그룹 ACL이 `rwx`인데 mask가 `r-x`라면 실제 그룹 쓰기는 제한된다. 출력에 `#effective:r-x`처럼 실제 적용값이 표시될 수 있다.

default ACL을 설정했다고 **이미 있던 모든 파일이 자동 변경되지는 않는다.** 또 프로그램이 새 파일을 명시적으로 600으로 만들면 ACL이 그 제한을 무시하고 그룹 쓰기를 강제로 열지는 않는다. 보통의 텍스트 파일 생성과 `mktemp`의 제한적인 파일 생성을 구분한다.

setgid(2770의 앞 2)는 새 항목이 부모 디렉토리의 그룹을 이어받게 한다. ACL은 권한, setgid는 그룹 상속을 맡는다고 먼저 이해하면 좋다.

## 3.5 이 과제의 접근 표

| 경로 | admin | dev | test |
| --- | --- | --- | --- |
| upload_files | 읽기·쓰기 | 읽기·쓰기 | 읽기·쓰기 |
| api_keys | 읽기·쓰기 | 읽기·쓰기 | 접근 거부 |
| /var/log/agent-app | 읽기·쓰기 | 읽기·쓰기 | 접근 거부 |
| bin/monitor.sh | 읽기·실행 | 소유자로 수정·실행 | 접근 거부 |

## 작은 실습: 계정별 동작 확인

**장소: Ubuntu 기본 관리 계정. 영향: 임시 업로드 파일 하나를 만들었다가 제거한다.** setup이 끝난 환경에서 한 블록씩 실행한다.

```bash
sudo -u agent-test bash -c 'f=$(mktemp /home/agent-admin/agent-app/upload_files/lesson.XXXXXX) && printf "upload allowed\n" && rm -- "$f"'
sudo -u agent-test ls /home/agent-admin/agent-app/api_keys
echo $?
```

첫 결과는 `upload allowed`, 두 번째는 `Permission denied`, 종료 코드는 0이 아닌 값이어야 한다. 두 번째 거부는 요구사항대로 동작한 것이다. `mktemp` 실습은 디렉토리 생성 권한만 확인한다. 일반 파일의 ACL 상속과 dev의 실제 수정은 [verify_vm.sh](../../tests/verify_vm.sh)가 별도 검사한다.

```bash
sudo stat -c '%U:%G %a' /home/agent-admin/agent-app/bin/monitor.sh
```

기대값은 `agent-dev:agent-core 750`이다.

## 확인 질문

1. monitor.sh가 750일 때 agent-admin이 실행할 수 있는 이유는?
2. 하위 폴더 권한이 맞는데도 접근이 거부될 때 어디를 보는가?
3. default ACL만 바꾸면 이미 있던 파일도 모두 바뀌는가?

<details>
<summary>답 확인</summary>

1. agent-core 그룹에 속해 있고 그룹에 읽기·실행 권한이 있기 때문이다.
2. 모든 상위 디렉토리의 x, 추가 ACL과 mask, 실제 로그인 세션의 그룹 목록을 본다.
3. 아니다. 주로 이후 생성되는 항목의 상속 기준이다.

</details>
