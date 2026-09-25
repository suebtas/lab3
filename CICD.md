# ข้อกำหนด CI/CD และการ Deploy Flutter Web ด้วย Docker

## 1. วัตถุประสงค์และขอบเขต

เอกสารนี้กำหนดความต้องการสำหรับนำแอป `startup_hr` ที่มีอยู่ไป build เป็น Flutter Web และให้บริการผ่าน Docker container บนเครื่องผู้ใช้ โดยเริ่มต้นที่ `http://localhost:8080` ผลลัพธ์หลักต้องเป็น Docker image แบบ immutable และ portable ซึ่งใช้ image เดียวกันในการทดสอบ, local deployment และ production deployment ในอนาคตได้

เอกสารนี้เป็นข้อกำหนดสำหรับระยะ implementation เท่านั้น การมีรายการไฟล์หรือคำสั่งในเอกสารไม่ได้หมายความว่าไฟล์ Deploy, workflow, SSH key หรือระบบที่กล่าวถึงถูกสร้างและทดสอบแล้ว

ข้อกำหนดสำคัญ:

- source code เดิมต้องคงอยู่ที่ root ของโปรเจกต์ โดยเฉพาะ `lib/`, `test/`, `pubspec.yaml` และไฟล์ Flutter ที่เกี่ยวข้อง
- ห้ามย้ายหรือทำสำเนา application source code ไปไว้ใน `deploy/CICD/`
- `docker-compose.yml` ที่ root ต้องคงไว้สำหรับ OpenCode development environment และต้องไม่ถูกใช้เป็น Compose file ของเว็บแอป
- deployment configuration ใหม่ต้องอยู่ใน `deploy/CICD/` ยกเว้น GitHub Actions workflow ซึ่งตามมาตรฐานต้องอยู่ใน `.github/workflows/`
- ห้ามเก็บ credential, token, password หรือ private key ใน repository
- ห้ามใช้การ mount `build/web` หรือ application source จาก host เป็นรูปแบบ production deployment
- local deployment ต้องทดสอบ runtime image เดียวกับ artifact ที่จะเผยแพร่ ไม่สร้าง image คนละแบบสำหรับแต่ละ environment

## 2. สถานะโปรเจกต์ที่ตรวจพบ

ตรวจสอบจากไฟล์ในพาธปัจจุบันเมื่อจัดทำเอกสาร พบสถานะดังนี้:

| รายการ | สถานะที่ตรวจพบ | ผลต่อการดำเนินงาน |
| --- | --- | --- |
| Application | Flutter/Dart ชื่อ `startup_hr` | ใช้ source เดิมเป็นแอปที่จะ Deploy |
| Dart constraint | `>=3.0.0 <4.0.0` จาก `pubspec.yaml` | เวอร์ชัน Flutter ที่เลือกต้องมาพร้อม Dart ที่อยู่ในช่วงนี้ |
| Dependencies | Flutter SDK; dev dependencies คือ `flutter_test` และ `flutter_lints: ^3.0.0` | ใช้ `flutter analyze` และ `flutter test` เป็น quality gates |
| Source | มี `lib/main.dart`, `lib/core/`, `lib/data/`, `lib/domain/` และ `lib/screens/` | ไม่ย้าย source ออกจากโครงสร้างเดิม |
| Tests | มี `test/payroll_engine_test.dart` และ `test/widget_smoke_test.dart` | ต้องรันทั้งหมดใน CI |
| Flutter Web scaffold | มีโฟลเดอร์ `web/` และ `.metadata` แล้ว | ต้องรักษา scaffold และเพิ่ม custom bootstrap ได้เมื่อจำเป็นต่อ browser runtime |
| Root Compose | service `opencode-env` ใช้ `node:24-slim`, mount โปรเจกต์ที่ `/workspace` และติดตั้ง `opencode-ai` | ไม่ใช่ runtime ของ Flutter Web และห้ามแก้หรือใช้แทน Compose ใหม่ |
| Deploy directory | มี portable-image, Nginx และ Compose artifacts ภายใต้ `deploy/CICD/` แล้ว | ให้ปรับปรุงและตรวจซ้ำตามเอกสารนี้ ห้ามย้ายกลับไป root Compose |
| Git working tree | พาธปัจจุบันไม่ใช่ Git working tree และไม่พบ `.git` | ยังยืนยัน branch, commit และ remote จาก local Git ไม่ได้ |
| GitHub repository | ระบุเป้าหมายเป็น `https://github.com/suebtas/lab3` แต่ไม่สามารถยืนยันเนื้อหาจาก public access ได้ | ต้องยืนยันว่า repository มีอยู่และบัญชีที่ใช้งานมีสิทธิ์ ก่อนเชื่อม local project หรือสร้าง workflow |
| Flutter toolchain | ใช้ pinned Flutter builder image ผ่าน Docker ได้ | local host ไม่จำเป็นต้องติดตั้ง Flutter แต่เวอร์ชัน package และ builder image ต้องสอดคล้องกัน |

ห้ามถือว่า local project และ `suebtas/lab3` เป็น code revision เดียวกันจนกว่าจะยืนยันด้วย Git remote และ commit history ได้

## 3. สถาปัตยกรรมที่แนะนำ

ใช้สถาปัตยกรรมแบบ immutable static web deployment:

1. Flutter/Dart เป็น application และ test stack เดิม
2. multi-stage Dockerfile ต้องมี stage ที่รองรับ dependency restore, `flutter analyze`, `flutter test` และ `flutter build web --release`
3. runtime stage ใช้ Nginx แบบ unprivileged และ `COPY` เฉพาะผลลัพธ์จาก `build/web` กับ runtime configuration เข้า image
4. local Docker Compose build และรัน runtime image เดียวกับที่ผ่าน smoke test
5. production Docker Compose อ้างอิง published image ด้วย immutable tag หรือ digest และต้องไม่มี `build:` หรือ source volume
6. Playwright browser-test container เปิด runtime image จริง ตรวจ UI, console, page errors และ network failures โดยไม่รวม browser ไว้ใน production image
7. GitHub Actions ทำ CI ตั้งแต่ quality gates, Docker build, image inspection, HTTP smoke test จนถึง browser smoke test
8. CD ระยะถัดไปเผยแพร่ image ที่ผ่าน CI ไปยัง registry โดยไม่ rebuild แล้วให้ environment เป้าหมาย pull image เดิม

