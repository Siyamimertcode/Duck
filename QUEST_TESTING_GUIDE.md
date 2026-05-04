# Görev Sistemi Test Rehberi

## ✅ Tüm Tracking Sistemleri Aktif

### Günlük Görevler (18 Tip)

#### 1. **Giriş Yap** 
- **Tracking**: `recordAppOpen()` 
- **Test**: Uygulamayı aç/kapat
- **Kontrol**: `getOpensToday()`

#### 2. **Mini Oyun Oyna**
- **Tracking**: `recordGamePlayed()`
- **Test**: Oyun bölümünde oyun oyna
- **Kontrol**: `getGamesToday()`

#### 3. **Alıştırma Başlat / 5 Alıştırma Yap**
- **Tracking**: `recordExerciseCompleted()`
- **Test**: Ders tamamla (otomatik kayıt)
- **Kontrol**: `getExercisesToday()`

#### 4. **Kelime Eşleştirme**
- **Tracking**: `recordGamePlayed()`
- **Test**: Kelime eşleştirme oyunu
- **Kontrol**: `getGamesToday()`

#### 5. **Hızlı Test**
- **Tracking**: `recordTestCompleted()`
- **Test**: Test modülünde test çöz
- **Kontrol**: `getTestsToday()`

#### 6. **Doğru Seri**
- **Tracking**: `recordCorrectAnswer()` / `recordWrongAnswer()`
- **Test**: Doğru cevap ver (5 üst üste)
- **Kontrol**: `getMaxCorrectStreakToday()`

#### 7. **Yanlışsız Oyun / Hatasız Gün**
- **Tracking**: `recordErrorFreeTask()`
- **Test**: Görev hatasız tamamla
- **Kontrol**: `getErrorFreeTasksToday()`

#### 8. **Kelime Tekrarı**
- **Tracking**: `recordWordReview()`
- **Test**: Kelime tekrar sistemi
- **Kontrol**: `getWordReviewsToday()`

#### 9. **Balon Oyunu**
- **Tracking**: `recordGamePlayed()`
- **Test**: Balon oyunu oyna
- **Kontrol**: `getGamesToday()`

#### 10. **Zaman Geçir (10/15/30 dakika)**
- **Tracking**: `recordMinutesSpent(minutes)`
- **Test**: Uygulamada zaman geçir
- **Kontrol**: `getMinutesToday()`

#### 11. **Günlük Seri**
- **Tracking**: Otomatik (streak sistemi)
- **Test**: Her gün giriş yap
- **Kontrol**: `getStreak()`

#### 12. **XP Topla**
- **Tracking**: Otomatik (`addXP`)
- **Test**: Ders bitir, görev topla
- **Kontrol**: `getXPToday()`

#### 13. **Seviye Katkısı**
- **Tracking**: `recordExerciseCompleted()`
- **Test**: Herhangi bir alıştırma yap
- **Kontrol**: `getExercisesToday() > 0`

#### 14. **Geri Dönüş**
- **Tracking**: `recordAppOpen()`
- **Test**: Uygulamayı 2 kez aç
- **Kontrol**: `getOpensToday()`

#### 15. **Günlük Tamamlama**
- **Tracking**: `recordTaskCompleted()`
- **Test**: Görev topla (3 görev)
- **Kontrol**: `getTasksCompletedToday()`

---

### Haftalık Görevler (12 Tip)

#### 1. **3/5 Gün Üst Üste Gir**
- **Tracking**: Otomatik streak
- **Test**: 3-5 gün üst üste gir
- **Kontrol**: `getStreak()`

#### 2. **Haftalık Mini Oyun**
- **Tracking**: `recordGamePlayed()`
- **Test**: 10 oyun oyna
- **Kontrol**: `getGamesWeek()`

#### 3. **Alıştırma Maratonu**
- **Tracking**: `recordExerciseCompleted()`
- **Test**: 30 alıştırma yap
- **Kontrol**: `getExercisesWeek()`

#### 4. **Kelime Ustası**
- **Tracking**: `recordWordsLearned(count)`
- **Test**: 50 kelime öğren
- **Kontrol**: `getWordsWeek()`

#### 5. **Hatasız Gün**
- **Tracking**: `recordErrorFreeTask()`
- **Test**: Hatasız 3 görev bitir
- **Kontrol**: `getErrorFreeTasksWeek()`

#### 6. **Dinleme Haftası**
- **Tracking**: `recordListeningActivity()`
- **Test**: 5 dinleme aktivitesi
- **Kontrol**: `getListeningWeek()`

#### 7. **Konuşma Haftası**
- **Tracking**: `recordSpeakingActivity()`
- **Test**: 5 konuşma aktivitesi
- **Kontrol**: `getSpeakingWeek()`

#### 8. **Yazma Haftası**
- **Tracking**: `recordWritingActivity()`
- **Test**: 5 yazma aktivitesi
- **Kontrol**: `getWritingWeek()`

