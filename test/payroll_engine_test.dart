import 'package:flutter_test/flutter_test.dart';
import 'package:startup_hr/core/money.dart';
import 'package:startup_hr/domain/models/department.dart';
import 'package:startup_hr/domain/models/employee_model.dart';
import 'package:startup_hr/domain/payroll_engine.dart';
import 'package:startup_hr/domain/payroll_summary_entity.dart';

const _engine = PayrollEngine();

Employee _permanent(String id, int salary, {Department department = Department.it}) {
  return PermanentEmployee(
    id: id,
    firstName: 'ทดสอบ',
    lastName: id,
    age: 30,
    department: department,
    salary: salary,
    phoneNumber: '080-000-0000',
    skills: const ['Dart'],
  );
}

InternEmployee _intern(String id) {
  return InternEmployee(
    id: id,
    firstName: 'ฝึกงาน',
    lastName: id,
    age: 21,
    department: Department.design,
    salary: 10000,
    phoneNumber: '080-000-0000',
    skills: const ['Figma'],
  );
}

void main() {
  group('PayrollEngine - โบนัส', () {
    test('เงินเดือน <= 30,000 ได้โบนัส 10%', () {
      expect(_engine.calculateBonus(_permanent('A', 30000)), 3000);
      expect(_engine.calculateBonus(_permanent('B', 28000)), 2800);
    });

    test('เงินเดือน > 30,000 คิดโบนัส 5%', () {
      expect(_engine.calculateBonus(_permanent('C', 35000)), 1750);
      expect(_engine.calculateBonus(_permanent('D', 30001)), 1500);
    });
  });

  group('PayrollEngine - ภาษีหัก ณ ที่จ่าย', () {
    test('เด็กฝึกงานหัก 1% ของฐานคงที่ 10,000 = 100', () {
      expect(_engine.calculateTax(_intern('I1')), 100);
    });

    test('พนักงานประจำ/ผู้จัดการหักภาษี 3% ของเงินเดือน', () {
      expect(_engine.calculateTax(_permanent('E', 35000)), 1050);
    });
  });

  group('PayrollEngine - ยอดรับสุทธิ', () {
    test('กิตติศักดิ์ (เงินเดือน 35,000): สุทธิ 35,700', () {
      final record = _engine.evaluate(_permanent('F', 35000));
      expect(record.bonus, 1750);
      expect(record.tax, 1050);
      expect(record.netPay, 35700);
    });

    test('สิรินทร์ (Intern 10,000): สุทธิ 10,900', () {
      final record = _engine.evaluate(_intern('I2'));
      expect(record.bonus, 1000);
      expect(record.tax, 100);
      expect(record.netPay, 10900);
    });
  });

  group('PayrollSummaryEntity', () {
    test('ค่าใช้จ่ายรวม = เงินเดือนรวม + โบนัสรวม (ยอด reconcile กันเสมอ)', () {
      final employees = [
        _permanent('G', 35000),
        _permanent('H', 30000),
        _intern('I3'),
      ];
      final summary = PayrollSummaryEntity.fromEmployees(employees);
      expect(summary.totalActiveEmployees, 3);
      expect(summary.grandTotalExpenses,
          summary.totalSalaryExpenses + summary.totalBonusExpenses);
    });

    test('แยกยอดตามแผนก', () {
      final employees = [
        _permanent('G', 35000, department: Department.it),
        _permanent('H', 30000, department: Department.hr),
        _intern('I3'),
      ];
      final summary = PayrollSummaryEntity.fromEmployees(employees);
      expect(summary.departmentExpense(Department.it), 35000 + 1750);
      expect(summary.departmentExpense(Department.hr), 30000 + 3000);
    });
  });

  group('Money', () {
    test('formatBaht', () {
      expect(formatBaht(0), '฿0');
      expect(formatBaht(1245300), '฿1,245,300');
      expect(formatBaht(84700), '฿84,700');
    });
  });
}