แนวทางนี้แยกเครื่องมือ build ออกจาก runtime ทำให้ runtime image ไม่มี Flutter SDK, source code หรือ build tools และสามารถเคลื่อนย้ายผ่าน registry หรือ `docker save`/`docker load` ได้

ก่อน implementation ต้องเลือกและบันทึกเวอร์ชัน Flutter ที่เข้ากันกับ Dart constraint ปัจจุบัน รวมทั้ง pin Docker base images ด้วย immutable digest เมื่อใช้งานจริง ไม่ใช้ `latest` และไม่ปล่อยเวอร์ชันหลักให้เปลี่ยนโดยไม่ตั้งใจ

## 4. โครงสร้างไฟล์เป้าหมาย

โครงสร้างที่คาดว่าจะสร้างในระยะ implementation:

```text
.
├── .github/
│   └── workflows/
│       └── ci.yml
├── deploy/
│   └── CICD/
│       ├── Dockerfile
│       ├── Dockerfile.dockerignore
│       ├── docker-compose.yml
│       ├── docker-compose.test.yml
│       ├── docker-compose.production.yml
│       ├── nginx.conf
│       ├── browser-tests/
│       │   ├── package.json
│       │   ├── package-lock.json
│       │   ├── playwright.config.js
│       │   └── tests/
│       │       └── smoke.spec.js
│       ├── .env.example
│       └── README.md
├── lib/
├── test/
├── web/
│   └── flutter_bootstrap.js   # optional custom loader สำหรับ local CanvasKit
├── docker-compose.yml         # ของเดิมสำหรับ OpenCode; ห้ามแก้ไข
└── pubspec.yaml
```

หน้าที่ของไฟล์:

- `Dockerfile` — multi-stage build สำหรับ Flutter Web และ Nginx runtime
- `Dockerfile.dockerignore` — ตัด `.git/`, `.dart_tool/`, `build/`, Playwright reports/results, browser dependency caches, IDE files, logs และข้อมูลลับออกจาก build context
- `docker-compose.yml` — กำหนด service ของเว็บแอป, port, health check และ runtime restrictions
- `docker-compose.test.yml` — Compose overlay สำหรับ Playwright browser test; ใช้เฉพาะ local/CI และไม่เป็นส่วนหนึ่งของ production deployment
- `docker-compose.production.yml` — อ้างอิง published image ผ่าน `IMAGE_REF` เท่านั้น ไม่มี `build:` และไม่มี source/build volume
- `nginx.conf` — ให้บริการ static assets, รองรับ Flutter client-side routing ด้วย fallback ไป `index.html`, กำหนด `/healthz` และ security headers ขั้นพื้นฐาน
- `.env.example` — ตัวอย่างค่าที่ปรับได้ เช่น `APP_PORT=8080` โดยไม่มี secret
- `README.md` — คู่มือ build, start, verify, logs และ stop
- `.github/workflows/ci.yml` — workflow ของ GitHub Actions; อยู่ตำแหน่งมาตรฐาน ไม่อยู่ใต้ `deploy/CICD/`
- `browser-tests/` — test harness ที่เปิด browser จริง เก็บ console, page errors, failed requests, screenshot และ trace
- `web/flutter_bootstrap.js` — ใช้เมื่อจำเป็นต้องกำหนด Flutter loader เช่น `canvasKitBaseUrl` ให้โหลด asset ภายใน image

ไฟล์ `.github/workflows/release.yml` เป็น deliverable ของระยะ publish/CD หลังยืนยัน repository, registry และ approval policy แล้ว ไม่ให้สร้างหรือเปิดใช้งานในรอบ local implementation ปัจจุบัน

เนื่องจาก Docker build context ต้องครอบคลุม Flutter source ที่ root ให้ Compose กำหนดค่าตามแนวคิดนี้:

```yaml
build:
  context: ../..
  dockerfile: deploy/CICD/Dockerfile
```

เมื่อ context เป็น root ไฟล์ ignore แบบเฉพาะ Dockerfile ควรใช้ชื่อ `deploy/CICD/Dockerfile.dockerignore` แทนการใช้ `deploy/CICD/.dockerignore` ซึ่งไม่ได้อยู่ที่ root ของ build context ทั้งนี้ต้องทดสอบกับ Docker/BuildKit เวอร์ชันเป้าหมายก่อนยืนยัน implementation

## 5. ข้อกำหนด Docker และ Compose

- service name ที่แนะนำคือ `startup-hr-web`
- หลีกเลี่ยงการกำหนด `container_name` เพื่อให้ Compose แยก project และรองรับหลาย instance ได้ตามปกติ
- container รับ HTTP ภายในที่ port `8080` เมื่อใช้ unprivileged Nginx
- host port เริ่มต้นคือ `8080` และเปลี่ยนผ่านตัวแปร `APP_PORT` ได้โดยไม่แก้ source code เช่น `${APP_PORT:-8080}:8080`
- Compose project name ต้องเป็น `lab3-cicd` เพื่อไม่ชนกับ root Compose
- ต้องมี health check เรียก `http://127.0.0.1:8080/healthz` ภายใน container และถือว่าสำเร็จเมื่อได้ HTTP 200
- runtime ต้องใช้ read-only filesystem เมื่อทำได้ พร้อม `tmpfs` เฉพาะ path ที่ Nginx จำเป็นต้องเขียน และ drop Linux capabilities ที่ไม่จำเป็น
- ห้าม mount project source เข้า production container
- ห้าม mount `build/web` จาก host เข้า production container; static assets ต้องอยู่ใน image layer
- local Compose ต้อง build/tag image ด้วยชื่อที่ตรวจสอบได้ เช่น `startup-hr:local`
- production Compose ต้องรับค่า `IMAGE_REF` แบบบังคับ เช่น `ghcr.io/suebtas/lab3@sha256:<digest>` และห้าม fallback ไป `latest`
- image เดียวกันต้องผ่าน smoke test ก่อนอนุญาตให้ tag/publish; ห้าม rebuild ระหว่าง promotion ไป environment อื่น
- `docker compose config` ต้องผ่านก่อน build

การเลือก host port `8080` เป็นค่าเริ่มต้นยังต้องยืนยันว่าไม่ชนกับ service อื่นบนเครื่อง หากชนให้เปลี่ยนเฉพาะ `APP_PORT`

## 6. คำสั่งที่ต้องรองรับในระยะ implementation

คำสั่งต่อไปนี้ให้รันจาก root ของโปรเจกต์ เว้นแต่ระบุเป็นอย่างอื่น

