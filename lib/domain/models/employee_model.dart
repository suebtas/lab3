import 'department.dart';
import 'employee_type.dart';

abstract class Employee {
  const Employee({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.department,
    required this.salary,
    required this.phoneNumber,
    required this.skills,
    this.nickname,
    this.backupPhoneNumber,
  });

  final String id;
  final String firstName;
  final String lastName;
  final int age;
  final Department department;
  final int salary;
  final String phoneNumber;
  final List<String> skills;
  final String? nickname;
  final String? backupPhoneNumber;

  EmployeeType get type;

  String get nicknameLabel => nickname ?? 'ไม่ได้ระบุ';

  String get backupPhoneLabel => backupPhoneNumber ?? 'ไม่ได้ระบุ';

  String get fullName => '$firstName $lastName';

  factory Employee.fromType(
    EmployeeType type, {
    required String id,
    required String firstName,
    required String lastName,
    required int age,
    required Department department,
    required int salary,
    required String phoneNumber,
    required List<String> skills,
    String? nickname,
    String? backupPhoneNumber,
    int teamSize = 0,
  }) {
    return switch (type) {
      EmployeeType.permanent => PermanentEmployee(
          id: id,
          firstName: firstName,
          lastName: lastName,
          age: age,
          department: department,
          salary: salary,
          phoneNumber: phoneNumber,
          skills: skills,
          nickname: nickname,
          backupPhoneNumber: backupPhoneNumber,
        ),
      EmployeeType.intern => InternEmployee(
          id: id,
          firstName: firstName,
          lastName: lastName,
          age: age,
          department: department,
          salary: salary,
          phoneNumber: phoneNumber,
          skills: skills,
          nickname: nickname,
          backupPhoneNumber: backupPhoneNumber,
        ),
      EmployeeType.manager => ManagerEmployee(
          id: id,
          firstName: firstName,
          lastName: lastName,
          age: age,
          department: department,
          salary: salary,
          phoneNumber: phoneNumber,
          skills: skills,
          nickname: nickname,
          backupPhoneNumber: backupPhoneNumber,
          teamSize: teamSize,
        ),
    };
  }
}

class PermanentEmployee extends Employee {
  const PermanentEmployee({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.age,
    required super.department,
    required super.salary,
    required super.phoneNumber,
    required super.skills,
    super.nickname,
    super.backupPhoneNumber,
  });

  @override
  EmployeeType get type => EmployeeType.permanent;
}

class InternEmployee extends Employee {
  const InternEmployee({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.age,
    required super.department,
    required super.salary,
    required super.phoneNumber,
    required super.skills,
    super.nickname,
    super.backupPhoneNumber,
  });

  @override
  EmployeeType get type => EmployeeType.intern;
}

class ManagerEmployee extends Employee {
  const ManagerEmployee({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.age,
    required super.department,
    required super.salary,
    required super.phoneNumber,
    required super.skills,
    super.nickname,
    super.backupPhoneNumber,
    required this.teamSize,
  });

  final int teamSize;

  @override
  EmployeeType get type => EmployeeType.manager;
}