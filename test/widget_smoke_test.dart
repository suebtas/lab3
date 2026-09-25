import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startup_hr/data/employee_store.dart';
import 'package:startup_hr/screens/department_filter_screen.dart';
import 'package:startup_hr/screens/executive_overview_screen.dart';
import 'package:startup_hr/screens/home_screen.dart';
import 'package:startup_hr/screens/onboarding_screen.dart';
import 'package:startup_hr/screens/payroll_evaluation_screen.dart';

Widget _wrap(Widget screen) {
  return MaterialApp(home: screen);
}

void main() {
  testWidgets('Home screen แสดงภาพรวมจาก seed data', (tester) async {
    await tester.pumpWidget(_wrap(HomeScreen(store: EmployeeStore())));
    await tester.pump();
    expect(find.text('Startup HR'), findsOneWidget);
    expect(find.text('ภาพรวม ณ ปัจจุบัน'), findsOneWidget);
    expect(find.text('พนักงานทั้งหมด'), findsOneWidget);
  });

  testWidgets('Onboarding: กรอกข้อมูลแล้วบันทึกเพิ่มพนักงานได้ตามเงื่อนไข Optional',
      (tester) async {
    final store = EmployeeStore();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => OnboardingScreen(store: store)),
            ),
            child: const Text('เปิดหน้าเพิ่มพนักงาน'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('เปิดหน้าเพิ่มพนักงาน'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'ชื่อจริง *'), 'ก้อง');
    await tester.enterText(find.widgetWithText(TextFormField, 'นามสกุล *'), 'ใจดี');
    await tester.enterText(find.widgetWithText(TextFormField, 'อายุ *'), '25');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'เงินเดือนเริ่มต้น *'), '32000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'เบอร์โทรหลัก *'), '099-999-9999');
    await tester.enterText(
        find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'พิมพ์เพิ่มทักษะแล้วกด +'),
        'Flutter');
    final addSkill = find.byIcon(Icons.add_rounded);
    await tester.ensureVisible(addSkill);
    await tester.pumpAndSettle();
    await tester.tap(addSkill);
    await tester.pump();

    final before = store.employees.length;
    await tester.tap(find.text('บันทึกข้อมูลพนักงาน'));
    await tester.pumpAndSettle();

    expect(store.employees.length, before + 1);
    final added = store.employees.last;
    expect(added.fullName, 'ก้อง ใจดี');
    expect(added.nicknameLabel, 'ไม่ได้ระบุ');
    expect(added.backupPhoneLabel, 'ไม่ได้ระบุ');
    expect(added.salary, 32000);
    expect(find.text('บันทึกข้อมูล ก้อง ใจดี แล้ว'), findsOneWidget);
  });

  testWidgets('Payroll Evaluation: แสดงการ์ดสรุปและรายพนักงาน', (tester) async {
    await tester.pumpWidget(_wrap(PayrollEvaluationScreen(store: EmployeeStore())));
    await tester.pumpAndSettle();
    expect(find.text('ประเมินผลสิ้นเดือน'), findsOneWidget);
    expect(find.text('รายงานสรุปการจ่ายเงิน (Payroll Summary)'), findsOneWidget);
    expect(find.text('กิตติศักดิ์ พลดี (พนักงานประจำ)'), findsOneWidget);
    expect(find.text('สิรินทร์ แก้วดี (เด็กฝึกงาน - Intern)'), findsNothing);
  });

  testWidgets('Department Filter: กรองแผนกและแสดงคำแนะนำเปลี่ยนตาม Switch',
      (tester) async {
    await tester.pumpWidget(_wrap(DepartmentFilterScreen(store: EmployeeStore())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('แผนก IT'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cybersecurity'), findsOneWidget);
    expect(find.textContaining('กิตติศักดิ์'), findsOneWidget);
    expect(find.textContaining('นภา'), findsNothing);

    await tester.tap(find.text('แผนก Design'));
    await tester.pumpAndSettle();
    expect(find.textContaining('UI/UX Trend'), findsOneWidget);
    expect(find.textContaining('นภา'), findsOneWidget);
  });

  testWidgets('Executive Overview: แสดงยอดรวมและส่วนแบ่งแผนก', (tester) async {
    await tester.pumpWidget(_wrap(ExecutiveOverviewScreen(store: EmployeeStore())));
    await tester.pumpAndSettle();
    expect(find.text('สถานะรอบบัญชี: รอการอนุมัติ'), findsOneWidget);
    expect(find.text('ยอดค่าใช้จ่ายรวมทั้งสิ้นประจำเดือน'), findsOneWidget);
    expect(find.text('พนักงานทั้งหมด: 12 คน'), findsOneWidget);
    expect(find.textContaining('IT:'), findsOneWidget);
    expect(find.text('อนุมัติจ่ายเงินเดือน'), findsOneWidget);
  });
}