ตรวจ environment; Flutter บน host เป็นทางเลือก ไม่ใช่เงื่อนไขบังคับหาก Docker พร้อมใช้งาน:

```powershell
flutter --version
flutter doctor -v
flutter pub get
```

หาก OpenCode environment ไม่มี Flutter แต่เข้าถึง Docker Engine ได้ ให้ใช้ Flutter builder image ที่ pin แล้วสร้าง Web scaffold และรัน quality gates ภายใน container ห้ามดาวน์โหลด SDK แบบไม่ pin ลงใน OpenCode container ระหว่างงาน

เพิ่ม Flutter Web scaffold เฉพาะเมื่อได้รับอนุมัติและตรวจ diff หลังคำสั่ง:

```powershell
flutter config --enable-web
flutter create --platforms web .
```

ตรวจคุณภาพและ build application:

```powershell
flutter analyze
flutter test
flutter build web --release
```

Docker-first validation ต้องรองรับอย่างน้อยสอง targets โดยชื่อจริงกำหนดใน Dockerfile/README:

```powershell
docker build --target quality -f deploy/CICD/Dockerfile -t startup-hr:quality .
docker build --target runtime -f deploy/CICD/Dockerfile -t startup-hr:local .
```

target `quality` ต้องล้มเหลวเมื่อ analyze หรือ tests ไม่ผ่าน ส่วน target `runtime` ต้องเป็น portable image ที่ไม่พึ่งไฟล์จาก host หลัง build เสร็จ

ตรวจ configuration และ build container โดยไม่กระทบ root Compose:

```powershell
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env -f deploy/CICD/docker-compose.yml config
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env -f deploy/CICD/docker-compose.yml build
```

เริ่มระบบ ตรวจสถานะ และตรวจ endpoint:

```powershell
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env -f deploy/CICD/docker-compose.yml up -d
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env -f deploy/CICD/docker-compose.yml ps
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env -f deploy/CICD/docker-compose.yml logs --no-color
Invoke-WebRequest -UseBasicParsing http://localhost:8080/healthz
```

รัน automated browser test ด้วย application และ browser service บน Compose network เดียวกัน:

```powershell
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env -f deploy/CICD/docker-compose.yml -f deploy/CICD/docker-compose.test.yml config
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env -f deploy/CICD/docker-compose.yml -f deploy/CICD/docker-compose.test.yml run --rm browser-test
```

ภายใน browser test ให้ใช้ `http://startup-hr-web:8080` เป็น target; ห้ามเปลี่ยนเป็น `localhost` ส่วนชื่อ service `browser-test` ต้องตรงกันระหว่าง Compose, README และ CI

หยุดระบบและลบเฉพาะ resources ของ Compose project นี้:

```powershell
docker compose --project-name lab3-cicd --env-file deploy/CICD/.env -f deploy/CICD/docker-compose.yml down --remove-orphans
```

ก่อนใช้คำสั่งต้องสร้าง `deploy/CICD/.env` จาก `.env.example`; ไฟล์ `.env` จริงต้องอยู่ใน `.gitignore` และห้ามมี secret สำหรับกรณี local นี้

## 7. Health check และเกณฑ์ตรวจรับ

implementation ถือว่าผ่านเมื่อครบทุกข้อ:

1. `flutter pub get`, `flutter analyze` และ test ทั้งหมดจบด้วย exit code 0
2. `flutter build web --release` สำเร็จและสร้าง `build/web/index.html`
3. `docker compose ... config` และ Docker image build สำเร็จ
4. container อยู่ในสถานะ `running` และเปลี่ยนเป็น `healthy` ภายในเวลาที่กำหนด
5. `/healthz` ตอบ HTTP 200 และ `/` ตอบ HTTP 200 ผ่าน host port ที่กำหนด
6. browser automation เปิดแอปจาก service URL ภายใน Compose network และยืนยันว่า Flutter UI render จริง โดยพบ `flt-glass-pane`, `canvas` หรือ application-ready signal ที่กำหนดไว้อย่างชัดเจน
7. browser console ไม่มี CSP violation, uncaught JavaScript error หรือ `pageerror` ที่ทำให้แอปใช้งานไม่ได้
8. application resource ไม่มี `requestfailed` และไม่มี HTTP response ตั้งแต่ 400 ขึ้นไป ยกเว้นรายการที่บันทึก allowlist พร้อมเหตุผล
9. refresh ที่ route `/payroll` หรือ route ตัวแทนของแอปไม่คืน 404 และ UI กลับมา render สำเร็จ
10. มี screenshot และ Playwright trace/report เป็นหลักฐานอย่างน้อยเมื่อ test ล้มเหลว และ CI เก็บ artifacts เหล่านี้ได้
11. root `docker-compose.yml` ยังไม่เปลี่ยนแปลง และ service เดิมสามารถใช้งานแยกจาก `lab3-cicd` ได้
12. image ไม่มี source, `.git`, local build cache, credential, browser, test dependency หรือ private key ที่ไม่จำเป็น
13. หยุดและลบ build container แล้ว runtime image ยังรันได้โดยไม่ mount `lib/`, `web/` หรือ `build/web` จาก host
14. `docker save startup-hr:local` สำเร็จ หรือมีหลักฐานเทียบเท่าว่า image export ได้
15. production Compose ผ่าน structural/config validation เมื่อกำหนด `IMAGE_REF` และไม่มี `build:` หรือ application volume

HTTP 200, container `healthy` หรือการพบ static assets เพียงอย่างเดียวไม่ใช่หลักฐานว่า UI render สำเร็จ หาก browser test ไม่ได้รันให้ข้อ 6–10 เป็น `NOT RUN`; ห้ามเปลี่ยนเป็น `PASS` จาก HTTP smoke test

## 8. ข้อกำหนด CI ด้วย GitHub Actions

เมื่อยืนยัน repository และ default branch แล้ว ให้สร้าง `.github/workflows/ci.yml` โดยมีข้อกำหนดดังนี้:

- trigger เมื่อเปิดหรืออัปเดต pull request และเมื่อ push เข้า default branch
- รองรับ manual trigger (`workflow_dispatch`) เพื่อการวิเคราะห์ปัญหาเมื่อจำเป็น
- กำหนด `permissions: contents: read` เป็นค่าเริ่มต้น
- checkout source โดยไม่ persist credential หากขั้นตอนถัดไปไม่ต้อง push
- ใช้ Flutter version เดียวกับ Docker builder; อาจรัน quality gates ผ่าน Docker target เพื่อไม่ให้ local และ CI toolchain ต่างกัน
- รัน dependency restore, `flutter analyze`, `flutter test` และ `flutter build web --release` โดยตรงหรือผ่าน Docker stages ที่ให้ผลเทียบเท่าและมี log ตรวจสอบได้
- ตรวจ Compose ทั้ง local และ production แล้ว build portable Docker image จาก `deploy/CICD/Dockerfile`
- start container แบบ detached, รอ health status แบบมี timeout และตรวจทั้ง `/healthz` กับ `/`
- รัน Playwright browser test กับ runtime image เดียวกันผ่าน Compose network โดยใช้ service URL เช่น `http://startup-hr-web:8080`; ห้ามใช้ `localhost` จาก browser container
- fail เมื่อพบ browser console error, CSP violation, uncaught `pageerror`, failed application request, unexpected HTTP 4xx/5xx หรือ UI ไม่ render ภายใน timeout
- upload screenshot, trace, report และ browser diagnostic logs ด้วยเงื่อนไข `if: failure()` หรือ `if: always()` ตามชนิด artifact
- ตรวจว่า runtime image ไม่มี source/build tools และบันทึก immutable image ID/digest เป็นหลักฐาน
- เมื่อ failure ต้องแสดง `docker compose ps`, health status และ logs โดยไม่เปิดเผย secret
- cleanup ด้วยเงื่อนไข `always()` ไม่ว่า job สำเร็จ ถูกยกเลิก หรือล้มเหลว
- ใช้ concurrency cancellation สำหรับ commit เก่าของ pull request เดียวกันเพื่อลดงานซ้ำ
- action ภายนอกทุกตัวต้อง pin อย่างน้อยด้วย commit SHA ตามนโยบายความปลอดภัยของโครงการ
- CI ของ pull request ต้องไม่พึ่ง SSH private key และต้องทำงานได้โดยใช้ read-only `GITHUB_TOKEN`

### การแยก CI และ CD

- **CI** ครอบคลุม dependency restore, analyze, tests, Flutter Web build, Docker build, HTTP smoke test และ automated browser smoke test
- **CD ระยะแรก** หมายถึงการสร้าง portable image, tag ด้วย commit SHA และเตรียม production Compose โดยยังไม่ push
- **CD ระยะ publish** ต้อง push image ที่ผ่าน CI แล้วไปยัง registry โดยไม่ rebuild พร้อมบันทึก digest และใช้ digest เดิมใน deployment
- ยังไม่อนุญาตให้ Deploy ไป production server เพราะยังไม่ได้กำหนด target environment, registry, versioning/tag policy, approval gate, rollback และผู้รับผิดชอบ
- หากเลือก GitHub Container Registry ในภายหลัง ให้ job สำหรับ publish ทำงานเฉพาะ trusted branch/tag ใช้ `packages: write`, ไม่ทำงานกับ untrusted pull request และใช้ GitHub environment approval เมื่อเหมาะสม

## 9. Secrets, credentials และ supply-chain security

- ห้าม commit `.env`, token, password, SSH private key หรือ credential ทุกชนิด
- ใช้ GitHub Actions secrets เฉพาะค่าที่เป็น secret และใช้ repository/environment variables สำหรับค่าที่ไม่ลับ
- workflow แต่ละ job ต้องได้รับ permission เท่าที่จำเป็นตามหลัก least privilege
- ห้ามส่ง secret เข้า Docker build arguments หรือบันทึกไว้ใน image layer
- dependency และ container scanning เป็นข้อเสนอสำหรับระยะถัดไป แต่ผลการตรวจที่มีระดับความรุนแรงตามเกณฑ์ของโครงการต้องสามารถหยุดการเผยแพร่ image ได้
- image ที่เผยแพร่ต้องมี tag แบบ immutable เช่น commit SHA; ห้ามพึ่ง `latest` เพียง tag เดียว

## 10. แผน SSH โดยยังไม่ดำเนินการจริง

SSH ไม่จำเป็นสำหรับ CI ของ pull request และไม่ควรถูกเพิ่มเพียงเพื่อให้ GitHub Actions checkout repository เดียวกัน

หากต้องใช้ SSH ในระยะถัดไป ให้ดำเนินการตามลำดับนี้หลังได้รับอนุญาตอย่างชัดเจน:

1. ระบุ use case ก่อนว่าเป็น Account SSH key สำหรับผู้ใช้ `git clone/pull/push` หรือ Repository Deploy key สำหรับระบบอัตโนมัติ
2. ตรวจเฉพาะรายชื่อ public-key files, key type และ fingerprint บนเครื่อง ห้ามอ่าน แสดง หรือคัดลอก private-key content
3. ตรวจสอบ key เดิมว่าเป็น key สำหรับงานนี้และยังใช้งานได้ก่อนเสนอให้ใช้ซ้ำ
4. หากไม่มี key ที่เหมาะสม ให้เสนอสร้าง Ed25519 key ชื่อเฉพาะ เช่น `id_ed25519_suebtas_lab3` โดยตรวจว่า path เป้าหมายยังไม่มีอยู่และห้ามเขียนทับ key เดิม
5. แสดงหรือส่งต่อได้เฉพาะ public key (`.pub`) หลังผู้ใช้อนุญาต
6. Account SSH key และ Deploy key ต้องไม่ถูกใช้สลับวัตถุประสงค์; Deploy key ให้สิทธิ์ read-only เว้นแต่มีเหตุผลที่อนุมัติแล้วว่าต้องเขียนได้
7. การเพิ่ม public key เข้า GitHub เป็น external state change ต้องได้รับคำยืนยันแยกต่างหาก และต้องตรวจบัญชี/repository เป้าหมายก่อนทุกครั้ง

## 11. Prerequisites และ assumptions

Prerequisites สำหรับ implementation:

- Docker Engine หรือ Docker Desktop พร้อม Docker Compose v2
- Docker CLI ต้องเข้าถึง Docker Engine ได้; หาก Agent รันใน container ต้องมี CLI/Compose plugin และได้รับ socket access ที่ผู้ใช้อนุมัติ หรือให้ผู้ใช้รันคำสั่ง Docker จาก host
- pinned Flutter builder image ที่มี Dart SDK ตรงกับ `pubspec.yaml`; Flutter SDK บน host/Agent เป็น optional
- web browser สำหรับ manual smoke test
- Git และสิทธิ์เข้าถึง `suebtas/lab3` เป็น prerequisite ของระยะ GitHub/publish เท่านั้น ไม่ใช่ local image build
- GitHub Actions เปิดใช้งานสำหรับ repository เป้าหมายก่อนเริ่มระยะ publish/CD