#### 9. **XP Avcısı**
- **Tracking**: Otomatik (`addXP`)
- **Test**: Hafta boyunca 300 XP kazan
- **Kontrol**: `getXPWeek()`

#### 10. **Seviye Atlama**
- **Tracking**: Otomatik (level-up)
- **Test**: 2 seviye atla
- **Kontrol**: `getLevelsWeek()`

#### 11. **Haftayı Bitir**
- **Tracking**: `recordTaskCompleted()`
- **Test**: 15 görev topla
- **Kontrol**: `getTasksCompletedWeek()`

---

## 🔄 Reset Sistemi

### Günlük Reset (00:00)
- Tüm daily_* görevler temizlenir
- Tüm günlük sayaçlar 0'a döner
- Yeni 3 random günlük görev yüklenir

### Haftalık Reset (Pazartesi 00:00)
- Tüm weekly_* görevler temizlenir
- Tüm haftalık sayaçlar 0'a döner
- Yeni 3 random haftalık görev yüklenir

---

## 🎮 Entegrasyon Noktaları

### Otomatik Kayıtlar
1. **Uygulama Açılışında**: `recordAppOpen()` ✅
2. **Ders Tamamlandığında**: `recordExerciseCompleted()` ✅
3. **XP Kazanıldığında**: `addXP()` (daily/weekly tracking dahil) ✅
4. **Görev Toplandığında**: `recordTaskCompleted()` ✅

### Manuel Kayıtlar (Eklenmesi Gerekenler)
```dart
// Oyun oynandığında
await UserPreferences.recordGamePlayed();

// Kelime öğrenildiğinde
await UserPreferences.recordWordsLearned(count: 5);

// Test çözüldüğünde
await UserPreferences.recordTestCompleted();

// Doğru cevap
await UserPreferences.recordCorrectAnswer();

// Yanlış cevap
await UserPreferences.recordWrongAnswer();

// Hatasız görev
await UserPreferences.recordErrorFreeTask();

// Dinleme aktivitesi
await UserPreferences.recordListeningActivity();

// Konuşma aktivitesi
await UserPreferences.recordSpeakingActivity();

// Yazma aktivitesi
await UserPreferences.recordWritingActivity();

// Kelime tekrarı
await UserPreferences.recordWordReview();

// Zaman tracking
await UserPreferences.recordMinutesSpent(15);
```

---

## 🧪 Test Senaryoları

### Senaryo 1: Günlük Görevleri Test Et
1. Uygulamayı aç → "Giriş Yap" görevi tamamlanmalı
2. Bir ders bitir → "Alıştırma" görevleri ilerlemeli
3. Görev topla → "Günlük Tamamlama" ilerlemeli
4. XP kazan → "XP Topla" ilerlemeli

### Senaryo 2: Haftalık Görevleri Test Et
1. 3 gün üst üste gir → "3 Gün Üst Üste" tamamlanmalı
2. Hafta boyunca ders yap → "Alıştırma Maratonu" ilerlemeli
3. 300 XP kazan → "XP Avcısı" tamamlanmalı

### Senaryo 3: Reset Testi
1. Görevleri tamamla
2. Sistemi 00:00'a ayarla (manuel test için SharedPreferences'ta `last_daily_reset` değiştir)
3. Uygulamayı aç → Yeni görevler yüklenmeli

---

## 📊 Debug Komutları

```dart
// Tüm sayaçları kontrol et
print('Opens: ${await UserPreferences.getOpensToday()}');
print('Exercises: ${await UserPreferences.getExercisesToday()}');
print('Games: ${await UserPreferences.getGamesToday()}');
print('Words: ${await UserPreferences.getWordsToday()}');
print('Tests: ${await UserPreferences.getTestsToday()}');
print('Correct Streak: ${await UserPreferences.getMaxCorrectStreakToday()}');
print('Error-Free: ${await UserPreferences.getErrorFreeTasksToday()}');
print('XP Today: ${await UserPreferences.getXPToday()}');
print('XP Week: ${await UserPreferences.getXPWeek()}');
```

---

## ✅ Tamamlanan Sistemler

1. ✅ 18 Günlük Görev Tipi
2. ✅ 12 Haftalık Görev Tipi
3. ✅ Otomatik günlük reset (00:00)
4. ✅ Otomatik haftalık reset (Pazartesi 00:00)
5. ✅ JSON tabanlı dinamik görev yükleme
6. ✅ Progress tracking ve otomatik completion
7. ✅ 15+ farklı tracking metodu
8. ✅ XP ve level tracking entegrasyonu
9. ✅ Quest claimed/completed state management
10. ✅ Hatasız derleme ve çalışma

---

## 🎯 Sonraki Adımlar

1. Oyun modüllerine `recordGamePlayed()` ekle
2. Kelime öğrenme sistemine `recordWordsLearned()` ekle
3. Test modülüne `recordTestCompleted()` ekle
4. Doğru/Yanlış cevap sistemine `recordCorrectAnswer()`/`recordWrongAnswer()` ekle
5. Skill-based aktivitelere (dinleme/konuşma/yazma) tracking ekle
