# Startup HR — Product, Architecture and CI/CD Guide

เอกสารนี้อธิบายโครงการ `startup_hr` ตั้งแต่เป้าหมายผลิตภัณฑ์ โครงสร้างแอป
Flutter Web การทดสอบ การสร้าง immutable container image ไปจนถึงการส่งมอบ
ผ่าน GitHub Actions และ GitHub Container Registry (GHCR) ส่วน Persona,
User Flow และ Wireframe เดิมยังคงอยู่ในส่วนถัดไปในฐานะข้อมูลออกแบบผลิตภัณฑ์

> สถานะ As-built ตรวจสอบล่าสุดวันที่ 3 ตุลาคม 2026 — ขอบเขตที่เสร็จแล้วคือ
> Flutter Web → Docker/Nginx → CI quality gates → browser acceptance test →
> GHCR publish → production Compose บน localhost ส่วนการ rollout ไป server
> ภายนอกยังไม่ได้กำหนด target และไม่รวมอยู่ในสถานะนี้

## 1. สถานะระบบที่ยืนยันแล้ว

| รายการ | ค่าที่ตรวจสอบแล้ว |
| --- | --- |
| Repository | `https://github.com/suebtas/lab3` |
| Branch | `main` |
| Verified application/deployment baseline | `68cb8cf0473f603b754b538f73702898d0342c63` |
| GitHub Actions run | [CI and Delivery #37081138732](https://github.com/suebtas/lab3/actions/runs/37081138732) — `success` |
| CI tests | Flutter analyze ผ่าน, Flutter tests `14/14`, Playwright `1/1` |
| Registry | `ghcr.io/suebtas/lab3` |
| Immutable production image | `ghcr.io/suebtas/lab3@sha256:db6d944bfe702ec016623acd7420db2b14b8cf896d9402c0998772c75dc856c3` |
| Runtime | Nginx 1.27.5 แบบ unprivileged บน port `8080` |
| Runtime validation | container `healthy`, `/healthz` และ `/` ตอบ HTTP 200, browser UI render ผ่าน |
| Root OpenCode Compose hash | `959C3398B4CD7900CB8FBAFEAC4E9B76639C60A795DA3124F40B45C6C73014A6` |

ค่า baseline ข้างต้นเป็นหลักฐานของ release ที่ผ่านการตรวจรับแล้ว แม้ภายหลังจะมี
documentation-only commit หรือ release ใหม่ ค่า digest นี้ยังคงใช้ rollback หรือ
ตรวจสอบย้อนหลังได้ ห้ามอ้างอิง tag `main` เป็น production pin เพราะ tag ดังกล่าว
เปลี่ยนตาม release ล่าสุด

## 2. ขอบเขตผลิตภัณฑ์ปัจจุบัน

แอปเป็น Flutter Web สำหรับสาธิตงาน HR และ Payroll ประกอบด้วย:

- เพิ่มพนักงานประจำ เด็กฝึกงาน และผู้จัดการ
- คำนวณโบนัส ภาษีหัก ณ ที่จ่าย และยอดรับสุทธิ
- ค้นหาและกรองผลประเมินเงินเดือนตามประเภทพนักงาน
- กรองพนักงานตามแผนกและแสดงคำแนะนำการพัฒนาบุคลากร
- แสดงภาพรวมค่าใช้จ่ายและสถานะอนุมัติสำหรับผู้บริหาร
- รองรับ client-side route `/payroll` ผ่าน Nginx fallback

ข้อจำกัดที่ต้องเข้าใจให้ตรงกัน:

- ข้อมูลอยู่ใน `EmployeeStore` แบบ in-memory และเริ่มจาก seed data; refresh หรือ
  restart แอปแล้วข้อมูลที่เพิ่มใหม่จะไม่คงอยู่
- ยังไม่มี backend API, database, authentication หรือ role-based access control
- ปุ่ม export/print แสดงผลตอบรับผ่าน `SnackBar`; ยังไม่สร้าง PDF หรือส่งงานพิมพ์จริง
- การอนุมัติ payroll เป็นสถานะใน UI เท่านั้น ไม่เชื่อมระบบธนาคาร การจ่ายเงินจริง
  audit log หรือ approval workflow ฝั่ง server
- ไม่มีข้อมูลลับที่ควรฝังใน Flutter Web เพราะ asset และ JavaScript ฝั่ง browser
  สามารถถูกผู้ใช้ดาวน์โหลดและตรวจดูได้

## 3. โครงสร้างซอฟต์แวร์

```text
lib/
├── core/                  # utility เช่นการจัดรูปแบบจำนวนเงิน
├── data/                  # EmployeeStore และ seed data แบบ in-memory
├── domain/
│   ├── models/            # Employee, EmployeeType และ Department
│   ├── payroll_engine.dart
│   ├── payroll_summary_entity.dart
│   └── recommendation_service.dart
├── screens/               # หน้าจอหลักทั้งห้าหน้าจอ
└── main.dart

test/                      # domain และ widget tests
web/                       # Flutter Web bootstrap/manifest/icons
assets/fonts/              # local fonts พร้อม license
deploy/CICD/               # Docker, Nginx, Compose และ browser tests
.github/workflows/ci.yml   # CI และ delivery workflow
```

`docker-compose.yml` ที่ root เป็น development environment สำหรับ OpenCode
ไม่ใช่ deployment definition ของเว็บแอป การรันเว็บต้องใช้ Compose ใต้
`deploy/CICD/` เท่านั้น

## 4. Toolchain และ Runtime Architecture

- Flutter builder: Flutter 3.44.0 / Dart 3.12.0 จาก image ที่ pin ด้วย digest
- Quality stage: `flutter pub get`, `flutter analyze`, `flutter test`
- Builder stage: `flutter build web --release`
- Runtime stage: Nginx 1.27.5 unprivileged; ไม่มี Flutter SDK, source code,
  compiler หรือ browser test dependencies
- Browser acceptance: Playwright 1.49.0/Chromium ใน test container แยกต่างหาก
- Fonts และ CanvasKit โหลดจาก image เดียวกันภายใต้ strict same-origin CSP

Production container ใช้ non-root user, read-only root filesystem,
`no-new-privileges`, drop Linux capabilities และเปิด writable `tmpfs` เฉพาะ
path ที่ Nginx จำเป็นต้องใช้

## 5. กระบวนการ CI/CD ตั้งแต่ต้นจนจบ

```text
Pull request / manual dispatch
  → Compose validation
  → Flutter analyze + tests
  → Build portable runtime image
  → Verify OCI labels and image contents
  → Start container and wait for healthy
  → HTTP smoke tests
  → Playwright browser acceptance test
  → PASS/FAIL (ไม่มีการ publish จาก PR หรือ manual dispatch)

Approved push to main
  → gates ทั้งหมดข้างต้น
  → docker save image ที่ผ่าน test พร้อม SHA-256 checksum
  → upload runtime artifact อายุ 1 วัน
  → publish job ดาวน์โหลดและตรวจ checksum/revision
  → login GHCR ด้วย repository-scoped GITHUB_TOKEN
  → push <full-commit-sha> และ main โดยไม่ rebuild
  → บันทึก immutable registry digest ใน job summary
  → production Compose pull และ run ด้วย digest
  → post-deploy health, HTTP และ browser validation
```

หลักสำคัญคือ build once, test once และ promote image เดิม ห้าม rebuild ใน publish
job เพราะผลลัพธ์ใหม่อาจไม่ตรงกับ artifact ที่ผ่านการทดสอบ Pull request ใช้สิทธิ์
`contents: read`; เฉพาะ publish job ของ trusted `main` push เท่านั้นที่ได้รับ
`packages: write` และไม่มี SSH private key, PAT หรือ registry password ใน repository

## 6. รัน Production Image บน Windows

รันคำสั่งจาก root ของ repository ด้วย PowerShell:

```powershell
cd D:\data\project\lab3

$env:IMAGE_REF = "ghcr.io/suebtas/lab3@sha256:db6d944bfe702ec016623acd7420db2b14b8cf896d9402c0998772c75dc856c3"

docker compose `
  --project-name lab3-cicd `
  --env-file deploy/CICD/.env.example `
  -f deploy/CICD/docker-compose.production.yml `
  pull

docker compose `
  --project-name lab3-cicd `
  --env-file deploy/CICD/.env.example `
  -f deploy/CICD/docker-compose.production.yml `
  up -d
```

เปิดเว็บที่ `http://localhost:8080` หาก port ชนกับบริการอื่นให้กำหนด
`$env:APP_PORT = "8081"` ก่อน `up -d` แล้วเปิด `http://localhost:8081`

ตรวจสถานะและ logs:

```powershell
docker compose `
  --project-name lab3-cicd `
  --env-file deploy/CICD/.env.example `
  -f deploy/CICD/docker-compose.production.yml `
  ps

Invoke-WebRequest -UseBasicParsing http://localhost:8080/healthz
Invoke-WebRequest -UseBasicParsing http://localhost:8080/

docker compose `
  --project-name lab3-cicd `
  --env-file deploy/CICD/.env.example `
  -f deploy/CICD/docker-compose.production.yml `
  logs --no-color
```

หยุดเฉพาะ production Compose project นี้:

```powershell
docker compose `
  --project-name lab3-cicd `
  --env-file deploy/CICD/.env.example `
  -f deploy/CICD/docker-compose.production.yml `
  down --remove-orphans

Remove-Item Env:IMAGE_REF
Remove-Item Env:APP_PORT -ErrorAction SilentlyContinue
```

## 7. Rollback

Rollback ใช้วิธีตั้ง `IMAGE_REF` กลับไปยัง digest ก่อนหน้าที่ผ่าน CI แล้ว จากนั้น
สั่ง `up -d` และตรวจ health/HTTP/browser ซ้ำ ห้าม rollback ด้วย tag `main`
เพราะเป็น moving alias ตัวอย่าง rollback ไป verified baseline:

```powershell
$env:IMAGE_REF = "ghcr.io/suebtas/lab3@sha256:db6d944bfe702ec016623acd7420db2b14b8cf896d9402c0998772c75dc856c3"

docker compose `
  --project-name lab3-cicd `
  --env-file deploy/CICD/.env.example `
  -f deploy/CICD/docker-compose.production.yml `
  up -d --force-recreate
```

## 8. เกณฑ์ตรวจรับและหลักฐาน

release ถือว่าพร้อมใช้งานเมื่อทุกข้อเป็น `PASS`:

1. Flutter analyze และ tests ผ่าน
2. runtime image build สำเร็จและ OCI revision ตรงกับ Git commit
3. image ไม่มี source, Flutter SDK หรือ build tools
4. local และ production Compose config ผ่าน
5. container เปลี่ยนเป็น `healthy` ภายใน timeout
6. `/healthz` และ `/` ตอบ HTTP 200
7. Playwright ยืนยันว่า Flutter UI render, route refresh ทำงาน และไม่มี console,
   CSP, page หรือ network error ที่ไม่ได้ allowlist
8. publish job ใช้ image artifact เดิม ตรวจ checksum แล้ว และไม่ rebuild
9. GHCR commit tag กับ `main` alias ชี้ digest เดียวกัน
10. production Compose รันด้วย digest และ post-deploy checks ผ่าน

Playwright report, screenshot และ trace เก็บเป็น GitHub Actions artifact 7 วัน
ส่วน runtime transfer artifact เก็บ 1 วัน ตัว registry image digest เป็น release
identity ระยะยาวและควรถูกบันทึกใน release/deployment record

## 9. งานที่ยังอยู่นอกขอบเขต

- external server/cloud deployment และ network/DNS/TLS ของ environment จริง
- backend persistence, authentication, authorization และ audit log
- vulnerability scanning gate, SBOM, image signing และ provenance verification
- automated environment approval และ automated rollback
- database backup/restore และ disaster recovery

รายละเอียดข้อกำหนด การควบคุมความปลอดภัย และคำสั่งสำหรับ Agent อยู่ใน
[`CICD.md`](CICD.md) ส่วนคู่มือ Docker โดยย่ออยู่ใน
[`deploy/CICD/README.md`](deploy/CICD/README.md)

---

# Personas & Application Flow

ส่วนนี้บันทึกผลการวิเคราะห์ Storyline ของบริษัท Tech Startup จากคู่มือ
"Startup HR - ระบบจัดการพนักงาน" เป็น **User Persona** และ **User Flow**
ซึ่งถูกนำไปพัฒนาเป็น Flutter UI แล้ว รายละเอียดในส่วน Wireframe จึงทำหน้าที่
เป็น design rationale และ reference สำหรับตรวจความสอดคล้องกับ implementation
ไม่ใช่รายการความสามารถที่ยืนยันว่ามี backend หรือ production integration แล้ว

## **👥 1\. User Personas (กำหนดกลุ่มผู้ใช้เป้าหมาย)**

จากการวิเคราะห์ความต้องการใน Storyline พบกลุ่มผู้ใช้งานหลัก 2 กลุ่มที่มีส่วนเกี่ยวข้องกับระบบนี้โดยตรง:

### **Persona 1: เจ้าหน้าที่ฝ่ายทรัพยากรบุคคล (HR Officer)**

**"ต้องการระบบที่บันทึกข้อมูลได้ยืดหยุ่น และคำนวณผลลัพธ์สิ้นเดือนได้อัตโนมัติเพื่อลดภาระงานแมนนวล"**

* **ชื่อสมมติ:** คุณมินท์ (HR ฝ่ายสรรหาและดูแลบุคลากร)  
* **บทบาทในระบบ:** ผู้ใช้งานหลัก (Primary User) ที่ทำหน้าที่ป้อนข้อมูลและจัดการรายชื่อพนักงาน  
* **เป้าหมาย (Goals):**  
  * บันทึกโปรไฟล์พนักงานใหม่ได้อย่างรวดเร็ว โดยระบบต้องรองรับกรณีข้อมูลไม่ครบถ้วน (เช่น พนักงานยังไม่ระบุชื่อเล่นหรือเบอร์โทรสำรอง) โดยที่แอปพลิเคชันไม่แครช.  
  * ลดเวลาในการตรวจเช็กและคำนวณเงินโบนัสกับภาษีหัก ณ ที่จ่ายของพนักงานแต่ละคนในสิ้นเดือน.  
  * จัดหมวดหมู่พนักงานตามแผนก (IT, HR, Design) เพื่อส่งเข้ารับการอบรมตามนโยบายบริษัทได้อย่างถูกต้อง.  
* **ปัญหาที่พบ (Pain Points):** ปวดหัวกับการตรวจข้อมูลด้วยมือเมื่อบริษัทเติบโตขึ้นอย่างรวดเร็ว และเจอปัญหาพิมพ์ชื่อคีย์ข้อมูลผิดพลาดบ่อยครั้งจนระบบพัง (ในระบบจัดการแบบเก่า).

### **Persona 2: ผู้บริหารระดับสูง (CEO / Founder)**

**"ต้องการโครงสร้างข้อมูลที่เป็นมาตรฐาน และรายงานสรุปยอดค่าใช้จ่ายที่ชัดเจนเพื่อการตัดสินใจทางธุรกิจ"**

* **ชื่อสมมติ:** คุณเตชินท์ (CEO ของ Tech Startup)  
* **บทบาทในระบบ:** ผู้ตรวจสอบและติดตามภาพรวม (Viewer / Decision Maker)  
* **เป้าหมาย (Goals):**  
  * ควบคุมให้ระบบจัดเก็บข้อมูลพนักงานมีมาตรฐานเดียวกัน ไม่เกิดข้อผิดพลาดในการพิมพ์คีย์ข้อมูล.  
  * ดูรายงานสรุปยอดรวมรายจ่ายค่าเงินเดือนบวกโบนัสทั้งหมดของบริษัทในแต่ละเดือนเพื่อบริหารกระแสเงินสด.  
* **ปัญหาที่พบ (Pain Points):** โค้ดระบบเดิมเริ่มยาวและซับซ้อนเกินไป ส่งผลให้หน้าจอ UI รกและปรับปรุงยากในอนาคต.

## **🔄 2\. User Flows (ขั้นตอนการทำงานของระบบ)**

เพื่อให้เห็นภาพการทำงานร่วมกันระหว่างผู้ใช้และระบบ ผมได้แบ่ง User Flow ออกเป็น 4 ฟังก์ชันหลักตามขั้นตอนการเติบโตของระบบดังนี้ครับ:

### **Flow 1: การเพิ่มพนักงานใหม่เข้าสู่ระบบ (Employee Onboarding)**

*ผู้ใช้งาน: HR Officer*

```

[เริ่มต้น] 
   └──> HR เข้าสู่เมนู "เพิ่มพนักงานใหม่"
   └──> เลือกประเภทพนักงาน (พนักงานประจำ / เด็กฝึกงาน / ผู้จัดการ)
   └──> กรอกข้อมูลพื้นฐาน (ชื่อ, นามสกุล, อายุ, แผนก)
   └──> กรอกข้อมูลเพิ่มเติม (เงินเดือนเริ่มต้น, ทักษะ, ช่องทางติดต่อ)
   └──> ตรวจสอบข้อมูล Null Safety (ชื่อเล่น/เบอร์สำรอง) 
         ├── มีข้อมูล ──> บันทึกตามจริง
         └── ไม่มีข้อมูล ──> เก็บเป็น nullable และใช้ข้อความ fallback เมื่อแสดงผล
   └──> ระบบใช้ Blueprint (Class) บันทึกเข้า EmployeeStore แบบ in-memory อย่างเป็นมาตรฐาน
[จบขั้นตอน]

```

### **Flow 2: การประมวลผลสิ้นเดือนและคำนวณอัตโนมัติ (End-of-Month Payroll Evaluation)**

*ผู้ใช้งาน: HR Officer & ระบบอัตโนมัติ*

```

[เริ่มต้น]
   └──> HR เข้าสู่เมนู "ประเมินผลสิ้นเดือน"
   └──> ระบบดึงรายชื่อพนักงานทั้งหมดจาก EmployeeStore มาประมวลผล
   └──> ระบบคำนวณ "โบนัสประจำเดือน" อัตโนมัติ:
         ├── เงินเดือน <= 30,000 บาท ──> คำนวณโบนัส 10%
         └── เงินเดือน > 30,000 บาท  ──> คำนวณโบนัส 5%
   └──> ระบบคำนวณ "ภาษีหัก ณ ที่จ่าย" อัตโนมัติ:
         ├── เป็นเด็กฝึกงาน (Intern) ──> หักภาษีพิเศษ 1% (ฐานเงินเดือนคงที่ 10,000 บาท)
         └── เป็นพนักงานประจำ/ผู้จัดการ ──> หักภาษีมาตรฐาน 3%
   └──> ระบบคำนวณยอดรับสุทธิ = เงินเดือน + โบนัส - ภาษี
   └──> คำนวณและแสดงผลรายงานในหน่วยความจำ (ยังไม่มี database persistence)
[จบขั้นตอน]

```

### **Flow 3: การคัดกรองตามแผนกและแนะนำการพัฒนาบุคลากร (Department Filters & Recommendations)**

*ผู้ใช้งาน: HR Officer*

```

[เริ่มต้น]
   └──> HR เลือกดูรายชื่อทั้งหมดหรือกรองตามแผนก IT, HR, Design และอื่นๆ
   └──> RecommendationService ใช้ Switch-Case เพื่อแสดงคำแนะนำจำเพาะ:
         ├── แผนก IT     ──> แสดงคำแนะนำ: "ส่งเข้ารับการอบรม Cybersecurity"
         ├── แผนก HR     ──> แสดงคำแนะนำ: "ส่งเข้าร่วมสัมมนาการสรรหาบุคลากรยุคใหม่"
         ├── แผนก Design ──> แสดงคำแนะนำ: "ส่งเข้าเวิร์กชอป UI/UX Trend"
         └── แผนกอื่นๆ   ──> แสดงคำแนะนำ: "ปฐมนิเทศพนักงานทั่วไป"
   └──> HR กดปุ่มพิมพ์รายงานเพื่อดูผลตอบรับใน UI (ยังไม่เชื่อม PDF/เครื่องพิมพ์จริง)
[จบขั้นตอน]

```

### **Flow 4: การสรุปภาพรวมรายจ่ายสำหรับผู้บริหาร (Executive Financial Overview)**

*ผู้ใช้งาน: CEO / Management*

```

[เริ่มต้น]
   └──> CEO เข้าสู่ระบบผ่านหน้า Dashboard สำหรับผู้บริหาร
   └──> ระบบคำนวณ PayrollSummaryEntity จาก EmployeeStore แล้วแสดงผลทันที
   └──> แสดงผลข้อมูลสำคัญบนหน้าจอ:
         1. จำนวนพนักงานทั้งหมดใน store ปัจจุบัน
         2. ยอดรวมรายจ่ายทั้งหมด (เงินเดือนรวม + โบนัสรวม)
   └──> CEO ใช้ข้อมูลนี้ตรวจสอบงบประมาณและทดลองอนุมัติใน UI
         (ยังไม่เชื่อมระบบจ่ายเงินจริงหรือ approval backend)
[จบขั้นตอน]

```

**หมายเหตุ As-built:** โครงสร้าง Dart ใช้ inheritance รองรับข้อมูลเฉพาะ เช่น
`teamSize` ของผู้จัดการ และผูกข้อมูลกับ Flutter UI แล้วผ่าน `EmployeeStore`
และ `ListView.builder` อย่างไรก็ตาม store ปัจจุบันอยู่ในหน่วยความจำ ไม่ใช่
backend หรือฐานข้อมูลถาวร ส่วนสลิปเงินเดือน การพิมพ์ และการส่งข้อมูลไปยัง
ระบบภายนอกยังเป็นงานระยะถัดไป

# Wireframe

# **เอกสารการออกแบบ UI/UX และสถาปัตยกรรม Flutter Widget (HR & Payroll Management System)**

## **\[PART 1\] หน้าจอ: เพิ่มพนักงานใหม่ (Employee Onboarding Screen) สำหรับ HR Officer**

### **1.1 Wireframe Layout Breakdown (โครงร่างหน้าจอจากบนลงล่าง)**

เพื่อการใช้งานที่ลื่นไหลสำหรับ HR Officer ที่ต้องกรอกข้อมูลจำนวนมาก เราจึงออกแบบด้วยสไตล์ **Scrollable Form with Sticky Bottom Button** โดยแบ่งโครงร่างของหน้าจอออกเป็น 5 ส่วนหลัก ดังนี้:

```
+-----------------------------------------------------------+
| [ <- ]             เพิ่มพนักงานใหม่ (Title)                |  <- 1. Top Navigation Bar
+-----------------------------------------------------------+
| [ PROGRESS BAR: ขั้นตอนที่ 1 จาก 1 (กรอกข้อมูลครบถ้วน) ]    |  <- 2. Progress Indicator
+-----------------------------------------------------------+
|                                                           |
|  +-----------------------------------------------------+  |
|  | [Icon] เลือกประเภทพนักงาน (Segmented Button)        |  |  <- 3. Section 1: Employment Type
|  | ( ) พนักงานประจำ    ( ) เด็กฝึกงาน    ( ) ผู้จัดการ   |  |
|  +-----------------------------------------------------+  |
|                                                           |
|  +-----------------------------------------------------+  |
|  | [Icon] ข้อมูลพื้นฐาน (Basic Info Card)              |  |  <- 4. Section 2: Basic Information
|  | - ชื่อจริง * - นามสกุล * |  |     (Scrollable Content Area)
|  | - อายุ * - แผนก (Dropdown) * |  |
|  | - ชื่อเล่น (Optional)                                |  |
|  +-----------------------------------------------------+  |
|                                                           |
|  +-----------------------------------------------------+  |
|  | [Icon] ข้อมูลเพิ่มเติม (Additional Info Card)         |  |  <- 5. Section 3: Professional & Contact
|  | - เงินเดือนเริ่มต้น * |  |
|  | - ทักษะ (Chips/Tags Input)                            |  |
|  | - ช่องทางติดต่อ / เบอร์โทรหลัก * |  |
|  | - เบอร์โทรสำรอง (Optional)                           |  |
|  +-----------------------------------------------------+  |
|                                                           |
+-----------------------------------------------------------+
|                  [ ปุ่มบันทึกข้อมูล (Save) ]               |  <- 6. Bottom Sticky Action Area
+-----------------------------------------------------------+
```

### **รายละเอียดโครงสร้าง (Section-by-Section)**

1. **Top Navigation Bar:** ส่วนควบคุมด้านบน มีปุ่มย้อนกลับ (Back Button) เพื่อป้องกันกรณี HR เผลอกดออกจากหน้าจอโดยไม่ได้ตั้งใจ (มีระบบ Confirm dialog) และแสดงชื่อหน้าจอชัดเจน  
2. **Progress Indicator / Progress Bar:** แถบแสดงความคืบหน้าของการกรอกข้อมูล (เช่น กรอกช่องที่เป็น Required Field ไปแล้วกี่เปอร์เซ็นต์) เพื่อกระตุ้นและอำนวยความสะดวกในการตรวจสอบข้อมูลก่อนส่ง  
3. **Scrollable Content (Main Area):** พื้นที่เลื่อนขึ้นลงได้ที่บรรจุการจัดหมวดหมู่ข้อมูลในรูปแบบของ Card เพื่อลดความล้าทางสายตา (Visual Fatigue) ของ HR แบ่งเป็น:  
   * **ประเภทพนักงาน:** ใช้ปุ่มตัวเลือกที่มองเห็นเด่นชัดและกดง่าย  
   * **ข้อมูลพื้นฐาน:** ฟอร์มรับข้อความสำหรับ ชื่อ นามสกุล อายุ และชื่อเล่น (Optional)  
   * **ข้อมูลเพิ่มเติม:** เงินเดือนเริ่มต้น ทักษะ (สามารถเพิ่มได้หลายรายการ) เบอร์โทรหลัก และเบอร์โทรสำรอง (Optional)  
4. **Bottom Sticky Action Area:** ปุ่ม "บันทึกข้อมูล" ขนาดใหญ่เต็มความกว้าง (Full-width Action Button) ที่จะ **ถูกตรึงไว้ด้านล่างสุดของหน้าจอเสมอ** ไม่เลื่อนไปตาม Scroll View เพื่อให้ HR สามารถกดบันทึกได้ทันทีเมื่อพร้อม โดยไม่ต้องเลื่อนหน้าจอกลับลงมาด้านล่างสุด

   ### **1.2 Widget Mapping Table (การจับคู่ Flutter Widgets และลำดับการซ้อน)**

ตารางด้านล่างแสดงโครงสร้างของแต่ละองค์ประกอบ ตั้งแต่ Widget ระดับนอกสุด (Parent) ไปจนถึง Widget ระดับย่อยที่สุด (Child) พร้อมเหตุผลและคุณสมบัติเด่นในการจัดการข้อมูล:

| ส่วนของหน้าจอ (Wireframe Section) | Flutter Widgets (Parent \-\> Child Sequence) | หน้าที่และความสอดคล้องกับ UX/UI / Clean Architecture |
| ----- | ----- | ----- |
| **โครงสร้างพื้นฐานของหน้าจอ** | `Scaffold` \-\> `SafeArea` | จัดเตรียมโครงสร้างพื้นฐาน ป้องกันไม่ให้เนื้อหาถูกบดบังด้วยรอยบาก (Notch) หรือแถบระบบของอุปกรณ์เคลื่อนที่ |
| **ส่วนหัวหน้าจอ (Top Bar)** | `AppBar` \-\> `IconButton` (Back) \+ `Text` (Title) | แถบเครื่องมือด้านบน จัดการเรื่อง Navigation |
| **เลย์เอาต์การแบ่งพื้นที่หลัก** | `Column` \-\> $$\`Expanded\` (Scrollable Area), \`Padding\` (Sticky Button)$$ | แบ่งพื้นที่ให้ส่วนฟอร์มขยายตัวได้เต็มที่และเลื่อนขึ้นลงได้ ขณะที่ตรึงปุ่มบันทึกไว้ด้านล่างสุดเสมอ |
| **พื้นที่ฟอร์มแบบเลื่อนได้** | `Expanded` \-\> `SingleChildScrollView` \-\> `Form` | เปิดใช้ฟีเจอร์เลื่อนหน้าจอ และหุ้มด้วย `Form` Widget เพื่อทำหน้าที่ Validate ข้อมูลพร้อมกันผ่าน `GlobalKey<FormState>` |
| **การจัดกลุ่มเนื้อหาภายในฟอร์ม** | `Padding` \-\> `Column` \-\> `Card` \-\> `Padding` \-\> `Column` (Form Fields) | ใช้ `Card` ในการสร้าง Visual Section เพื่อแยกหมวดหมู่ข้อมูล ปรับมุมโค้งมนและใส่เงาเพิ่มมิติ (Slight Elevation) |
| **1\. ส่วนเลือกประเภทพนักงาน** | `SegmentedButton<EmployeeType>` หรือ `Row` \-\> `ChoiceChip` | ให้ HR เลือกประเภทพนักงานได้เพียงหนึ่งเดียว (Enum-based State) มี Feedback การเลือกที่ชัดเจน |
| **2\. ข้อมูลพื้นฐาน** | `TextFormField` (สำหรับ Text) และ `DropdownButtonFormField` (สำหรับแผนก) | รับข้อมูลประเภทตัวอักษร มีการตั้งค่า `validator` สำหรับช่องที่บังคับกรอก (NotNull) |
| **3\. ข้อมูลเพิ่มเติม (เงินเดือน)** | `TextFormField` | ตั้งค่า `keyboardType: TextInputType.number` และใส่ `inputFormatters` เพื่อจำกัดให้พิมพ์ได้เฉพาะตัวเลข/ทศนิยม |
| **4\. ข้อมูลทางเลือก (Optional)** | `TextFormField` | ฟิลด์ที่ไม่ต้องใส่เงื่อนไข validation และมีกลไกกำหนด Default Value เป็น `"ไม่ได้ระบุ"` ที่ระดับ Model/Entity หากค่าที่รับมาเป็นช่องว่าง |
| **5\. ส่วนแสดง/เพิ่มทักษะ (Skills)** | `Wrap` \-\> `InputChip` | ช่วยให้แสดงรายการทักษะที่เลือก/พิมพ์เข้ามาใหม่ได้อย่างยืดหยุ่นในแบบหลายแถว (Responsive Row wrapping) |
| **ปุ่มดำเนินการด้านล่างสุด** | `Container` (Decoration) \-\> `SizedBox` \-\> `ElevatedButton` \-\> `Row` $$\`Icon\`, \`Text\`$$ | ปุ่มบันทึกข้อมูลแบบ Sticky ที่มีขนาดยาวเต็มจอ กดง่าย ปรับเปลี่ยนสีตามสถานะ Validation (เช่น สีเทาเมื่อฟอร์มยังไม่สมบูรณ์) |

### **1.3 Flutter Widget Hierarchy (Tree View)**

```
AppOnboardingScreen (StatelessWidget/ConsumerWidget - Clean Architecture Controller)
└── Scaffold
    ├── appBar: AppBar
    │    ├── leading: IconButton (Back Action with Pop Confirmation)
    │    └── title: Text ("เพิ่มพนักงานใหม่")
    ├── body: SafeArea
    │    └── Column (Main Layout Container)
    │         ├── children: [
    │         │    /* 1. PROGRESS BAR AREA */
    │         │    LinearProgressIndicator (แสดง % การกรอกข้อมูลที่เป็น Required)
    │         │    
    │         │    /* 2. SCROLLABLE FORM AREA */
    │         │    Expanded
    │         │    └── SingleChildScrollView
    │         │        └── Padding (EdgeInsets.all(16.0))
    │         │            └── Form (key: _formKey)
    │         │                └── Column
    │         │                     ├── children: [
    │         │                     │    /* Section Card 1: Employee Type */
    │         │                     │    Card
    │         │                     │    └── Padding
    │         │                     │        └── Column (Title + Selector)
    │         │                     │             ├── Text ("ประเภทพนักงาน")
    │         │                     │             └── SegmentedButton<EmployeeType>
    │         │                     │                  
    │         │                     │    /* Section Card 2: Basic Information */
    │         │                     │    Card
    │         │                     │    └── Padding
    │         │                     │        └── Column (Fields)
    │         │                     │             ├── Text ("ข้อมูลพื้นฐาน")
    │         │                     │             ├── TextFormField (Label: ชื่อจริง *, validator)
    │         │                     │             ├── TextFormField (Label: นามสกุล *, validator)
    │         │                     │             ├── Row
    │         │                     │             │    ├── Expanded -> TextFormField (Label: อายุ *, keyboardType: number)
    │         │                     │             │    └── Expanded -> TextFormField (Label: ชื่อเล่น (Optional))
    │         │                     │             └── DropdownButtonFormField<Department> (Label: แผนก *)
    │         │                     │
    │         │                     │    /* Section Card 3: Additional & Contacts */
    │         │                     │    Card
    │         │                     │    └── Padding
    │         │                     │        └── Column (Fields)
    │         │                     │             ├── Text ("ข้อมูลเพิ่มเติม")
    │         │                     │             ├── TextFormField (Label: เงินเดือนเริ่มต้น *, prefixText: "฿")
    │         │                     │             ├── Column (Skills input section)
    │         │                     │             │    ├── TextFormField (พิมพ์เพิ่มทักษะ)
    │         │                     │             │    └── Wrap (spacing: 8.0) -> List of InputChip (Skills Tags)
    │         │                     │             ├── TextFormField (Label: เบอร์โทรหลัก *, keyboardType: phone)
    │         │                     │             └── TextFormField (Label: เบอร์โทรสำรอง (Optional), keyboardType: phone)
    │         │                     │    ]
    │         │    
    │         │    /* 3. STICKY BOTTOM ACTION BUTTON AREA */
    │         │    Container (Decoration: BoxShadow, Color: Background)
    │         │    └── Padding (EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0))
    │         │        └── SizedBox (width: double.infinity, height: 50.0)
    │         │            └── ElevatedButton (onPressed: _submitForm)
    │         │                └── Row (mainAxisAlignment: Center)
    │         │                     ├── Icon (Icons.save_rounded)
    │         │                     └── Text ("บันทึกข้อมูลพนักงาน")
    │         │ ]