Assumptions ปัจจุบัน:

- แอปนี้สามารถทำงานฝั่ง client ได้โดยไม่ต้องมี backend เพิ่มเติม
- ไม่มี runtime secret ที่ต้องส่งให้ Flutter Web
- local deployment เป็นเป้าหมายแรก และยังไม่มี production environment
- `8080` เป็น port เริ่มต้นที่ยอมรับได้จนกว่าจะยืนยันค่าอื่น

หาก assumption ใดไม่จริง ต้องปรับ architecture และ threat model ก่อน implementation โดยเฉพาะกรณีที่มีข้อมูลพนักงานจริง ข้อมูลเงินเดือน authentication หรือ backend API

## 12. ความเสี่ยงและแนวทางลดความเสี่ยง

| ความเสี่ยง | แนวทางจัดการ |
| --- | --- |
| local project ไม่สัมพันธ์กับ GitHub repository | ยืนยัน Git remote และ commit ก่อนสร้าง workflow หรือ push |
| repository เป็น private, ไม่มีอยู่ หรือบัญชีไม่มีสิทธิ์ | ยืนยัน URL และ access โดยไม่เปลี่ยน GitHub state |
| ไม่มี Flutter Web scaffold | สร้างด้วย Flutter CLI หลังอนุมัติและ review diff |
| Flutter/Dart หรือ base image เปลี่ยนเวอร์ชัน | pin เวอร์ชันและ digest พร้อมกำหนดขั้นตอนอัปเดต |
| root Compose กับ app Compose ชนกัน | ใช้ไฟล์, service, port และ project name แยกกัน |
| client-side route ได้ 404 | กำหนด Nginx fallback ไป `index.html` และเพิ่ม route smoke test |
| HTTP 200 แต่ Flutter แสดงหน้าขาว | ใช้ Playwright ตรวจ UI-ready signal, screenshot, console, `pageerror`, CSP และ network แทนการอาศัย HTTP check อย่างเดียว |
| CSP บล็อก CanvasKit หรือ font | ใช้ local CanvasKit ผ่าน custom Flutter bootstrap เมื่อทำได้; หากต้องใช้ external origin ให้ allowlist เฉพาะ origin ที่พิสูจน์แล้ว ห้ามใช้ `*` หรือปิด web security |
| browser test container ทำให้ production image ใหญ่ขึ้น | แยก test service/image ออกจาก runtime image และยืนยันว่า production image ไม่มี browser หรือ Node test dependencies |
| Playwright package ไม่ตรงกับ browser image | pin `@playwright/test` และ Playwright Docker image เป็นเวอร์ชันเดียวกัน พร้อม pin image digest |
| ข้อมูลลับถูกฝังใน Flutter Web | ห้ามใส่ secret ใน build; ถือว่าค่าฝั่ง browser อ่านได้ทั้งหมด |
| workflow จาก pull request เข้าถึง secret | ไม่ให้ PR job ใช้ secret และไม่ใช้ privileged trigger โดยไม่มี security review |
| container ใช้สิทธิ์เกินจำเป็น | non-root runtime, read-only filesystem และ drop capabilities |

## 13. ค่าที่อนุมัติสำหรับ implementation รอบปัจจุบัน

ค่าต่อไปนี้ถือว่าได้รับการยืนยันแล้วและ Agent ไม่ต้องถามซ้ำ:

| รายการ | ค่าที่อนุมัติ |
| --- | --- |
| Host port | `8080` โดยเปลี่ยนผ่าน `APP_PORT` ได้ |
| Deployment target | Localhost ด้วย Docker Compose เท่านั้น |
| Runtime | Nginx แบบ unprivileged |
| Compose project | `lab3-cicd` |
| Docker image publishing | ยังไม่อนุญาต |
| Production/external deployment | ยังไม่อนุญาต |
| Portable artifact | ต้องสร้าง `startup-hr:local` ที่ export และรันบนเครื่องอื่นได้ |
| SSH | ห้ามสร้าง ตรวจ หรือใช้งานในรอบนี้ |
| Git operations | ห้าม `git init`, เพิ่ม remote, commit หรือ push ในรอบนี้ |
| GitHub Actions | อนุญาตให้สร้าง workflow file แต่ยังไม่ถือว่าผ่านจนกว่าจะรันบน GitHub จริง |
| Browser automation | อนุญาตให้สร้าง Playwright test container และ test artifacts โดยต้องแยกจาก production runtime |
| Browser test target | ใช้ `http://startup-hr-web:8080` ภายใน Compose network; host browser ใช้ `http://localhost:${APP_PORT:-8080}` |
| Browser security | ห้ามใช้ `--disable-web-security`, wildcard CSP, ignore HTTPS errors หรือ suppress console errors เพื่อทำให้ test ผ่าน |
| Application source | ห้ามแก้ `lib/` และ `test/` เพื่อทำให้ deployment หรือ tests ผ่าน |

รายการที่ยังไม่ยืนยันและต้องไม่ถูกสมมติเพื่อทำ external deployment:

1. สถานะและสิทธิ์ของ repository `https://github.com/suebtas/lab3`
2. default branch ที่แท้จริง; workflow ใช้ `main` เป็น assumption ได้และต้องรายงานไว้
3. container registry, image naming และ tag policy สำหรับการเผยแพร่
4. production platform, approval process, rollback และผู้รับผิดชอบ
5. backend API, authentication, environment-specific configuration และข้อมูลจริงที่ต้องคุ้มครอง
6. Flutter version ให้ตรวจจาก environment ที่ใช้งานจริง แล้วใช้เวอร์ชันเดียวกันใน local build, Docker builder และ CI; ห้ามแต่งเวอร์ชันหรือ digest ที่ไม่ได้ตรวจสอบ

## 14. ลำดับการดำเนินงานระยะถัดไป

ให้ดำเนินการเป็นชุดเล็กและตรวจรับได้ตามลำดับ:

1. ตรวจ Docker access และ pin Flutter/runtime builder images จากข้อมูลที่ตรวจสอบได้
2. เพิ่ม Flutter Web scaffold ผ่าน host Flutter หรือ pinned builder container
3. สร้างและตรวจ deployment files ใน `deploy/CICD/`
4. รัน quality target, build portable runtime image และ HTTP smoke test บน localhost
5. เพิ่ม Playwright browser-test service แล้วตรวจ UI render, console, page errors, failed requests และ route refresh
6. ตรวจ image contents และ portability ด้วย export test
7. สร้างหรือปรับ GitHub Actions CI ให้ใช้ browser test เดียวกับ local หลัง local browser flow ผ่านแล้ว
8. เชื่อม local project กับ Git repository ที่ถูกต้องโดยไม่เขียนทับงานเดิม หลังได้รับอนุญาตแยกต่างหาก
9. เพิ่ม image publishing หรือ external deployment เฉพาะเมื่อกำหนด CD target และ security controls ครบถ้วน
10. จัดทำหลักฐานผลทดสอบและตรวจ acceptance criteria ทุกข้อก่อนประกาศพร้อมใช้งาน

## 15. Execution contract สำหรับ Agent

หัวข้อนี้เป็นคำสั่งปฏิบัติงานสำหรับ implementation รอบปัจจุบัน เมื่อผู้ใช้สั่งให้ทำตาม `CICD.md` ใน Build mode ให้ Agent อ่านเอกสารทั้งไฟล์ แล้วดำเนินงานต่อเนื่องตามขอบเขตที่อนุมัติไว้โดยไม่หยุดเพียงการสรุปหรือถามค่าที่ได้รับการยืนยันแล้วในหัวข้อ 13

### 15.1 ไฟล์ที่อนุญาตให้สร้างหรือแก้ไข

- `.opencode/Dockerfile`, `.opencode/README.md` และ `docker-compose.override.yml` เป็น development-runner support files ที่อนุญาตเพื่อให้ OpenCode container ใช้ Docker Desktop; ไม่ใช่ production deployment artifacts
- `web/` และ `.metadata` เฉพาะส่วนที่ Flutter CLI จำเป็นต้องสร้างสำหรับ Web platform
- `deploy/CICD/Dockerfile`
- `deploy/CICD/Dockerfile.dockerignore`
- `deploy/CICD/docker-compose.yml`
- `deploy/CICD/docker-compose.test.yml`
- `deploy/CICD/docker-compose.production.yml`
- `deploy/CICD/nginx.conf`
- `deploy/CICD/browser-tests/**` สำหรับ Playwright configuration, lockfile และ tests เท่านั้น
- `web/flutter_bootstrap.js` สำหรับกำหนด Flutter loader ให้ใช้ runtime assets ที่อนุมัติ
- `deploy/CICD/.env.example`
- `deploy/CICD/.env` สำหรับ local testing โดยต้องถูก ignore
- `deploy/CICD/README.md`
- `.github/workflows/ci.yml`
- `.gitignore` เฉพาะการเพิ่ม `deploy/CICD/.env`, Playwright artifacts และ ignore ที่จำเป็นต่อ generated/build artifacts

ห้ามแก้ `docker-compose.yml` ที่ root, `lib/`, `test/` หรือ business requirements เพื่อฝืนให้ validation ผ่าน หากพบปัญหาในไฟล์เหล่านี้ให้รายงาน root cause และสถานะ `FAIL` แยกต่างหาก

### 15.2 ลำดับการทำงานบังคับ

1. ตรวจ environment และบันทึก Flutter/Dart, Docker/Compose, Git status, โครงสร้างไฟล์ และ hash ของ root `docker-compose.yml`
2. แสดง implementation plan และรายชื่อไฟล์ที่จะเปลี่ยนแบบสั้น แล้วลงมือทำต่อทันที
3. เพิ่ม Flutter Web scaffold หากยังไม่มี โดยใช้ Flutter บน host หรือ pinned Flutter builder container และตรวจไฟล์ที่ Flutter CLI เปลี่ยน
4. สร้าง deployment files, portable-image stages, local/production Compose และ CI workflow ตามหัวข้อ 3–9
5. สร้าง `deploy/CICD/.env` จาก `.env.example` สำหรับการทดสอบ และยืนยันว่า Git ignore ครอบคลุมไฟล์นี้
6. รัน quality target, runtime image build, local/production Compose validation และ HTTP smoke test ตามหัวข้อ 6–8
7. รัน Playwright browser test ตามหัวข้อ 17 กับ runtime image เดียวกัน; อ่าน console, page errors, failed requests, screenshot และ trace เมื่อไม่ผ่าน
8. แก้เฉพาะ root cause แล้วทำ build/test loop ซ้ำได้ไม่เกิน 5 รอบ ห้ามลด security control หรือ suppress error เพื่อฝืนให้ผ่าน
9. ตรวจ security, ขอบเขตไฟล์ และ hash ของ root Compose อีกครั้ง
10. ตรวจ runtime image contents แล้วทดสอบ export ด้วย `docker save` ไปยัง temporary path; ลบไฟล์ export หลังตรวจสำเร็จ
11. cleanup browser-test resources และ test deployment ด้วย `down --remove-orphans` แล้วรัน `up -d` รอบสุดท้ายจาก local Compose
12. จบงานโดยปล่อยเฉพาะ local application service ทำงานอยู่ เมื่อ container เป็น `healthy`, HTTP checks ผ่าน และ automated browser smoke test ผ่านแล้ว

Flutter SDK บน OpenCode container ไม่ใช่ prerequisite หาก Docker พร้อมและ Dockerfile มี pinned Flutter builder หาก environment ไม่มี Docker CLI หรือเข้าไม่ถึง Docker daemon ให้ทำส่วนที่ตรวจสอบได้ต่อ ห้ามเปลี่ยน host configuration โดยพลการ และต้องรายงานขั้นตอน runtime เป็น `NOT RUN` ไม่ใช่ `PASS`

### 15.3 หลักฐานและเกณฑ์การรายงาน

รายงานสุดท้ายต้องแสดง:

- ไฟล์ที่สร้างหรือแก้ไข
- Flutter/Dart และ Docker versions ที่ตรวจพบ
- Docker base images และเวอร์ชันที่ใช้
- คำสั่ง validation ที่รันและผลลัพธ์หรือ exit code สำคัญ
- จำนวน tests ที่ผ่านและล้มเหลว
- Docker build result, container state และ health status
- runtime image tag, image ID/digest, size และผลตรวจว่าไม่มี source/build tools
- ผล `docker save` หรือการตรวจ portability ที่เทียบเท่า
- ผลตรวจ local และ production Compose
- HTTP status ของ `/healthz` และ `/`
- Playwright/browser version, test target URL และผล UI-ready assertion
- browser console errors, CSP violations, uncaught page errors, failed requests และ unexpected HTTP status
- path ของ screenshot, trace และ report; artifacts ต้องไม่มี credential หรือข้อมูลลับ
- URL สำหรับเปิดแอป
- hash ก่อนและหลังของ root `docker-compose.yml`
- acceptance criteria แต่ละข้อเป็น `PASS`, `FAIL` หรือ `NOT RUN`
- งานที่ยังไม่ได้ดำเนินการและข้อจำกัดของ environment

