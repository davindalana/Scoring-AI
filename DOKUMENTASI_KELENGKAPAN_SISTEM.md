# Dokumentasi Kelengkapan Sistem Archery Scoring AI

Dokumen ini menyajikan audit menyeluruh mengenai arsitektur, kelengkapan fitur, integrasi lintas perangkat (*cross-device*), mekanisme build, dan status verifikasi mutu dari aplikasi **Archery Scoring AI**.

---

## 1. Ringkasan Eksekutif & Arsitektur Sistem

Aplikasi **Archery Scoring AI** adalah sistem manajemen skoring dan analisis tembakan panahan terintegrasi yang mengikuti standar resmi **World Archery (WA)**. Sistem ini menghubungkan tiga lapisan utama:
1. **Perangkat Sensor (Apple Watch - watchOS)**: Mengukur pergerakan pergelangan tangan, akselerasi tarikan busur (*draw*), getaran rilis (*release peak*), dan detak jantung atlet secara *real-time*.
2. **Aplikasi Seluler (iPhone - Flutter/iOS)**: Menyediakan antarmuka skoring taktil, pencatatan otomatis tembakan jam, pemindaian visual target berbasis AI, grafik perkembangan skor, serta penyimpanan lokal (*offline engine*).
3. **Backend & Computer Vision (FastAPI - Python)**: Menyediakan RESTful API, persistensi data sesi MySQL, dan inferensi *computer vision* untuk deteksi anak panah pada bantalan target 10 lingkaran.

```
 +-------------------------------------------------------+
 |             Apple Watch (ArcheryWatchApp)             |
 |  CoreMotion 50Hz + HKWorkoutSession (Background)      |
 |  Deteksi Tembakan Otomatis & Tombol Manual/Reset      |
 +---------------------------+---------------------------+
                             |
                   WatchConnectivity (WCSession)
                   Local Bluetooth / Wi-Fi
                             v
 +-------------------------------------------------------+
 |             iPhone App (Archery Scoring)              |
 |  - Keypad Skoring Taktil WA (X, 10..1, M)             |
 |  - Visualisasi Bantalan Target (10 Cincin Warna)      |
 |  - Offline Scoring Engine & Local Storage (Hive)      |
 |  - Pemindai Target AI (Camera/Gallery)                |
 |  - Grafik Progresif & Scorecard Resmi                 |
 +---------------------------+---------------------------+
                             |
                         HTTP / REST
                             v
 +-------------------------------------------------------+
 |          Backend Server (FastAPI & MySQL)             |
 |  - REST API Atlet, Sesi, End, dan Skoring             |
 |  - Engine Deteksi Target (OpenCV & Roboflow AI)       |
 |  - Basis Data Relasional MySQL (schema.sql)           |
 +-------------------------------------------------------+
```

---

## 2. Kelengkapan Fitur Apple Watch (`mobile_app/ios/ArcheryWatchApp/`)

Modul jam tangan dibangun secara *native* menggunakan **SwiftUI** dan **WatchKit/HealthKit**:

### A. Penginderaan Gerak & Deteksi Rilis Panah
- **Frekuensi Tinggi 50Hz**: Menggunakan `CMMotionManager` untuk menangkap data akselerometer (`userAcceleration`) dan giroskop (`rotationRate`).
- **Eksekusi Latar Belakang (*Background Execution*)**: Mengintegrasikan `HKWorkoutSession` dan `HKLiveWorkoutBuilder` bertipe aktivitas `.archery`. Sensor tetap mengukur pergerakan atlet bahkan saat pergelangan tangan diturunkan (*wrist-down*).
- **Algoritma `ShotDetector`**:
  - Mendeteksi fase tarikan (*draw phase*) selama 1.5–5.0 detik.
  - Mendeteksi lonjakan akselerasi tajam saat rilis tali (*release peak* > 2.0G).
  - Melakukan filter terhadap gerakan palsu (*false positive*) dengan menghitung nilai *confidence*.
- **Pemantauan Detak Jantung**: Membaca sensor optik detak jantung (*Heart Rate*) selama sesi panahan berlangsung.