```

## **\[PART 2\] หน้าจอ: การประมวลผลสิ้นเดือนและคำนวณอัตโนมัติ (End-of-Month Payroll Evaluation Screen)**

### **2.1 Wireframe Layout Breakdown (โครงร่างหน้าจอจากบนลงล่าง)**

หน้าจอนี้เน้นความชัดเจนของข้อมูลสรุปยอดรวมและการแสดงรายการแยกรายบุคคลที่คำนวณเสร็จสิ้นแล้ว โดยมีโครงสร้างดังนี้:

```
+-----------------------------------------------------------+
| [ <- ]            ประเมินผลสิ้นเดือน (Title)                 |  <- 1. Top Navigation Bar
+-----------------------------------------------------------+
|  +-----------------------------------------------------+  |
|  | [Icon] รายงานสรุปการจ่ายเงิน (Payroll Summary)      |  |  <- 2. Summary Dashboard Card
|  | พนักงานรวม: 42 คน    | ยอดชำระสุทธิทั้งหมด: ฿1,245,300 |  |
|  | โบนัสรวม: ฿84,500    | ภาษีหัก ณ ที่จ่ายรวม: ฿32,100  |  |
|  +-----------------------------------------------------+  |
|                                                           |
| [ค้นหารายชื่อพนักงาน...                           [กรอง]] |  <- 3. Search & Filter Bar
|                                                           |
|  +-----------------------------------------------------+  |
|  | [Icon] นายกิตติศักดิ์ พลดี (พนักงานประจำ)             |  |  <- 4. Section: Employee Payroll Cards
|  | เงินเดือนพื้นฐาน: ฿35,000  | โบนัส (5%): ฿1,750         |  |     (Scrollable List Area)
|  | ภาษีหัก ณ ที่จ่าย (3%): ฿1,050                         |  |
|  | ยอดรับสุทธิ: ฿35,700                                 |  |
|  +-----------------------------------------------------+  |
|                                                           |
|  +-----------------------------------------------------+  |
|  | [Icon] นางสาวสิรินทร์ แก้วดี (เด็กฝึกงาน - Intern)      |  |
|  | เงินเดือนคงที่: ฿10,000   | โบนัส (10%): ฿1,000        |  |
|  | ภาษีพิเศษ (1%): ฿100                                 |  |
|  | ยอดรับสุทธิ: ฿10,900                                 |  |
|  +-----------------------------------------------------+  |
|                                                           |
+-----------------------------------------------------------+
|          [ ปุ่มประมวลผลใหม่ / บันทึกผลลัพธ์และออกรายงาน ]    |  <- 5. Bottom Sticky Action Area
+-----------------------------------------------------------+
```

### **2.2 กฎการคำนวณอัตโนมัติ (Business Logic & Mathematics)**

ระบบจะทำงานประมวลผลข้อมูลผ่าน Loop โดยคำนวณตัวแปรของพนักงานแต่ละคน ($i$) ตามสูตรทางคณิตศาสตร์และเงื่อนไขประเภทพนักงานดังนี้:

#### **1\. การคำนวณโบนัสประจำเดือน ($Bonus\_i$)**

ใช้ฐานเงินเดือน ($Salary\_i$) เป็นเงื่อนไขในการพิจารณาอัตราเปอร์เซ็นต์โบนัส:

$$Bonus\_i \= \\begin{cases} Salary\_i \\times 10\\% & \\text{ถ้า } Salary\_i \\le 30,000 \\text{ บาท} \\\\ Salary\_i \\times 5\\% & \\text{ถ้า } Salary\_i \> 30,000 \\text{ บาท} \\end{cases}$$

#### **2\. การคำนวณภาษีหัก ณ ที่จ่าย ($Tax\_i$)**

พิจารณาตามตำแหน่งและประเภทของพนักงาน โดยเด็กฝึกงานจะมีฐานเงินเดือนคงที่สำหรับประเมินที่ $10,000$ บาท:

$$Tax\_i \= \\begin{cases} 10,000 \\times 1\\% \= 100 \\text{ บาท} & \\text{ถ้าเป็นเด็กฝึกงาน (Intern)} \\\\ Salary\_i \\times 3\\% & \\text{ถ้าเป็นพนักงานประจำ หรือผู้จัดการ} \\end{cases}$$

#### **3\. การคำนวณยอดเงินรวมรายบุคคล ($NetPay\_i$)**

ยอดเงินสุทธิที่พนักงานแต่ละคนจะได้รับหลังจากคำนวณโบนัสและหักภาษี ณ ที่จ่ายเสร็จสิ้น:

$$NetPay\_i \= Salary\_i \+ Bonus\_i \- Tax\_i$$

## **\[PART 3\] หน้าจอ: การคัดกรองตามแผนกและแนะนำการพัฒนาบุคลากร (Department Filters & Recommendations Screen)**

### **3.1 Wireframe Layout Breakdown (โครงร่างหน้าจอจากบนลงล่าง)**

```
+-----------------------------------------------------------+
| [ <- ]        คัดกรองแผนก & พัฒนาบุคลากร (Title)          |  <- 1. Top Navigation Bar
+-----------------------------------------------------------+
|                                                           |
|  [ ทั้งหมด ]   [ แผนก IT ]   [ แผนก HR ]   [ แผนก Design ]  |  <- 2. Department Horizontal Filter
|                                                           |
+-----------------------------------------------------------+
|  +-----------------------------------------------------+  |
|  | [Icon] คำแนะนำการพัฒนาสำหรับ: แผนก IT                |  |  <- 3. Smart Recommendation Card
|  | "ส่งเข้ารับการอบรม Cybersecurity เพื่อป้องกันภัยระบบ"|  |     (Dynamic Content based on Switch)
|  +-----------------------------------------------------+  |
|                                                           |
|  จำนวนพนักงานที่พบ: 14 คน                                   |  <- 4. Metadata Header
|                                                           |
|  +-----------------------------------------------------+  |
|  | [Icon] สมชาย ยอดนักรบ (IT Specialist)                |  |  <- 5. Employee List View
|  | Skills: Dart, Flutter, Firebase                     |  |     (Scrollable Area)
|  +-----------------------------------------------------+  |
|                                                           |
|  +-----------------------------------------------------+  |
|  | [Icon] นภา สวยเด่น (UI/UX Designer)                   |  |
|  | Skills: Figma, Design System, Prototyping           |  |
|  +-----------------------------------------------------+  |
|                                                           |
+-----------------------------------------------------------+
|          [ ปุ่มพิมพ์รายงานส่งต่อหัวหน้างาน (Print) ]        |  <- 6. Bottom Sticky Action Area
+-----------------------------------------------------------+
```

### **3.2 ตรรกะการประมวลผลและคัดกรองพนักงาน (Dart Pattern Matching)**

ระบบคำแนะนำจะคัดกรองข้อมูลอย่างเหมาะสมด้วยกลไก Switch-Case ในระดับ Domain Layer:

```
String getRecommendationText(Department dept) {
  switch (dept) {
    case Department.it:
      return "ส่งเข้ารับการอบรม Cybersecurity";
    case Department.hr:
      return "ส่งเข้าร่วมสัมมนาการสรรหาบุคลากรยุคใหม่";
    case Department.design:
      return "ส่งเข้าเวิร์กชอป UI/UX Trend";
    default:
      return "ปฐมนิเทศพนักงานทั่วไป";
  }
}
```

## **\[PART 4\] หน้าจอ: การสรุปภาพรวมรายจ่ายสำหรับผู้บริหาร (Executive Financial Overview Screen)**

หน้าจอนี้ออกแบบสำหรับผู้บริหารระดับสูง (CEO & Management) เพื่อใช้ตรวจทาน
งบประมาณและจำลอง **Payroll Approval Gate** ใน UI เท่านั้น การยืนยันปัจจุบัน
เปลี่ยน state ภายในหน้าจอและแสดง `SnackBar`; ยังไม่มี server-side approval,
audit trail หรือการสั่งจ่ายเงินจริง

### **4.1 Wireframe Layout Breakdown (โครงร่างหน้าจอจากบนลงล่าง)**

```
+-----------------------------------------------------------+
| [ <- ]           ภาพรวมรายจ่ายสำหรับผู้บริหาร (Title)         |  <- 1. Top Navigation Bar
+-----------------------------------------------------------+
|  +-----------------------------------------------------+  |
|  | [Icon] สถานะรอบบัญชี: รอการอนุมัติ (Pending Approval)  |  |  <- 2. Status Badge Row
|  +-----------------------------------------------------+  |
|                                                           |
|  +-----------------------------------------------------+  |
|  | [Icon] ยอดรวมค่าใช้จ่ายทั้งสิ้นประจำเดือน               |  |  <- 3. Large Hero Metric Card (Expenses)
|  |          ฿1,330,000.00                              |  |     (Total Salary + Total Bonus)
|  |   (เงินเดือน: ฿1,245,300.00 | โบนัส: ฿84,700.00)     |  |
|  +-----------------------------------------------------+  |
|                                                           |
|  +-----------------------------------------------------+  |
|  | [Icon] พนักงานทั้งหมด                                 |  |  <- 4. Secondary Metric Card
|  |          42 คน (Active)                             |  |     (Total Employee headcount)
|  |   (พนักงานประจำ: 35 คน | เด็กฝึกงาน: 5 คน | ผู้จัดการ: 2 คน) |
|  +-----------------------------------------------------+  |
|                                                           |
|  +-----------------------------------------------------+  |
|  | [Icon] สรุปรายจ่ายแยกตามฝ่ายงาน (Visual Graph)        |  |  <- 5. Department Breakdown Graph
|  |  - IT:     ===================> ฿450,000            |  |
|  |  - Design: ============> ฿320,000                   |  |
|  |  - HR:     =======> ฿180,000                        |  |
|  +-----------------------------------------------------+  |
|                                                           |
+-----------------------------------------------------------+
|      [ ปฏิเสธการจ่ายเงิน ]    [ ยืนยันอนุมัติการจ่ายเงิน ]   |  <- 6. Bottom Double Action Sticky Bar
+-----------------------------------------------------------+
```

### **4.2 กฎการดึงยอดสรุปทางบัญชีสำหรับผู้บริหาร (Financial Formulas)**

ระบบจะดึงยอดรวมที่ทำการคำนวณ (Loop) รายบุคคลจาก Flow ที่ 2 มาประมวลผลเพื่อแสดงยอดภาพรวมให้ผู้บริหารตรวจสอบ:

#### **1\. ยอดรวมพนักงานทั้งหมด ($TotalEmployees$)**

นับจำนวนพนักงานทั้งหมดในองค์กร ($n$):

$$TotalEmployees \= n$$

#### **2\. ยอดรวมรายจ่ายทั้งหมดของทั้งบริษัท ($TotalExpenses$)**

คำนวณจากผลรวมของเงินเดือน ($Salary\_i$) และโบนัสประจำเดือน ($Bonus\_i$) ของพนักงานทุกคน:

$$TotalExpenses \= \\sum\_{i=1}^{n} (Salary\_i \+ Bonus\_i)$$

*(หมายเหตุ: ยอดภาษีหัก ณ ที่จ่ายไม่ถูกนำมาหักลบ เนื่องจากภาษีเป็นส่วนหนึ่งของค่าใช้จ่ายที่บริษัทต้องหักเพื่อส่งสรรพากร จึงนับรวมเป็นต้นทุนหลักทางด้านบุคคลร่วมด้วย)*

### **4.3 Widget Mapping Table (การจับคู่ Flutter Widgets และลำดับการซ้อน)**

| ส่วนของหน้าจอ (Executive Section) | Flutter Widgets (Parent \-\> Child Sequence) | หน้าที่และความสอดคล้องกับ UX/UI / Clean Architecture |
| ----- | ----- | ----- |
| **โครงสร้างพื้นฐาน** | `Scaffold` \-\> `SafeArea` | ป้องกันพื้นที่ขอบหน้าจอ รอยบากระบบ และแถบโฮมของสมาร์ตโฟน |
| **ส่วนแสดงสถานะรอบบัญชี** | `Row` \-\> `Container` (Background: Soft Orange/Green) \-\> `Icon` \+ `Text` | ชี้แจงสถานะรอบบัญชีเด่นชัด เช่น "รอการอนุมัติ" ด้วยสีส้มอบอุ่นเพื่อเตือนให้ดำเนินการ |
| **การ์ดสรุปยอดค่าใช้จ่ายหลัก (Hero)** | `Card` \-\> `Padding` \-\> `Column` \-\> `Text` (Large Big Font) \+ `Divider` \+ `Row` (Sub-Metrics) | เน้นยอดรายจ่ายทั้งหมด ($TotalExpenses$) เพื่อให้ผู้บริหารมองเห็นได้ทันทีเป็นอันดับแรก ขนาดฟอนต์ 32pt ตัวหนา |
| **สถิติจำนวนพนักงาน** | `Card` \-\> `ListTile` \-\> `title: Text` (Count) \+ `subtitle: Row` (Role Split) | สรุปจำนวนทีมทั้งหมดเพื่อความสมดุลด้านทรัพยากรบุคคล |
| **กราฟสถิติรายจ่ายแยกตามฝ่าย** | `Card` \-\> `Column` \-\> `ListView.builder` \-\> `Row` \[ `Text` (Dept), `Expanded` \-\> `LinearProgressIndicator` (Custom Scale), `Text` (Cost) \] | ทำหน้าที่จำลองบาร์กราฟ (Horizontal Bar Graph) ด้วย `LinearProgressIndicator` เพื่อให้มองเห็นความสัดส่วนของงบประมาณในแต่ละแผนกได้ง่ายขึ้น |
| **ปุ่มอนุมัติติดแน่นด้านล่าง** | `Container` \-\> `Padding` \-\> `Row` \-\> \[ `Expanded` (Reject Button), `SizedBox` (Spacing), `Expanded` (Approve Button) \] | ใช้ `Row` แบ่งน้ำหนักปุ่มสัดส่วน 30:70 ให้ปุ่มยืนยันอนุมัติมีขนาดกว้างกว่าอย่างชัดเจน (Visual Hierarchy) |

### **4.4 Flutter Widget Hierarchy (Tree View \- Executive Screen)**

```
AppExecutiveFinancialOverviewScreen (StatelessWidget/ConsumerWidget)
└── Scaffold
    ├── appBar: AppBar
    │    ├── leading: IconButton (Back Action)
    │    └── title: Text ("ภาพรวมงบประมาณรายเดือน")
    ├── body: SafeArea
    │    └── Column (Main Layout Grid)
    │         ├── children: [
    │         │    /* 1. SCROLLABLE DASHBOARD CONTENT */
    │         │    Expanded
    │         │    └── SingleChildScrollView
    │         │        └── Padding (EdgeInsets.all(16.0))
    │         │            └── Column
    │         │                 ├── children: [
    │         │                 │    /* A. STATUS ALERT BADGE */
    │         │                 │    Container (BorderRadius: 8, Color: OrangeAccent.withOpacity(0.1))
    │         │                 │    └── Row (Icon(Icons.pending), Text("รอการอนุมัติโอนเงินเดือน")),
    │         │                 │    
    │         │                 │    /* B. HERO TOTAL BUDGET EXPENSES CARD */
    │         │                 │    Card (Elevation: 6, Color: DarkBlueBackground)
    │         │                 │    └── Padding
    │         │                 │        └── Column (Large Numeric Text)
    │         │                 │             ├── Text ("ยอดค่าใช้จ่ายรวมทั้งสิ้น")
    │         │                 │             ├── Text ("฿1,330,000.00", style: TextStyle(fontSize: 32, fontWeight: Bold))
    │         │                 │             └── Row (Sub-details: Salary vs Bonus split)
    │         │                 │                  
    │         │                 │    /* C. SECONDARY EMPLOYEES HEADCOUNT CARD */
    │         │                 │    Card
    │         │                 │    └── ListTile
    │         │                 │         ├── leading: Icon(Icons.people_rounded)
    │         │                 │         ├── title: Text("พนักงานทั้งหมด: 42 คน")
    │         │                 │         └── subtitle: Text("ประจำ: 35 | ฝึกงาน: 5 | ผู้จัดการ: 2"),
    │         │                 │    
    │         │                 │    /* D. VISUAL BAR CHART: DEPARTMENTAL SPENDING */
    │         │                 │    Card
    │         │                 │    └── Padding
    │         │                 │        └── Column
    │         │                 │             ├── Text ("สัดส่วนการชำระเงินแยกตามแผนก")
    │         │                 │             └── Column (List of progress bars)
    │         │                 │                  ├── Row (IT: LinearProgressIndicator(value: 0.45), Cost)
    │         │                 │                  ├── Row (Design: LinearProgressIndicator(value: 0.32), Cost)
    │         │                 │                  └── Row (HR: LinearProgressIndicator(value: 0.18), Cost)
    │         │                 │    ]
    │         │    
    │         │    /* 2. STICKY DOUBLE-ACTION BUTTON AREA (CEO APPROVAL GATE) */
    │         │    Container (Decoration: BoxShadow)
    │         │    └── Padding (EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0))
    │         │        └── Row
    │         │             ├── children: [
    │         │             │    /* Reject Button (30%) */
    │         │             │    Expanded
    │         │             │    │    flex: 3,
    │         │             │    │    └── OutlinedButton (onPressed: _onRejectRequest)
    │         │             │    │         └── Text ("ส่งกลับแก้ไข")
    │         │             │    
    │         │             │    /* Approve Button (70%) */
    │         │             │    Expanded
    │         │             │    │    flex: 7,
    │         │             │    │    └── ElevatedButton (onPressed: _onApproveRequest)
    │         │             │    │         └── Row
    │         │             │    │              ├── Icon(Icons.verified_user_rounded)
    │         │             │    │              └── Text("อนุมัติจ่ายเงินเดือน")
    │         │             │    ]
    │         │ ]