ห้ามประกาศว่างานเสร็จสมบูรณ์หาก analyze/tests ล้มเหลว, Docker image build ไม่ผ่าน, container ไม่ healthy, HTTP checks ไม่ได้ 200, browser test ไม่ผ่าน หรือไม่มีหลักฐานรองรับ หาก browser automation รันไม่ได้ให้รายงานข้อ browser เป็น `NOT RUN` และ terminal state ยังไม่สำเร็จ

### 15.4 Terminal state ของรอบนี้

รอบ implementation นี้ถือว่าสำเร็จเมื่อ portable runtime image ผ่าน quality gates, image inspection, export test, HTTP checks และ automated browser acceptance criteria พร้อมทำงานที่ `http://localhost:8080` รวมทั้งมี local Compose, browser-test Compose, production Compose และ CI workflow ที่ตรวจสอบแล้ว การ push repository, publish image, GitHub Actions run และ external production deployment เป็นงานระยะถัดไปและต้องได้รับอนุญาตแยกต่างหาก

## 16. Portable image promotion และ Production Deployment

Docker image ที่ผ่าน CI เป็น release candidate เพียง artifact เดียว ห้าม rebuild เมื่อ promote ไป environment อื่น

### 16.1 Image identity และ tags

- local validation ใช้ `startup-hr:local`
- เมื่อเชื่อม Git แล้ว release candidate ใช้ tag แบบ immutable เช่น `ghcr.io/suebtas/lab3:<full-commit-sha>`
- tag ที่มนุษย์อ่านง่าย เช่น semantic version เป็น alias เพิ่มเติมได้ แต่ deployment record ต้องเก็บ digest เสมอ
- ห้ามใช้ `latest` เป็น deployment reference

### 16.2 การส่งมอบ

- registry path: CI push image ที่ผ่าน smoke test แล้ว จากนั้นบันทึก registry digest
- offline path: `docker save` เป็น archive และใช้ `docker load` ที่เครื่องเป้าหมาย พร้อม checksum ของ archive
- production Compose รับ `IMAGE_REF` จาก environment และต้องทำงานกับ tag หรือ digest โดยไม่ต้องมี source หรือ Flutter SDK

### 16.3 Promotion และ rollback

1. build image ครั้งเดียว
2. รัน quality gates, vulnerability policy และ smoke tests กับ image นั้น
3. publish โดยไม่ rebuild
4. deploy ด้วย digest ที่บันทึกไว้
5. ตรวจ health/readiness หลัง deploy
6. rollback ด้วย digest ก่อนหน้าเมื่อ health check หรือ post-deploy smoke test ล้มเหลว

### 16.4 ขอบเขตรอบปัจจุบัน

รอบนี้อนุญาตให้สร้างและพิสูจน์ portable image, production Compose และ CI configuration เท่านั้น ยังห้าม login registry, push image, สร้าง release, แก้ GitHub หรือ deploy ไป external environment จนกว่าจะได้รับอนุญาตแยกต่างหาก

## 17. Automated Browser Validation และ Debug Loop

### 17.1 สถาปัตยกรรม browser test

- ใช้ Playwright/Chromium ใน test container แยกจาก OpenCode container และ production runtime image
- browser-test service ต้องอยู่ Compose network เดียวกับ `startup-hr-web` และเรียก `http://startup-hr-web:8080`; `localhost` ภายใน browser container หมายถึง browser container เองและห้ามใช้เป็น application target
- host browser ยังคงเปิดแอปด้วย `http://localhost:${APP_PORT:-8080}`
- ใช้ official Playwright image ที่ pin เวอร์ชันและ immutable digest; เวอร์ชัน `@playwright/test` ใน lockfile ต้องตรงกับ image
- ห้ามใช้ tag `latest`, `npx -y` แบบไม่ pin หรือดาวน์โหลด browser ใหม่ทุกครั้งระหว่าง test
- browser-test service ต้องใช้ `init: true`, กำหนด shared memory/IPC ที่เหมาะสม, มี timeout และถูก cleanup หลัง test
- ห้าม mount Docker socket, credential, SSH key หรือ application source ที่ไม่จำเป็นเข้า browser-test container
- browser/test dependencies ห้ามปรากฏใน `startup-hr:local` และ production Compose ห้ามมี browser-test service
- test output เขียนได้เฉพาะ directory artifacts ที่กำหนด เช่น `deploy/CICD/browser-tests/test-results/` และ `playwright-report/`; directory เหล่านี้ต้องถูก Git ignore

### 17.2 Browser acceptance test ขั้นต่ำ

Browser test ต้องลงทะเบียน event listeners ก่อน `page.goto()` และตรวจอย่างน้อยดังนี้:

1. `/healthz` ตอบ HTTP 200 และ body เป็น `ok`
2. เปิด `/` ด้วย browser context ใหม่ที่ไม่มี cache/service worker state จากรอบก่อน
3. รอ application-ready signal แบบมี timeout เช่น element `flt-glass-pane`, visible `canvas` หรือ signal เฉพาะแอปที่มีความหมายเทียบเท่า
4. fail เมื่อพบ console message ระดับ error, CSP violation, uncaught `pageerror` หรือ unhandled promise rejection
5. fail เมื่อ application request เกิด `requestfailed` หรือ response ตั้งแต่ 400 ขึ้นไป ยกเว้น allowlist ที่ระบุ URL pattern และเหตุผลไว้ใน test อย่างชัดเจน
6. ยืนยันว่า `flutter_bootstrap.js`, `main.dart.js`, renderer assets และ font ที่จำเป็นโหลดสำเร็จ
7. เปิดหรือ navigate ไป `/payroll`, reload หน้า และยืนยันว่าไม่เป็น 404 พร้อมกลับมา render ได้
8. บันทึก screenshot หลัง UI พร้อม และบันทึก screenshot เพิ่มเมื่อ failure
9. เปิด Playwright trace อย่างน้อยแบบ retain-on-failure และสร้าง machine-readable result กับ HTML report
10. test ต้องคืน non-zero exit code เมื่อข้อใดข้อหนึ่งไม่ผ่าน ห้ามเพียงเขียน warning แล้วจบด้วย success