### B. Antarmuka Jam & Kontrol Atlet
- **Status Bar**: Menampilkan indikator status *Recording* (Hijau), *Synced* (Kuning), atau *Offline* (Abu-abu), serta nomor End yang sedang aktif.
- **Shot Counter Card**: Menampilkan jumlah tembakan terdeteksi, nilai G-force tembakan terakhir, dan persentase *confidence*.
- **Feedback Haptik**: Memberikan getaran haptik instan (`WKInterfaceDevice.current().play(.click)`) saat rilis anak panah terkonfirmasi.
- **Tombol Start / Stop Shooting**: Memulai atau menghentikan sesi latihan dan pengumpulan sensor.
- **Tombol Tembak Manual**: Memungkinkan atlet mencatat tembakan secara manual jika rilis tidak terpicu oleh sensor.
- **Tombol Reset Tembakan**: Mereset counter tembakan kembali ke **0** secara instan kapan saja di tengah sesi dengan notifikasi haptik.

### C. Komunikasi Nirkabel (`WatchSessionManager`)
- **Protokol Dua Arah**: Mengirim *payload* `SHOT_DETECTED` ke iPhone secara instan via `sendMessage`, dengan *fallback* otomatis ke `transferUserInfo` jika koneksi sedang terputus.
- **Remote Commands dari iPhone**: Menerima perintah `START_SESSION`, `END_SESSION`, dan `UPDATE_SESSION_STATE` dari aplikasi ponsel.

---

## 3. Kelengkapan Fitur Mobile App (`mobile_app/`)

Aplikasi seluler dibangun menggunakan **Flutter** dengan arsitektur reaktif berbasis **Provider**:

### A. Alur Skoring & Keypad Standar World Archery
- **Keypad Taktil**: Tombol responsif berukuran besar: `X`, `10`, `9`, `8`, `7`, `6`, `5`, `4`, `3`, `2`, `1`, `M`.
- **Kategori Busur Resmi**:
  - `Recurve` (e.g. 70m)
  - `Compound` (e.g. 50m)
  - `Barebow`
  - `Standard Bow / National`
- **Manajemen End & Arrow**:
  - Pilihan jumlah anak panah per end: 3 atau 6 anak panah.
  - Jumlah end fleksibel: 5, 6, 10, atau 12 end per sesi (Training / Competition).
  - Navigasi End yang mulus (End berikutnya, End sebelumnya, dan konfirmasi simpan).
  - Kemampuan koreksi: Mengetuk slot anak panah mana pun untuk mengoreksi nilai skor secara langsung.

### B. Visualisasi Bantalan Target Panahan
- **Target Face Konsentris Interaktif**:
  - Lingkaran X & 10, 9 (Kuning / Emas).
  - Lingkaran 8 & 7 (Merah).
  - Lingkaran 6 & 5 (Biru).
  - Lingkaran 4 & 3 (Hitam).
  - Lingkaran 2 & 1 (Putih).
- **Plotting Koordinat Anak Panah**: Menampilkan titik impak anak panah pada bantalan target sesuai hasil input manual maupun deteksi AI.

### C. Integrasi Apple Watch (*Platform Channels*)
- **`WatchBridgeManager.swift`**: Menjembatani panggilan native iOS (`WCSession`) ke Flutter melalui `archery/watch_control` (MethodChannel) dan `archery/watch_events` (EventChannel).
- **Auto-Matching Tembakan Jam**: Ketika Apple Watch mendeteksi rilis anak panah, *event* otomatis dipetakan ke slot anak panah yang sedang aktif di layar skoring.

### D. Mode Offline & Mesin Skoring Mandiri
- **`OfflineScoringEngine`**: Menghitung total skor per end, jumlah X, akumulasi total sesi, rata-rata skor per panah/end, serta menentukan end tertinggi dan terendah tanpa ketergantungan server.
- **`LocalStorageService`**: Menggunakan penyimpanan terisolasi untuk menyimpan profil atlet, histori sesi, dan seluruh data end secara persisten di penyimpanan perangkat.
- **Bebas Hambatan Lapangan**: Atlet dapat berlatih di lapangan tanpa sinyal internet; data tetap tersimpan rapi dan dapat disinkronkan saat terhubung kembali.

### E. AI Target Detection
- **Pemindaian Foto Target**: Mengambil foto bantalan target langsung dari kamera atau galeri iPhone.
- **Deteksi Cincin & Titik Impak**: Menghitung jarak relatif titik pusat target (*center*) terhadap anak panah untuk memprediksi perolehan angka.
- **Konfirmasi Atlet**: Hasil prediksi AI disajikan sebagai kandidat angka (`source: 'ai'`); atlet memiliki kendali penuh untuk meninjau dan mengonfirmasi sebelum disimpan.

