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

/// Food types a shop picks when applying; customers see it under the shop name.
const shopCategories = [
  'อาหารตามสั่ง',
  'ก๋วยเตี๋ยว',
  'ส้มตำ / อาหารอีสาน',
  'ข้าวมันไก่ / ข้าวขาหมู / ข้าวหมูแดง',
  'ปิ้งย่าง / ไก่ทอด / ของทอด',
  'หมูกระทะ / ชาบู',
  'อาหารเช้า / โจ๊ก / ปาท่องโก๋',
  'ขนม / ของหวาน / เบเกอรี่',
  'กาแฟ / ชา / เครื่องดื่ม',
  'ผลไม้',
  'อื่นๆ',
];

const shopStatusLabel = {'pending': 'รออนุมัติ', 'approved': 'อนุมัติแล้ว', 'rejected': 'ไม่ผ่าน'};

const roleLabel = {'customer': 'ลูกค้า', 'shop_owner': 'ร้านค้า', 'rider': 'ไรเดอร์', 'admin': 'แอดมิน'};

/// 0833474363 -> 083-347-4363, for showing a member's phone number.
String phoneLabel(String digits) => digits.length == 10
    ? '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}'
    : digits;
