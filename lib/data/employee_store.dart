import 'package:flutter/foundation.dart';

import '../domain/models/department.dart';
import '../domain/models/employee_model.dart';
import '../domain/payroll_summary_entity.dart';

final class EmployeeStore extends ChangeNotifier {
  EmployeeStore({List<Employee>? seed})
      : _employees = List.of(seed ?? _defaultSeed());

  final List<Employee> _employees;

  List<Employee> get employees => List.unmodifiable(_employees);

  PayrollSummaryEntity get summary =>
      PayrollSummaryEntity.fromEmployees(_employees);

  Employee getById(String id) {
    return _employees.firstWhere((employee) => employee.id == id);
  }

  void addEmployee(Employee employee) {
    _employees.add(employee);
    notifyListeners();
  }

  static List<Employee> _defaultSeed() {
    const skills = <String>['Dart', 'Flutter', 'Firebase'];
    const designSkills = <String>['Figma', 'Design System', 'Prototyping'];
    return [
      const PermanentEmployee(
        id: 'EMP-001',
        firstName: 'กิตติศักดิ์',
        lastName: 'พลดี',
        age: 32,
        department: Department.it,
        salary: 35000,
        phoneNumber: '081-234-5678',
        skills: ['Flutter', 'Dart', 'Swift'],
        nickname: 'กิต',
        backupPhoneNumber: '081-234-9999',
      ),
      const InternEmployee(
        id: 'EMP-002',
        firstName: 'สิรินทร์',
        lastName: 'แก้วดี',
        age: 22,
        department: Department.design,
        salary: 10000,
        phoneNumber: '089-111-2233',
        skills: designSkills,
      ),
      const PermanentEmployee(
        id: 'EMP-003',
        firstName: 'สมชาย',
        lastName: 'ยอดนักรบ',
        age: 29,
        department: Department.it,
        salary: 42000,
        phoneNumber: '086-555-7788',
        skills: skills,
      ),
      const PermanentEmployee(
        id: 'EMP-004',
        firstName: 'นภา',
        lastName: 'สวยเด่น',
        age: 27,
        department: Department.design,
        salary: 36000,
        phoneNumber: '090-888-1122',
        skills: designSkills,
      ),
      const ManagerEmployee(
        id: 'EMP-005',
        firstName: 'เตชินท์',
        lastName: 'สุวรรณเดช',
        age: 40,
        department: Department.it,
        salary: 90000,
        phoneNumber: '082-777-3344',
        skills: ['Leadership', 'System Architecture'],
        teamSize: 8,
      ),
      const ManagerEmployee(
        id: 'EMP-006',
        firstName: 'ปาล์ม',
        lastName: 'มณีรัตน์',
        age: 38,
        department: Department.hr,
        salary: 75000,
        phoneNumber: '085-666-4455',
        skills: ['People Management', 'Recruitment'],
        teamSize: 4,
      ),
      const PermanentEmployee(
        id: 'EMP-007',
        firstName: 'มินท์',
        lastName: 'ทองไทย',
        age: 26,
        department: Department.hr,
        salary: 28000,
        phoneNumber: '094-555-6677',
        skills: ['Sourcing', 'Interviewing'],
        nickname: 'มินท์',
      ),
      const PermanentEmployee(
        id: 'EMP-008',
        firstName: 'กันต์',
        lastName: 'รุ่งโรจน์',
        age: 24,
        department: Department.it,
        salary: 30000,
        phoneNumber: '087-444-5566',
        skills: ['Kotlin', 'Android'],
      ),
      const InternEmployee(
        id: 'EMP-009',
        firstName: 'เฟิร์น',
        lastName: 'วงศ์วิลาศ',
        age: 21,
        department: Department.hr,
        salary: 10000,
        phoneNumber: '093-333-2211',
        skills: ['Excel', 'Onboarding'],
      ),
      const PermanentEmployee(
        id: 'EMP-010',
        firstName: 'เต้ย',
        lastName: 'แสงอรุณ',
        age: 31,
        department: Department.design,
        salary: 48000,
        phoneNumber: '092-222-1100',
        skills: ['Figma', 'Motion Design'],
        nickname: 'เต้ย',
      ),
      const InternEmployee(
        id: 'EMP-011',
        firstName: 'มิ้นท์',
        lastName: 'กลิ่นหอม',
        age: 23,
        department: Department.it,
        salary: 10000,
        phoneNumber: '095-111-0099',
        skills: ['QA', 'Test Cases'],
      ),
      const PermanentEmployee(
        id: 'EMP-012',
        firstName: 'บอส',
        lastName: 'ชัยวัฒน์',
        age: 45,
        department: Department.other,
        salary: 65000,
        phoneNumber: '081-999-8877',
        skills: ['Operations'],
      ),
    ];
  }
}