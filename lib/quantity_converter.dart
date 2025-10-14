// lib/model/quantity_converter.dart
class QuantityConverter {
  /// แปลงค่าปริมาณเป็น "กิโลกรัม"
  /// รองรับ: kg, g/gram, ขีด, hg, lb, piece(ชิ้น) -> ต้องกำหนด weightPerPieceKg ถ้าจะใช้
  static double toKg(double value, String unit, {double? weightPerPieceKg}) {
    final u = unit.trim().toLowerCase();
    switch (u) {
      case 'kg':
      case 'กก':
      case 'กิโล':
        return value;
      case 'g':
      case 'gram':
      case 'กรัม':
        return value / 1000.0;
      case 'hg':
      case 'ขีด': // 1 ขีด = 0.1 kg
        return value * 0.1;
      case 'lb':
      case 'pound':
        return value * 0.45359237;
      case 'piece':
      case 'ชิ้น':
        // ถ้าจะรองรับชิ้น ต้องบอกน้ำหนักต่อชิ้น
        if (weightPerPieceKg == null) {
          // ไม่มีน้ำหนักต่อชิ้นให้ถือว่า 1 ชิ้น = 1 kg (หรือเปลี่ยนเป็น 0 ก็ได้)
          return value * 1.0;
        }
        return value * weightPerPieceKg;
      default:
        // หน่วยไม่รู้จัก — คืนค่าตามเดิม (ถือเป็น kg)
        return value;
    }
  }
}
