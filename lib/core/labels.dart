// Thai labels for enum values coming from the database.

const orderStatusLabel = {
  'pending': 'รอร้านรับออเดอร์',
  'accepted': 'ร้านรับออเดอร์แล้ว',
  'cooking': 'กำลังทำอาหาร',
  'ready': 'อาหารพร้อมแล้ว',
  'picked_up': 'ไรเดอร์รับอาหารแล้ว',
  'delivering': 'กำลังไปส่ง',
  'completed': 'สำเร็จ',
  'cancelled': 'ยกเลิก',
};

const paymentStatusLabel = {
  'unpaid': 'ยังไม่ชำระ',
  'slip_uploaded': 'ส่งสลิปแล้ว รอร้านตรวจ',
  'confirmed': 'ชำระแล้ว',
  'rejected': 'สลิปไม่ผ่าน',
};

const paymentMethodLabel = {'promptpay': 'สแกน QR พร้อมเพย์', 'cash': 'เงินสด'};

String baht(double v) => '฿${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';
