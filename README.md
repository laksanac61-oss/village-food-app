# สั่งอาหารในหมู่บ้าน (village-food-app)

แอปสั่งอาหารสำหรับร้านในหมู่บ้าน ใช้โค้ดชุดเดียวได้ทั้งแอป Android และเว็บแอป (ลูกค้า iOS เปิดผ่าน Safari แล้วกด "เพิ่มไปยังหน้าจอโฮม")

- **ลูกค้า**: ดูร้าน, สั่งอาหาร, เลือกให้ไรเดอร์ส่งหรือรับเอง, สแกน QR พร้อมเพย์ที่ใส่ยอดเงินให้อัตโนมัติ, แนบสลิป, ติดตามสถานะ
- **ร้านค้า**: เปิด/ปิดร้าน, จัดการเมนูและของหมด, รับออเดอร์, ตรวจสลิป, อัปเดตสถานะ
- **ไรเดอร์**: สมัครพร้อมรูปบัตรและรูปถ่าย, รอแอดมินอนุมัติ, ออนไลน์รับงาน (คนแรกที่กดได้งาน), อัปเดตการส่ง, ลูกค้าสแกนจ่ายค่าส่งเข้าพร้อมเพย์ไรเดอร์ได้
- **ผู้ดูแลระบบ**: เพิ่ม/ระงับร้าน, อนุมัติ/ระงับไรเดอร์, ตั้งค่าส่งตามโซน

ไม่ใช้ payment gateway: เงินโอนตรงเข้าพร้อมเพย์ของร้านและไรเดอร์ ไม่มีค่าธรรมเนียม

## เทคโนโลยี

- Flutter (`lib/`) สำหรับ Android, เว็บ และ iOS
- Supabase (ฐานข้อมูล, ล็อกอิน, เก็บรูป, อัปเดตเรียลไทม์) แพ็กเกจฟรีเพียงพอช่วงเริ่ม
- กติกาความปลอดภัยอยู่ในฐานข้อมูล (`supabase/migrations/0001_init.sql`): ยอดเงินคำนวณที่เซิร์ฟเวอร์, แต่ละบทบาทเปลี่ยนสถานะออเดอร์ได้เฉพาะขั้นของตัวเอง, เฉพาะแอดมินอนุมัติไรเดอร์และเปลี่ยนบทบาทได้

## ตั้งค่าครั้งแรก

1. สมัคร [Supabase](https://supabase.com) แล้วสร้างโปรเจกต์ใหม่ (เลือก region Singapore)
2. เปิด **SQL Editor** วางเนื้อหาไฟล์ใน `supabase/migrations/` ทีละไฟล์ตามลำดับเลข (`0001_init.sql`, `0002_rider_map.sql`, ...) แล้วกด Run ทุกไฟล์
3. ไปที่ **Authentication → Providers → Email** ปิด "Confirm email" ถ้าไม่ต้องการให้ยืนยันอีเมล
4. คัดลอก **Project URL** และ **anon / publishable key** จาก Project Settings → API
5. รันแอป แล้วสมัครสมาชิกด้วยบัญชีของคุณเอง
6. ตั้งตัวเองเป็นแอดมิน: ใน SQL Editor รัน
   ```sql
   update profiles set role = 'admin' where phone = 'เบอร์ของคุณ';
   ```
7. ในแอป (หน้าแอดมิน) เพิ่มโซนค่าส่ง และเพิ่มร้านค้า โดยให้เจ้าของร้านสมัครสมาชิกในแอปก่อน แล้วใช้เบอร์ที่เขาสมัคร

## สมาชิกลืมรหัสผ่าน

สมาชิกสมัครด้วยเบอร์โทร (ระบบเก็บเป็นอีเมลภายใน `เบอร์@cozy-melomakarona-cafbc6.netlify.app` ไม่มีการส่งอีเมลจริง) ถ้าลืมรหัสผ่าน แอดมินตั้งรหัสใหม่ให้ได้ใน SQL Editor:

```sql
update auth.users
   set encrypted_password = extensions.crypt('รหัสใหม่', extensions.gen_salt('bf'))
 where email = '0812345678@cozy-melomakarona-cafbc6.netlify.app';
```

## รันและสร้างแอป

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxxx

# เว็บแอป (นำโฟลเดอร์ build/web ไปวางบน Netlify / Vercel / Firebase Hosting ได้ฟรี)
flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# ไฟล์ติดตั้ง Android
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## ทดสอบ

```bash
flutter analyze && flutter test   # รวมการทดสอบ QR พร้อมเพย์
scripts/test_db.sh                # โหลดฐานข้อมูลลง Postgres ชั่วคราวแล้วทดสอบขั้นตอนสั่ง-ส่งทั้งหมด
```

## สิ่งที่ยังไม่มี (ช่วงถัดไป)

- แจ้งเตือน push เมื่อมีออเดอร์ใหม่ (ตอนนี้หน้าจออัปเดตเองแบบเรียลไทม์ขณะเปิดแอปอยู่)
- ล็อกอินด้วย OTP ทาง SMS หรือ LINE (ตอนนี้ใช้เบอร์โทรและรหัสผ่าน ซึ่งฟรี)
- ตรวจสลิปอัตโนมัติ, รีวิว, รายงานยอดขาย
