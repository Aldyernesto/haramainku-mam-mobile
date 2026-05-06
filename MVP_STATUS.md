# HaramainKU MAM Mobile — MVP Status

> **Tanggal**: 6 Mei 2026
> **Status**: MVP COMPLETE

---

## Yang Sudah Berfungsi

- Login/Signup email via GraphQL ✅
- Home Netflix-style project cards ✅
- Create project (bottom sheet + cover picker) ✅
- Upload chunked REST multipart + progress bar ✅
- Download stream + auto-save to Gallery ✅
- File preview dialog (Download/Share/Trash) ✅
- Folder navigation (tap → sub-folders + files) ✅
- Multi-select (checkbox + bulk actions) ✅
- Move file/folder (folder picker) ✅
- QR Scanner (mobile_scanner camera) ✅
- Global Chat tab (all messages feed) ✅
- @ mention tagging `@[type:id:name]` clickable ✅
- Settings → Linked Devices (list + disconnect) ✅
- RBAC: Trash hidden for EDITOR/CREW ✅
- Role badge di chat ✅
- Search (real GraphQL backend) ✅
- Per-folder file type rules ✅

## Build & Deploy

```bash
# CLEAN BUILD (wajib tiap deploy):
rm -rf build .dart_tool && flutter clean && flutter pub get && flutter build apk --debug

# Install & launch:
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n com.haramainku.haramainku_mam/.MainActivity
```

## Known Issues
- Perlu kotlin.incremental=false di gradle.properties (cross-drive C:/D:)
- iOS build belum di-test
- Push notification belum aktif
