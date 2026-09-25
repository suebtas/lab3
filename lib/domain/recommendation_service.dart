import 'models/department.dart';

final class RecommendationService {
  const RecommendationService();

  String getRecommendationText(Department dept) {
    switch (dept) {
      case Department.it:
        return 'ส่งเข้ารับการอบรม Cybersecurity เพื่อป้องกันภัยระบบ';
      case Department.hr:
        return 'ส่งเข้าร่วมสัมมนาการสรรหาบุคลากรยุคใหม่';
      case Department.design:
        return 'ส่งเข้าเวิร์กชอป UI/UX Trend';
      case Department.other:
        return 'ปฐมนิเทศพนักงานทั่วไป';
    }
  }
}