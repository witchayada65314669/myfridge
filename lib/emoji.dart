String getEmojiFromProductName(String name) {
  final lower = name.toLowerCase();

  // 🐷 หมูทั้งหมดใช้ emoji เดียว
  if (_matchAny(lower, [
    'หมู',
    'สันใน',
    'สันนอก',
    'สะโพก',
    'ไหล่',
    'หัวไหล่',
    'ซี่โครง',
    'สามชั้น',
    'ขาหมู',
    'หูหมู',
    'จมูก',
    'หาง',
    'ลิ้น',
    'หน้ากาก',
    'เครื่องในหมู',
  ]))
    return '🐷';

  // 🐄 เนื้อวัวทั้งหมดใช้ emoji เดียว
  if (_matchAny(lower, [
    'เนื้อ',
    'ใบพาย',
    'อกวัว',
    'น่อง',
    'หัวไหล่',
    'สันในเนื้อ',
    'สันนอกเนื้อ',
    'สะโพกเนื้อ',
  ]))
    return '🐄';

  // 🐟 อาหารทะเลแยกตามชนิด
  if (lower.contains('ปลา')) return '🐟';
  if (lower.contains('กุ้ง')) return '🦐';
  if (lower.contains('ปู')) return '🦀';
  if (lower.contains('หอย')) return '🐚';
  if (lower.contains('ปลาหมึก')) return '🦑';

  // 🥦 ผัก
  if (lower.contains('คะน้า')) return '🥬';
  if (lower.contains('กะหล่ำ')) return '🥬';
  if (lower.contains('ผักบุ้ง') || lower.contains('ผักชี')) return '🌿';
  if (lower.contains('ต้นหอม') || lower.contains('หัวหอม')) return '🧅';
  if (lower.contains('แครอท')) return '🥕';
  if (lower.contains('บร็อค')) return '🥦';
  if (lower.contains('แตงกวา')) return '🥒';
  if (lower.contains('มะเขือ')) return '🍅';
  if (lower.contains('พริก')) return '🌶️';
  if (lower.contains('ขิง')) return '🫚';
  if (lower.contains('กระเทียม')) return '🧄';

  // 🍎 ผลไม้
  if (lower.contains('แอปเปิ้ล')) return '🍎';
  if (lower.contains('กล้วย')) return '🍌';
  if (lower.contains('ส้ม')) return '🍊';
  if (lower.contains('องุ่น')) return '🍇';
  if (lower.contains('มะม่วง')) return '🥭';
  if (lower.contains('สับปะรด')) return '🍍';
  if (lower.contains('แตงโม')) return '🍉';
  if (lower.contains('ลิ้นจี่') || lower.contains('เงาะ')) return '🍒';
  if (lower.contains('ชมพู่') || lower.contains('ฝรั่ง')) return '🍐';
  if (lower.contains('มังคุด')) return '🍈';
  if (lower.contains('ทุเรียน')) return '🟡';

  return '🍽️'; // fallback
}

bool _matchAny(String text, List<String> keywords) {
  return keywords.any((kw) => text.contains(kw));
}
