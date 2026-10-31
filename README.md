# Antalya 2050

COP31 için hazırlanmış, Godot 4 ile yapılmış 3D iklim dirençli şehir oyunu. Oyuncu Antalya'nın iklim uyum koordinatörüdür: şehirde yürür, parlayan karar noktalarına gider, oradaki düğmeye basarak kararını verir ve her karar şehri görünür şekilde değiştirir. Oyun 2026'dan 2050'ye kadar beş yıllık 5 dönemden ve 15 karardan oluşur; her dönemin sonunda hazırlığa göre zararı değişen bir iklim olayı yaşanır. Oyun Türkçe ve İngilizcedir.

## Oyun döngüsü

- **Beş gösterge:** Su, Sağlık, Ekonomi, Doğa ve Halk Refahı. Sonuçtaki dayanıklılık puanı bunların ortalamasıdır.
- **Yeşil Bütçe:** Her dönem gelir getirir; gelir altın olarak hazineye akar; güneş enerjisi, dört mevsim turizm, sıfır atık gibi kararlar ve teknolojiler geliri artırır.
- **Eko-XP:** Her karar ve afetlerden çıkarılan dersler XP kazandırır; kristaller sayaca uçar.
- **Konular:** iklim dirençli şehir, su, sıcak, yangın, sel, gıda güvenliği, enerji, ulaşım ve karbon ayak izi, bilinçli tüketim, deniz, sıfır atık, adil geçiş, erken uyarı ve COP31 iklim planı.
- **Teknoloji ağacı (T tuşu):** Su, Doğa ve Toplum dallarında 9 teknik (Likya sarnıçları, Toros rüzgâr koridorları, adil geçiş programı, deniz çayırı restorasyonu vb.). Her teknik olay zararını azaltır ya da geliri artırır ve şehre görünür bir yapı ekler.

## Projeyi açmak

1. godotengine.org adresinden Godot 4'ü (4.7 veya üstü, "Standard" sürüm) indirin ve açın.
2. Proje Yöneticisi'nde **Import** düğmesine basın, bu klasördeki `project.godot` dosyasını seçin.
3. Proje açılınca sağ üstteki **Run** (▶) düğmesiyle oyunu çalıştırın.

## Kontroller

- WASD / ok tuşları ya da zemine tıklama: yürü
- E / Boşluk / Enter ya da ekrandaki düğme: karar ver
- T ya da sağ alttaki düğme: teknoloji ağacı
- Esc ya da sağ üstteki Menü düğmesi: duraklat (devam et, nasıl oynanır, yeniden başla, ana menü, ses, tam ekran, çıkış)

## Web sürümünü yeniden dışa aktarmak

**Project → Export → Web → Export Project** ile `build/web/index.html` olarak dışa aktarın. Godot ilk seferde export template indirmenizi isteyebilir; "Manage Export Templates" üzerinden indirin. Hazır ayar thread desteği kapalı olduğu için itch.io ve GitHub Pages'te ek ayar gerektirmez.

## Dosyalar

- `main.gd`: dünya, karakter, karar noktaları, olay efektleri ve arayüz (her şey kodla oluşturulur, dış varlık yok)
- `data.gd`: kararlar, olaylar ve tüm Türkçe/İngilizce metinler
- `main.tscn`: ana sahne
- `music/`: ana tema, olay ve final müzikleri (Suno, ücretli abonelik)

## Test modları

Oyun açıkken **F9** tuşu tanıtım modunu açar/kapatır: oyun kendi kendine yürür, karar verir ve teknoloji öğrenir (tanıtım videosu kaydı için). itch.io dahil her yerde çalışır. Oyunun kendi sayfasında linkin sonuna `?autoplay` eklemek de aynı işi yapar, `?lang=en` İngilizce açar.

## Müzik

Oyundaki üç müzik parçası (Ana tema "Antalya 2050", olay müziği "Toroslar'da Fırtına" ve final müziği "Dirençli Şehir") Suno ile, ücretli abonelik kapsamında üretilmiştir. Suno'nun ücretli plan koşulları bu parçalar için ticari kullanım hakkı tanır. Dosyalar `music/` klasöründedir.

Bilgi notlarının kaynakları: MedECC (2020) Akdeniz'de iklim ve çevresel değişim raporu; Dünya Meteoroloji Örgütü, Herkes için Erken Uyarı girişimi. Olaylar ve etkiler eğitsel amaçla basitleştirilmiştir.