```

## **\[PART 5\] UX/UI & Code Architecture Recommendations (คำแนะนำสำหรับทุกหน้าจอ)**

> หัวข้อนี้เป็นข้อเสนอสำหรับการพัฒนาระยะถัดไป ไม่ใช่สถานะ As-built ปัจจุบัน
> ขณะนี้แอปใช้ `ChangeNotifier`/`EmployeeStore` แบบ in-memory และไม่มี biometric,
> backend state machine หรือฐานข้อมูลธุรกรรม

### **ด้านสถาปัตยกรรมและการจัดการ Null Safety (Class Blueprint & Model)**

* **การจัดการค่า Optional (Null Safety):** ใน Dart Class Blueprint (Data Model) ควรกำหนดฟิลด์ที่ไม่บังคับให้เป็นประเภท Nullable เช่น `String? nickname;` และ `String? backupPhoneNumber;` โดยกำหนดค่าเริ่มต้นหรือ fallback เป็น `"ไม่ได้ระบุ"` เมื่อแสดงผลใน UI  
* **การป้องกันความเสียหายทางการเงินด้วยสถาปัตยกรรมความปลอดภัยสูง (Secure State Machine):** \* สำหรับหน้าจอของผู้บริหาร ยอดสรุปการคำนวณการเงินทั้งหมดจะต้องถูกส่งผ่านสภาวะแบบเป็นขั้นตอน (State Transitions) โดยใช้ระบบ State Management (เช่น Riverpod หรือ BLoC) โดยแบ่งสถานะรอบบัญชีเป็นไอเดมโปเทนท์แอนด์สเตตแมชชีน (State Machine):  
   $$\\text{Draft} \\longrightarrow \\text{Calculated} \\longrightarrow \\text{Pending Approval} \\longrightarrow \\text{Approved}$$  
  * ห้ามคำนวณและเก็บค่าทางการเงินเป็น Dynamic ใน UI เพื่อความปลอดภัยจากการถูกดัดแปลงโครงสร้างหน่วยความจำ  
* **การประมวลผลข้อมูล (Clean Architecture Separation):** \* UI ทำหน้าที่เพียงแสดงสถานะที่ดึงมาจาก Domain Models เท่านั้น  
  * ส่วนสูตรการคิดรวมเงิน $TotalExpenses$ และยอดรวมพนักงาน $TotalEmployees$ จะถูกรวมเป็นคำสั่ง (Method) ใน Domain Layer เพื่อป้องกันปัญหา Null Exception และรองรับการทำ Unit Testing ในระดับ Domain:

```
// domain/entities/payroll_summary_entity.dart
class PayrollSummaryEntity {
  final List<EmployeeModel> employees;