### F. Ringkasan & Analisis Performa (*Summary*)
- **Statistik Komprehensif**: Total poin, skor maksimal yang mungkin dicapai, persentase akurasi, total X, rata-rata poin per panah, rata-rata poin per end.
- **Grafik Progresi (*Progression Chart*)**: Grafik batang visual perkembangan skor antar end untuk mengevaluasi konsistensi performa atlet.
- **Scorecard Resmi**: Tabel rinci end-by-end yang menyajikan rincian setiap anak panah.

---

## 4. Kelengkapan Fitur Backend & Computer Vision (`Scoring AI/`)

Backend berbasis **FastAPI** dengan arsitektur berlapis (*layered architecture*):

- **Routing & Controller Layer**:
  - `POST /api/athletes` & `GET /api/athletes`: Pendaftaran dan daftar atlet.
  - `POST /api/sessions`: Inisialisasi sesi skoring latihan atau kejuaraan.
  - `GET /api/sessions/{session_id}`: Pengambilan data sesi lengkap dengan statistik kumulatif.
  - `POST /api/sessions/{session_id}/ends`: Penyimpanan skor per-end.
  - `PUT /api/sessions/{session_id}/ends/{end_number}`: Koreksi skor end yang telah tersimpan.
  - `POST /api/sessions/{session_id}/detect`: Analisis citra target panahan via model Computer Vision.
- **Computer Vision Pipeline (`ml/target_detector.py`)**:
  - Deteksi elips/lingkaran target menggunakan segmentasi warna HSV dan *Hough Circle Transform*.
  - Pemetaan koordinat piksel ke zona cincin World Archery (R10 hingga R1).
  - Dukungan ganda: Model cloud Roboflow atau *fallback* lokal OpenCV murni tanpa internet.
- **Persistensi Data (`schema.sql` & `repositories/`)**:
  - Skema relasional yang rapi meliputi tabel `athletes`, `scoring_sessions`, `session_ends`, `arrow_scores`, dan `target_ranges`.

---

## 5. Ringkasan Konfigurasi Build & Deployment

Proyek telah dikonfigurasi untuk pengujian langsung pada perangkat fisik:

1. **Target iOS (`Runner`)**:
   - Bundle Identifier: `com.davindalana.archeryscoring`
   - Mode Kompilasi: **Release (AOT)**
   - Status: Terpasang dan berjalan mandiri (*standalone*) di iPhone `Matane` (iOS 26.3.1).
2. **Target watchOS (`ArcheryWatchApp`)**:
   - Bundle Identifier: `com.davindalana.archeryscoring.watchkitapp`
   - Deployment Target: `watchOS 9.0` (kompatibel penuh dengan watchOS 9, 10, 11, hingga 26.3).
   - Supported Platforms: `watchos watchsimulator`
   - Status: Terdaftar di profil developer, terpasang dan berjalan di **Davin’s Apple Watch** (Apple Watch SE Gen 2).

---

## 6. Verifikasi Mutu & Hasil Pengujian Otomatis

Seluruh pengujian unit dan integrasi (*end-to-end*) berjalan dengan tingkat kelulusan **100%**:

| Komponen Uji | Framework | Jumlah Test | Status |
| :--- | :--- | :---: | :---: |
| **Backend & Scoring Logic** | `pytest` (Python 3.11) | 32 | **32 Passed (100%)** |
| **Mobile App & Watch Event** | `flutter test` (Dart 3.x) | 21 | **21 Passed (100%)** |
| **Total Pengujian Sistem** | | **53** | **53 Passed (100%)** |

### Kasus Uji Utama yang Tervalidasi:
- Parsing skor valid (`X`, `10`, `9`..`1`, `M`) dan penolakan skor tidak valid.
- Perhitungan total skor, X count, dan aturan tie-break sesuai buku aturan World Archery.
- Koreksi skor anak panah pada end sebelumnya dan pembaruan kumulatif otomatis.
- Deteksi duplikasi anak panah dan batas jumlah end.
- Serialisasi model atlet, sesi, anak panah, dan event jam tangan.
- Alur deteksi lingkaran target panahan konsentris.