การตรวจว่า HTTP 200 หรือไฟล์ JavaScript มีอยู่ไม่สามารถทดแทนข้อ 3–7 ได้

### 17.3 หลักการแก้ปัญหา browser runtime

- `nginx -t` พิสูจน์เฉพาะ syntax/configuration loading ไม่ได้พิสูจน์ว่า Flutter render สำเร็จ
- เมื่อ browser test ล้มเหลว ให้ตรวจหลักฐานตามลำดับ: console/CSP, `pageerror`, failed request/response, screenshot, trace, Nginx access/error log และ container health
- สำหรับ CanvasKit ให้ใช้ asset ภายใน image ผ่าน custom `web/flutter_bootstrap.js` และ `canvasKitBaseUrl` เมื่อทำได้ เพื่อรักษาความเป็น portable; หากจำเป็นต้องใช้ CDN ให้ allowlist เฉพาะ scheme/host ที่พิสูจน์แล้ว
- font ที่จำเป็นควรถูก bundle เป็น Flutter asset พร้อม license เมื่อได้รับอนุญาตให้เพิ่ม asset; หากยังใช้ external font ให้ allowlist เฉพาะ origin ที่จำเป็นใน `connect-src` และ `font-src`
- CSP ต้องใช้ least privilege ห้าม wildcard `*`, ห้ามเพิ่ม `'unsafe-eval'` เมื่อ `'wasm-unsafe-eval'` เพียงพอ และห้ามปิด CSP เพื่อทำให้ test ผ่าน
- ห้ามใช้ `--disable-web-security`, `ignoreHTTPSErrors`, request interception เพื่อซ่อน failure หรือการ suppress console/page errors
- การแก้แต่ละรอบต้องเริ่มจาก root cause ที่มีหลักฐาน แล้ว rebuild/recreate และรัน test ใหม่ทั้งหมด; ทำซ้ำได้ไม่เกิน 5 รอบก่อนรายงาน `FAIL` พร้อม blocker
- stale browser cache/service worker ต้องถูกตัดออกจาก automated test ด้วย fresh browser context; manual verification ให้ unregister service worker และ clear site data ก่อนสรุปผล

### 17.4 การใช้ใน CI

- CI ต้องใช้ browser test files และ Compose overlay ชุดเดียวกับ local เพื่อป้องกัน test drift
- start application ก่อน รอ Docker health เป็น `healthy` แล้วจึง start browser-test service
- browser-test container failure ต้องทำให้ CI job ล้มเหลว
- เก็บ Playwright HTML report, trace, screenshot, console/network diagnostics และ Docker logs เมื่อ failure โดย artifacts ต้องไม่มี secret
- cleanup browser และ application resources ด้วย `if: always()`
- GitHub Actions ที่ใช้ upload artifacts หรือ setup เพิ่มเติมต้อง pin ด้วย commit SHA

### 17.5 สถานะการตรวจรับ

- `PASS` ได้เมื่อ browser test รันจริงและ assertions ผ่านทั้งหมด
- `FAIL` เมื่อ browser เปิดได้แต่ UI ไม่ render, มี CSP/console/page/network error หรือ route refresh ล้มเหลว
- `NOT RUN` เมื่อไม่มี browser engine, image pull ไม่ได้ หรือ environment ไม่อนุญาตให้รัน test; `NOT RUN` ไม่ถือว่า terminal state สำเร็จ
- manual browser smoke test ใช้เป็นหลักฐานเสริมได้ แต่ไม่ทดแทน automated browser gate หลังจาก browser-test harness ถูกสร้างแล้ว

## 18. Standard Prompt สำหรับ OpenCode

ให้ใช้ Prompt ต่อไปนี้เป็นคำสั่งมาตรฐานสำหรับ implementation และ browser-debug session เพื่อลดคำสั่งยาวซ้ำซ้อน โดย `CICD.md` ฉบับใน workspace เป็น source of truth สูงสุด:

```text
ดำเนินการตาม CICD.md ฉบับปัจจุบันในโหมด implementation + automated browser validation

ให้อ่าน CICD.md ทั้งไฟล์ก่อนลงมือ และปฏิบัติตาม execution contract, allowed files, security controls, acceptance criteria และ terminal state โดยเคร่งครัด

ตรวจ environment และ root docker-compose.yml hash ก่อน จากนั้นดำเนินการต่อเองตามลำดับบังคับโดยไม่หยุดถามในเรื่องที่ CICD.md อนุมัติไว้แล้ว ใช้ Docker Desktop ผ่าน Docker socket ที่มีอยู่ ห้ามเปลี่ยน host configuration

ต้องรัน quality gates, portable runtime build, Compose validation, health/HTTP checks และ Playwright browser-debug loop จริง Browser test ต้องตรวจ UI render, console, CSP, page errors, failed requests, route refresh และเก็บ screenshot/trace/report ห้ามรายงาน PASS จาก HTTP 200 เพียงอย่างเดียว

เมื่อพบ failure ให้แก้เฉพาะ root cause ภายใน allowed files แล้ว rebuild/retest ได้ไม่เกิน 5 รอบ ห้ามลด security, ใช้ wildcard CSP, disable web security, suppress errors หรือแก้ business logic/tests เพื่อฝืนให้ผ่าน

ห้าม Git init/commit/push, SSH, GitHub mutation, registry login/push, image publish หรือ external deployment เว้นแต่ได้รับอนุญาตในคำสั่งแยกต่างหาก

จบงานโดยปล่อยเฉพาะ application service ทำงานอยู่เมื่อ terminal state ผ่านครบ หากไม่ผ่านให้ cleanup test resources และรายงาน blocker ตามหลักฐานจริง

รายงานไฟล์ที่เปลี่ยน, commands/exit codes, test counts, image identity/size, container security/health, HTTP results, browser results/errors, artifact paths, root Compose hash ก่อน/หลัง และทุก acceptance criterion เป็น PASS/FAIL/NOT RUN
```

หาก session ต้องทำเฉพาะการตรวจโดยไม่แก้ไฟล์ ให้เพิ่มบรรทัดแรกว่า `โหมด review-only: ห้ามแก้ไฟล์และห้ามเปลี่ยน runtime state` หากต้องการอนุญาต Git, publish หรือ external deployment ต้องใช้ Prompt แยกและระบุ target, credential mechanism, approval gate และ rollback policy อย่างชัดเจน; ห้ามตีความ Standard Prompt นี้ว่าอนุญาตงานดังกล่าว
