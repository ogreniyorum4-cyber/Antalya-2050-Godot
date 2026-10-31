# Antalya 2050

COP31 için hazırlanmış, Godot 4 ile yapılmış 3D iklim dirençli şehir oyunu. Oyuncu Antalya'nın iklim uyum koordinatörüdür: şehirde yürür, parlayan karar noktalarına gider, kararını orada verir ve her karar şehri görünür şekilde değiştirir. Her on yılın sonunda hazırlığa göre zararı değişen bir iklim olayı yaşanır. Oyun Türkçe ve İngilizcedir.

## Projeyi açmak

1. godotengine.org adresinden Godot 4'ü (4.7 veya üstü, "Standard" sürüm) indirin ve açın.
2. Proje Yöneticisi'nde **Import** düğmesine basın, bu klasördeki `project.godot` dosyasını seçin.
3. Proje açılınca sağ üstteki **Run** (▶) düğmesiyle oyunu çalıştırın.

## Kontroller

- WASD / ok tuşları ya da zemine tıklama: yürü
- E / Boşluk / Enter ya da ekrandaki düğme: karar ver

## Web sürümünü yeniden dışa aktarmak

**Project → Export → Web → Export Project** ile `build/web/index.html` olarak dışa aktarın. Godot ilk seferde export template indirmenizi isteyebilir; "Manage Export Templates" üzerinden indirin. Hazır ayar thread desteği kapalı olduğu için itch.io ve GitHub Pages'te ek ayar gerektirmez.

## Dosyalar

- `main.gd`: dünya, karakter, karar noktaları, olay efektleri ve arayüz (her şey kodla oluşturulur, dış varlık yok)
- `data.gd`: kararlar, olaylar ve tüm Türkçe/İngilizce metinler
- `main.tscn`: ana sahne

## Test modları

Web linkinin sonuna `?autoplay` eklenirse oyun kendi kendine oynar (tanıtım videosu kaydı için kullanışlıdır). `?lang=en` İngilizce açar.

Bilgi notlarının kaynakları: MedECC (2020) Akdeniz'de iklim ve çevresel değişim raporu; Dünya Meteoroloji Örgütü, Herkes için Erken Uyarı girişimi. Olaylar ve etkiler eğitsel amaçla basitleştirilmiştir.