  PayrollSummaryEntity({required this.employees});

  int get totalActiveEmployees => employees.length;

  double get totalSalaryExpenses => employees.fold(0.0, (sum, emp) => sum + emp.salary);
  double get totalBonusExpenses => employees.fold(0.0, (sum, emp) => sum + emp.calculatedBonus);
  double get grandTotalExpenses => totalSalaryExpenses + totalBonusExpenses;
}
```

  ### **ด้าน UX/UI (User Experience Best Practices)**

1. **Double-Confirmation for Executive Decisions:** เนื่องจากปุ่ม "อนุมัติจ่ายเงินเดือน" เป็นปุ่มที่มีผลกระทบต่อธุรกรรมทางการเงินของบริษัท ควรมีการเพิ่มระบบการตรวจสอบซ้ำ เช่น การกดยืนยันสองครั้ง (Double-Tap Interaction) หรือการสแกนลายนิ้วมือ/ใบหน้า (Biometric Authentication \- FaceID/TouchID) ก่อนที่แอปพลิเคชันจะบันทึกผลสำเร็จลงระบบฐานข้อมูลหลัก  
2. **Adaptive Keyboard & Overlap Safeguards:** ทุกๆ หน้าจอที่เป็นฟอร์มบันทึก ควรจัดเตรียม `resizeToAvoidBottomInset: true` เสมอ เพื่อลดปัญหาระบบแป้นพิมพ์ระบบทับซ้อนช่องกรอกข้อมูล  
3. **Interactive Visual Cues:** การจัดวางข้อมูลสำหรับ CEO ควรหลีกเลี่ยงการใช้เอกสารตารางที่มีตัวเลขสีทึบจนเกินไป ควรใช้ Visual Progress Bar สีเด่น หรือการแบ่งแยกแผนกด้วยแถบสีเพื่ออำนวยความสะดวกในการวิเคราะห์งบประมาณและลดข้อผิดพลาดในการตรวจสอบ  
4. **Dynamic Transition and Tactile Feedback:** การเพิ่ม Haptic Feedback (การสั่นตอบสนองเบาๆ บนเครื่องสมาร์ตโฟน) เมื่อผู้บริหารกดปุ่ม "อนุมัติ" หรือ "ส่งกลับแก้ไข" ช่วยให้เกิดความรู้สึกพึงพอใจและมั่นใจในการสั่งงานผ่านระบบเคลื่อนที่มากยิ่งขึ้น  

