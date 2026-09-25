import 'models/department.dart';
import 'models/employee_model.dart';
import 'payroll_engine.dart';

final class PayrollSummaryEntity {
  PayrollSummaryEntity({required this.records, PayrollEngine? engine})
      : _engine = engine ?? const PayrollEngine();

  final List<PayrollRecord> records;
  final PayrollEngine _engine;

  int get totalActiveEmployees => records.length;

  int get totalSalaryExpenses {
    var sum = 0;
    for (final record in records) {
      sum += record.employee.salary;
    }
    return sum;
  }

  int get totalBonusExpenses {
    var sum = 0;
    for (final record in records) {
      sum += record.bonus;
    }
    return sum;
  }

  int get grandTotalExpenses => totalSalaryExpenses + totalBonusExpenses;

  int get totalTaxWithheld {
    var sum = 0;
    for (final record in records) {
      sum += record.tax;
    }
    return sum;
  }

  int countByType(String typeLabel) {
    return records
        .where((record) => record.employee.type.label == typeLabel)
        .length;
  }

  int departmentExpense(Department department) {
    var sum = 0;
    for (final record in records) {
      if (record.employee.department == department && department != Department.other) {
        sum += record.employee.salary + record.bonus;
      }
    }
    return sum;
  }

  PayrollSummaryEntity recompute(List<Employee> employees) {
    return PayrollSummaryEntity(
      records: _engine.evaluateAll(employees),
      engine: _engine,
    );
  }

  factory PayrollSummaryEntity.fromEmployees(
    List<Employee> employees, {
    PayrollEngine engine = const PayrollEngine(),
  }) {
    return PayrollSummaryEntity(records: engine.evaluateAll(employees), engine: engine);
  }
}