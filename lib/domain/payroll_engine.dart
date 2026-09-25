import 'models/employee_model.dart';
import 'models/employee_type.dart';

const int bonusThresholdSalary = 30000;
const int bonusPercentOnOrBelow = 10;
const int bonusPercentAbove = 5;
const int internTaxBaseSalary = 10000;
const int internTaxPercent = 1;
const int standardTaxPercent = 3;

final class PayrollRecord {
  const PayrollRecord({
    required this.employee,
    required this.bonus,
    required this.tax,
    required this.netPay,
  });

  final Employee employee;
  final int bonus;
  final int tax;
  final int netPay;
}

final class PayrollEngine {
  const PayrollEngine();

  int calculateBonus(Employee employee) {
    final salary = employee.salary;
    if (salary <= bonusThresholdSalary) {
      return salary * bonusPercentOnOrBelow ~/ 100;
    }
    return salary * bonusPercentAbove ~/ 100;
  }

  int calculateTax(Employee employee) {
    if (employee.type == EmployeeType.intern) {
      return (internTaxBaseSalary * internTaxPercent ~/ 100).round();
    }
    return employee.salary * standardTaxPercent ~/ 100;
  }

  PayrollRecord evaluate(Employee employee) {
    final bonus = calculateBonus(employee);
    final tax = calculateTax(employee);
    return PayrollRecord(
      employee: employee,
      bonus: bonus,
      tax: tax,
      netPay: employee.salary + bonus - tax,
    );
  }

  List<PayrollRecord> evaluateAll(List<Employee> employees) {
    return employees.map(evaluate).toList();
  }
}