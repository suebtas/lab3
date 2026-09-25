enum EmployeeType {
  permanent('พนักงานประจำ'),
  intern('เด็กฝึกงาน'),
  manager('ผู้จัดการ');

  const EmployeeType(this.label);

  final String label;
}