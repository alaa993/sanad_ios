# Sanad iOS (SwiftUI)

## نظرة عامة
تطبيق Sanad iOS يستخدم SwiftUI وURLSession للتعامل مع APIs المستندة إلى Laravel، ويركب Socket.IO (실 WebSocket) لمزامنة المحادثات والمجتمع والجلسات في الوقت الحقيقي.

## التبعيات
- تعتمد الوحدة على Swift packages الداخلية لـ LiveKit وSanadUI (تُدار داخل مشروع Xcode). لا توجد مكتبات خارجية إضافية للـ Socket، لأننا نستخدم `URLSessionWebSocketTask` المدمجة.
- يجب تثبيت حزمة `LiveKit` عبر Xcode إذا لم تُضمّن بعد (راجع `Package Dependencies`).

## إعداد الوقت الحقيقي
1. شغّل `realtime-server` عبر `npm install && npm run start` (أو `npm run dev` أثناء التطوير). تأكد من ضبط المتغيرات `PORT`, `SOCKET_PATH`, `SOCKET_ALLOWED_ORIGINS` إذا تغيرت.
2. اضبط `AppConfig.BASE_URL` ليشير إلى عنوان السيرفر (يُنفّذ اتصال الـ Socket إلى `BASE_URL/socket/?...`).
3. عند تسجيل الدخول، `AuthViewModel` تستدعي `RealtimeSocket.shared.connect`، وتُعيد الاتصال عند تجديد المستخدم أو إعادة المصادقة.
4. إذا كنت بحاجة إلى تتبع أحداث خاصة (مثلاً `community:post` أو `session:status`)، تابع الموضوعات في `RealtimeSocket.events` واستخدم `Combine` لربطها بالشاشات.

## الفوترة والتقارير
- تستخدم `BillingService` النقاط النهائية `v1/billing/*` لعرض الخطط، الفواتير، المعاملات، واشتراك/إلغاء الخطط.
- تعرض `WalletView` هذه البيانات مع التحكم في الاشتراكات وأزرار التحميل.
- تُستخدم `ReportsService` لقراءة `v1/reports/overview` وجلب مؤشرات النظام العامة، ما يعرض في `ReportsView` ضمن التبويت.

## إدارة المصادقة والرمز
- `KeychainHelper` يخزن التوكن في Keychain، ويتم استرجاعه عبر `KeychainHelper.getToken()` في كافة الخدمات.
- `AuthViewModel.bootstrap()` يُعيد تأكيد المستخدم+الدور ويستأنف الاتصال بـ Socket.IO عند إعادة فتح التطبيق.
- إذا أردت إعادة تعيين التوكن، استعمل `KeychainHelper.clearToken()` ومن ثم `AuthViewModel.logout()`.

## تشغيل الكود
1. افتح `SanadApp.xcodeproj` وشيّل الـ target للـ simulator.
2. ضمن `SanadApp/App/SanadApp.swift`، تأكد أن `AuthGate` هو `@main` entry.
3. شغّل الـ backend (`httpdocs`) و`realtime-server` قبل بدء التطبيق حتى تتوفر الـ APIs والـ WebSocket.

## اختبارات ومتابعة
- لا توجد اختبارات آلية حالية، فراجع كل وسيلة عبر تشغيل التطبيق، تسجيل الدخول، التحقق من الجلسات، المجتمعات، الدردشة، والفوترة.
- استخدم الـ Console log عند الحاجة (`RealtimeSocket` يرسل reconnect attempts) وراجع `service` errors.
