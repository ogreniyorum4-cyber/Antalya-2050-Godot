extends RefCounted
## Antalya 2050 - oyun verisi (kararlar, olaylar, metinler). TR/EN.

const KEYS := ["w", "h", "e", "n"]

const UI := {
	"tr": {
		"sub": "COP31 · İklim dirençli şehir oyunu",
		"start": "Oyuna başla", "w": "Su", "h": "Sağlık", "e": "Ekonomi", "n": "Doğa",
		"budget": "Bütçe", "unit": "kaynak",
		"period": ["Bugün - 2030", "2030 - 2040", "2040 - 2050"],
		"reach": ["2030'a gelindi", "2040'a gelindi", "2050'ye gelindi"],
		"tasks": "Bu on yılın görevleri", "done": "tamam",
		"controls": "WASD / ok tuşları ya da zemine tıkla: yürü   ·   E: karar ver",
		"prompt": "Karar ver", "follow": "Oku takip et, parlayan halkaya yürü.",
		"choose": "Seç", "notEnough": "Bütçe yetmiyor", "disc": "Erken yatırım indirimi",
		"prot": "Koruma", "risk": "Risk artar", "later": "Gecikmeli etki var", "cost": "Maliyet",
		"yourChoice": "Seçimin", "dyk": "Biliyor muydun?", "next": "Devam",
		"walkOn": "Yürümeye devam et", "toEvent": "On yılı tamamla",
		"allDone": "Bu on yılın üç kararı tamam.",
		"ok": "Hazırlıklıydın, zarar azaldı.", "bad": "Hazırlıksız yakalandın.",
		"warnOk": "Erken uyarı sistemi zararı yarıya indirdi.",
		"delayed": "Geçmiş kararların gecikmeli etkileri",
		"introH": "Isınan Akdeniz'de bir şehri ayakta tut.",
		"introP": "Antalya'nın iklim uyum koordinatörüsün. Şehri yürüyerek dolaş, sorunları yerinde gör ve kararını orada ver. Önünde üç on yıl, dokuz karar ve sınırlı bir bütçe var.",
		"how": [
			"Her on yılda şehirde üç karar noktası parlar. Oku takip et ve halkaya yürü.",
			"Her on yıl 10 kaynak alırsın; harcamadığın kaynak devreder.",
			"Doğru cevap yok, sadece takaslar var. Kararların şehri görünür şekilde değiştirir.",
			"On yılın sonunda bir iklim olayı yaşanır. Hazırlık yaptığın riskte zarar azalır.",
		],
		"dur": "Yaklaşık 6 dakika",
		"score": "Dayanıklılık puanı", "weakest": "En zayıf alanın",
		"journey": "Kararların", "events": "Yaşanan olaylar",
		"voteH": "Gerçek Antalya için önerin",
		"voteP": "Oyunda öğrendiklerine göre belediyenin öncelik vermesi gereken 3 alanı seç.",
		"save": "Önerimi kaydet", "pick": "3 alan seç",
		"saved": "Kaydedildi. Bu cihazda oynayanların öncelikleri:",
		"again": "Tekrar oyna",
		"footer": "Olaylar ve etkiler eğitsel amaçla basitleştirilmiştir. Kaynaklar: MedECC (2020) Akdeniz'de iklim ve çevresel değişim raporu; Dünya Meteoroloji Örgütü, Herkes için Erken Uyarı girişimi. Öneriler yalnızca bu cihazda saklanır.",
		"lang": "EN",
	},
	"en": {
		"sub": "COP31 · Climate-resilient city game",
		"start": "Start the game", "w": "Water", "h": "Health", "e": "Economy", "n": "Nature",
		"budget": "Budget", "unit": "credits",
		"period": ["Today - 2030", "2030 - 2040", "2040 - 2050"],
		"reach": ["2030 has arrived", "2040 has arrived", "2050 has arrived"],
		"tasks": "This decade's tasks", "done": "done",
		"controls": "WASD / arrow keys or click the ground: walk   ·   E: decide",
		"prompt": "Decide", "follow": "Follow the arrow and walk into the glowing ring.",
		"choose": "Choose", "notEnough": "Not enough budget", "disc": "Early investment discount",
		"prot": "Protects", "risk": "Raises risk", "later": "Has a delayed effect", "cost": "Cost",
		"yourChoice": "Your choice", "dyk": "Did you know?", "next": "Continue",
		"walkOn": "Keep walking", "toEvent": "Finish the decade",
		"allDone": "All three decisions for this decade are made.",
		"ok": "You were prepared; damage was reduced.", "bad": "You were caught unprepared.",
		"warnOk": "The early warning system halved the damage.",
		"delayed": "Delayed effects of past decisions",
		"introH": "Keep a city standing on a warming Mediterranean.",
		"introP": "You are Antalya's climate adaptation coordinator. Walk the city, see each problem on the spot and decide there. Ahead of you: three decades, nine decisions and a limited budget.",
		"how": [
			"Each decade three decision points light up. Follow the arrow and walk into the ring.",
			"You get 10 credits each decade; unspent credits carry over.",
			"There is no right answer, only trade-offs. Your choices visibly change the city.",
			"Each decade ends with a climate event. Damage is lower for risks you prepared for.",
		],
		"dur": "About 6 minutes",
		"score": "Resilience score", "weakest": "Your weakest area",
		"journey": "Your decisions", "events": "Events that hit",
		"voteH": "Your advice for the real Antalya",
		"voteP": "Based on what you learned, pick the 3 areas the city should prioritise.",
		"save": "Save my advice", "pick": "Pick 3 areas",
		"saved": "Saved. Priorities of players on this device:",
		"again": "Play again",
		"footer": "Events and effects are simplified for learning. Sources: MedECC (2020) Climate and Environmental Change in the Mediterranean; World Meteorological Organization, Early Warnings for All. Advice is stored only on this device.",
		"lang": "TR",
	},
}

const TAGS := {
	"water": {"tr": "Kuraklık", "en": "Drought"},
	"heat": {"tr": "Sıcak dalgası", "en": "Heatwave"},
	"fire": {"tr": "Yangın", "en": "Wildfire"},
	"flood": {"tr": "Sel", "en": "Flood"},
	"food": {"tr": "Kuraklık (tarım)", "en": "Drought (farms)"},
	"energy": {"tr": "Sıcak dalgası (enerji)", "en": "Heatwave (power)"},
	"sea": {"tr": "Deniz ısınması", "en": "Marine heat"},
	"warn": {"tr": "Tüm olaylar", "en": "All events"},
}

const THEMES := [
	{"tr": "Su yönetimi", "en": "Water management"},
	{"tr": "Kentsel ısı", "en": "Urban heat"},
	{"tr": "Yangınla mücadele", "en": "Wildfire defence"},
	{"tr": "Sel ve taşkın", "en": "Floods"},
	{"tr": "Tarımda su", "en": "Water for farming"},
	{"tr": "Temiz enerji", "en": "Clean energy"},
	{"tr": "Deniz ve kıyı", "en": "Sea and coast"},
	{"tr": "Sıfır atık", "en": "Zero waste"},
	{"tr": "Erken uyarı", "en": "Early warning"},
]

## Her karar: yerdeki istasyonun adı ve konumu (x, z), başlık, bağlam, bilgi notu, 3 seçenek.
const DEC := [
	{
		"place": {"tr": "Su deposu", "en": "Water reservoir"}, "pos": Vector2(-21, 1),
		"title": {"tr": "Kuraklık kapıda", "en": "Drought at the door"},
		"ctx": {"tr": "Yeraltı suyu her yıl biraz daha düşüyor, yaz aylarında şebeke zorlanıyor.", "en": "Groundwater drops a little more every year and the network struggles each summer."},
		"fact": {"tr": "Akdeniz havzası küresel ortalamadan yaklaşık %20 daha hızlı ısınıyor; bölgede yağışın azalması ve kuraklıkların sıklaşması bekleniyor (MedECC, 2020).", "en": "The Mediterranean basin is warming about 20% faster than the global average; less rain and more frequent droughts are expected (MedECC, 2020)."},
		"opts": [
			{"label": {"tr": "Kaçakları onar, akıllı sayaç tak", "en": "Fix leaks, install smart meters"}, "desc": {"tr": "Şebekede kaybolan suyu azaltır.", "en": "Cuts water lost in the network."}, "cost": 4, "eff": {"w": 12, "e": -2}, "tags": ["water"]},
			{"label": {"tr": "Yağmur suyu hasadı ve gri su", "en": "Rainwater harvesting and greywater"}, "desc": {"tr": "Yeni binalarda yağmur suyu toplama ve gri suyun yeniden kullanımı zorunlu olur.", "en": "New buildings must collect rainwater and reuse greywater."}, "cost": 6, "eff": {"w": 16, "n": 4, "e": -3}, "tags": ["water"]},
			{"label": {"tr": "Yeni derin kuyular aç", "en": "Drill new deep wells"}, "desc": {"tr": "Hızlı ve ucuz, ama kıyıdaki yeraltı suyunu tüketir.", "en": "Fast and cheap, but drains coastal groundwater."}, "cost": 2, "eff": {"w": 8, "n": -6}, "later": {"due": 1, "eff": {"w": -12, "e": -3}, "msg": {"tr": "Aşırı çekilen kıyı kuyularına deniz suyu karıştı.", "en": "Seawater seeped into over-pumped coastal wells."}}},
		],
	},
	{
		"place": {"tr": "Kent meydanı", "en": "Town square"}, "pos": Vector2(0, 3),
		"title": {"tr": "Şehir fırına dönüyor", "en": "The city is turning into an oven"},
		"ctx": {"tr": "Yaz geceleri artık serinlemiyor; yaşlılar ve dışarıda çalışanlar risk altında.", "en": "Summer nights no longer cool down; older people and outdoor workers are at risk."},
		"fact": {"tr": "Asfalt ve beton gündüz ısıyı depolayıp gece geri verir. Ağaçlı sokaklar ve açık renkli çatılar şehir içi sıcaklığı belirgin şekilde düşürebilir.", "en": "Asphalt and concrete store heat by day and release it at night. Tree-lined streets and light-coloured roofs can noticeably cool a city."},
		"opts": [
			{"label": {"tr": "Gölgeli sokaklar: ağaçlandırma", "en": "Shaded streets: tree planting"}, "desc": {"tr": "Gölge sağlar, havayı serinletir, doğaya katkı verir.", "en": "Gives shade, cools the air and helps nature."}, "cost": 5, "eff": {"h": 10, "n": 8}, "tags": ["heat"]},
			{"label": {"tr": "Serin çatılar ve serinleme merkezleri", "en": "Cool roofs and cooling centres"}, "desc": {"tr": "Açık renkli çatılar ve sıcakta açık kamu binaları.", "en": "Light-coloured roofs and public buildings open in the heat."}, "cost": 4, "eff": {"h": 12, "e": -2}, "tags": ["heat"]},
			{"label": {"tr": "Klima teşviki dağıt", "en": "Subsidise air conditioners"}, "desc": {"tr": "Hemen rahatlatır; elektrik talebini ve dış ortam ısısını artırır.", "en": "Instant relief; raises power demand and outdoor heat."}, "cost": 2, "eff": {"h": 6, "e": 2, "n": -4}, "later": {"due": 1, "eff": {"e": -6, "h": -4}, "msg": {"tr": "Sıcak dalgasında elektrik şebekesi pik yüke dayanamadı.", "en": "The grid buckled under peak demand during a heatwave."}}},
		],
	},
	{
		"place": {"tr": "Orman sınırı", "en": "Forest edge"}, "pos": Vector2(-6, -12),
		"title": {"tr": "Ormanla şehir arasındaki çizgi", "en": "The line between forest and city"},
		"ctx": {"tr": "Yerleşimler ormana yaklaştıkça yangın hem doğayı hem evleri tehdit ediyor.", "en": "As neighbourhoods creep toward the forest, wildfire threatens both nature and homes."},
		"fact": {"tr": "2021 yazında Manavgat ve çevresindeki yangınlar Türkiye'nin yakın tarihindeki en büyük orman yangınları arasında yer aldı. Sıcak, kuru ve rüzgârlı günler riski artırıyor.", "en": "The 2021 fires around Manavgat were among the largest in Türkiye's recent history. Hot, dry and windy days raise the risk."},
		"opts": [
			{"label": {"tr": "Yangın emniyet şeritleri ve bakım", "en": "Firebreaks and forest maintenance"}, "desc": {"tr": "Yanıcı malzeme temizlenir, yangının yayılması yavaşlar.", "en": "Clears fuel and slows the spread of fire."}, "cost": 4, "eff": {"n": 6, "e": -1}, "tags": ["fire"]},
			{"label": {"tr": "Gönüllü gözcü ağı ve erken ihbar", "en": "Volunteer lookouts and early reporting"}, "desc": {"tr": "Yangın küçükken fark edilir.", "en": "Fires are spotted while still small."}, "cost": 3, "eff": {"h": 4, "n": 2}, "tags": ["fire"]},
			{"label": {"tr": "Şimdilik ertele, bütçeyi turizme aktar", "en": "Postpone, move the budget to tourism"}, "desc": {"tr": "Bu on yılda ekonomiye katkı sağlar.", "en": "Boosts the economy this decade."}, "cost": 0, "eff": {"e": 6}, "flags": ["fireRisk"], "risk": true},
		],
	},
	{
		"place": {"tr": "Kıyı yolu", "en": "Coastal road"}, "pos": Vector2(7, 11),
		"title": {"tr": "Bir gün kuraklık, bir gün sel", "en": "Drought one day, flood the next"},
		"ctx": {"tr": "Kısa sürede düşen yoğun yağış, betonla kaplı sokaklarda taşkına dönüşüyor.", "en": "Intense bursts of rain turn paved streets into torrents."},
		"fact": {"tr": "Kuraklık ve ani sağanak aynı şehirde birlikte görülebilir. Sertleşmiş toprak ve beton yüzeyler suyu emmez, taşkın riski artar.", "en": "Drought and sudden downpours can hit the same city. Hardened soil and concrete do not absorb water, so flood risk rises."},
		"opts": [
			{"label": {"tr": "Sünger şehir: geçirgen zemin, yağmur bahçeleri", "en": "Sponge city: permeable ground, rain gardens"}, "desc": {"tr": "Yağmur suyunu toprağa geri kazandırır.", "en": "Lets rainwater soak back into the ground."}, "cost": 6, "eff": {"w": 6, "n": 8, "h": 2}, "tags": ["flood"], "disc": {"tag": "water", "amt": 2}},
			{"label": {"tr": "Beton kanallar ve set", "en": "Concrete channels and levees"}, "desc": {"tr": "Suyu hızla denize taşır, doğal alanları daraltır.", "en": "Rushes water to the sea, shrinks natural areas."}, "cost": 5, "eff": {"e": 2, "n": -8}, "tags": ["flood"]},
			{"label": {"tr": "Ertele", "en": "Postpone"}, "desc": {"tr": "Bütçe korunur.", "en": "Saves the budget."}, "cost": 0, "eff": {"e": 4}, "risk": true},
		],
	},
	{
		"place": {"tr": "Seralar", "en": "Greenhouses"}, "pos": Vector2(21, -4),
		"title": {"tr": "Seralar susuz kalmasın", "en": "Keep the greenhouses watered"},
		"ctx": {"tr": "Sera tarımı hem binlerce kişinin geçim kaynağı hem de büyük bir su tüketicisi.", "en": "Greenhouse farming feeds thousands of livelihoods and uses a lot of water."},
		"fact": {"tr": "Antalya, Türkiye'nin örtü altı (sera) sebze üretiminde öne çıkan illerin başında gelir. Damla sulama, salma sulamaya göre çok daha az su kullanır.", "en": "Antalya is one of Türkiye's leading provinces for greenhouse vegetables. Drip irrigation uses far less water than flood irrigation."},
		"opts": [
			{"label": {"tr": "Damla sulama ve nem sensörü desteği", "en": "Drip irrigation and soil sensors"}, "desc": {"tr": "Çiftçiye su tasarruflu sulama desteği.", "en": "Helps farmers irrigate with less water."}, "cost": 4, "eff": {"w": 10, "e": 4}, "tags": ["food"], "disc": {"tag": "water", "amt": 1}},
			{"label": {"tr": "Kuraklığa dayanıklı yerel tohum bankası", "en": "Drought-tolerant local seed bank"}, "desc": {"tr": "Yerel çeşitler daha az suyla yetişir.", "en": "Local varieties grow with less water."}, "cost": 3, "eff": {"n": 6, "e": 2}, "tags": ["food"]},
			{"label": {"tr": "Tarımsal suyu sübvanse et", "en": "Subsidise farm water"}, "desc": {"tr": "Çiftçiyi rahatlatır, su tüketimini artırır.", "en": "Eases farmers' costs, raises water use."}, "cost": 2, "eff": {"e": 6, "w": -10}, "risk": true},
		],
	},
	{
		"place": {"tr": "Otel bölgesi", "en": "Hotel district"}, "pos": Vector2(19, 11),
		"title": {"tr": "Oteller, güneş ve elektrik", "en": "Hotels, sun and power"},
		"ctx": {"tr": "Turizm şehrin motoru; yaz zirvesinde enerji ve su talebi katlanıyor.", "en": "Tourism drives the city; summer peaks multiply energy and water demand."},
		"fact": {"tr": "Antalya yılın büyük bölümünde yüksek güneşlenme alır. Sıcak hava dalgaları klima kullanımını ve elektrik talebini aynı anda zirveye taşır.", "en": "Antalya gets strong sunshine most of the year. Heatwaves push air-conditioning and power demand to their peak at the same time."},
		"opts": [
			{"label": {"tr": "Otel çatılarına güneş paneli zorunluluğu", "en": "Mandatory rooftop solar on hotels"}, "desc": {"tr": "Zirve saatte kendi elektriğini üretir.", "en": "Hotels make their own power at peak hours."}, "cost": 5, "eff": {"e": 6, "h": 4, "n": 4}, "tags": ["energy"], "disc": {"tag": "heat", "amt": 1}},
			{"label": {"tr": "Dört mevsim turizm", "en": "Year-round tourism"}, "desc": {"tr": "Yaz zirvesini yayar, su ve enerji baskısını azaltır.", "en": "Spreads the summer peak, easing water and power."}, "cost": 3, "eff": {"e": 8, "w": 4}},
			{"label": {"tr": "Yeni kıyı oteli bölgesi aç", "en": "Open a new coastal hotel zone"}, "desc": {"tr": "Hızlı gelir; kıyı ve su kaynakları baskı altında kalır.", "en": "Quick income; puts the coast and water under pressure."}, "cost": 0, "eff": {"e": 12, "n": -12, "w": -6}, "flags": ["hotel"], "risk": true, "later": {"due": 1, "eff": {"e": -8, "n": -4}, "msg": {"tr": "Yeni otellerin önündeki kumsal erozyonla daraldı.", "en": "Erosion narrowed the beach in front of the new hotels."}}},
		],
	},
	{
		"place": {"tr": "İskele", "en": "Pier"}, "pos": Vector2(-10, 14),
		"title": {"tr": "Isınan deniz", "en": "A warming sea"},
		"ctx": {"tr": "Deniz suyu sıcaklığı yükseliyor; kıyı ekosistemi ve balıkçılık baskı altında.", "en": "Sea temperatures are rising; coastal ecosystems and fishing are under strain."},
		"fact": {"tr": "Deniz çayırları (Posidonia oceanica) karbon depolar, kıyıyı dalgalara karşı korur ve balıklara yuva olur.", "en": "Seagrass meadows (Posidonia oceanica) store carbon, shield the shore from waves and shelter fish."},
		"opts": [
			{"label": {"tr": "Deniz koruma alanı, deniz çayırlarını koru", "en": "Marine protected area for seagrass"}, "desc": {"tr": "Ekosistem toparlanır, balıkçılık güçlenir.", "en": "Ecosystems recover and fishing improves."}, "cost": 4, "eff": {"n": 12, "e": 2}, "tags": ["sea"]},
			{"label": {"tr": "Riskli kıyıda yapılaşmayı durdur", "en": "Halt building on at-risk coastline"}, "desc": {"tr": "İnsanları ve doğal kıyıyı korur, kısa vadede gelir kaybı.", "en": "Protects people and the natural shore; short-term income loss."}, "cost": 5, "eff": {"h": 6, "n": 6, "e": -4}, "tags": ["sea", "flood"]},
			{"label": {"tr": "Kumsal besleme: dışarıdan kum taşı", "en": "Beach nourishment: truck in sand"}, "desc": {"tr": "Sezonu kurtarır, deniz tabanına zarar verir.", "en": "Saves the season, harms the seabed."}, "cost": 3, "eff": {"e": 6, "n": -4}},
		],
	},
	{
		"place": {"tr": "Atık sahası", "en": "Waste site"}, "pos": Vector2(-22, -9),
		"title": {"tr": "Sezonun çöpü", "en": "The season's waste"},
		"ctx": {"tr": "Turizm sezonunda atık miktarı katlanıyor, depolama alanı doluyor.", "en": "Waste multiplies in the tourist season and the landfill is filling up."},
		"fact": {"tr": "Organik atığın kompostlanması, depolama alanlarında oluşan ve güçlü bir sera gazı olan metanın salımını azaltır.", "en": "Composting organic waste cuts methane, a powerful greenhouse gas formed in landfills."},
		"opts": [
			{"label": {"tr": "Otellerde sıfır atık ve kompost", "en": "Zero waste and composting in hotels"}, "desc": {"tr": "Kaynağında ayrıştırma ve kompost.", "en": "Sorting at source and composting."}, "cost": 3, "eff": {"n": 8, "e": 2, "h": 2}},
			{"label": {"tr": "Atıktan enerji tesisi", "en": "Waste-to-energy plant"}, "desc": {"tr": "Elektrik üretir, hava kalitesine dikkat ister.", "en": "Makes power; needs careful air-quality control."}, "cost": 5, "eff": {"e": 4, "n": 2, "h": -2}},
			{"label": {"tr": "Depolama alanını genişlet", "en": "Expand the landfill"}, "desc": {"tr": "En ucuz yol; sızıntı yeraltı suyunu kirletebilir.", "en": "Cheapest option; leachate can pollute groundwater."}, "cost": 1, "eff": {"e": 2, "n": -6, "w": -4}, "risk": true},
		],
	},
	{
		"place": {"tr": "Belediye binası", "en": "City hall"}, "pos": Vector2(7, -4),
		"title": {"tr": "Herkes zamanında haberdar olsun", "en": "Everyone warned in time"},
		"ctx": {"tr": "Olaylar sıklaştıkça birkaç saat önceden yapılan uyarı can kurtarıyor.", "en": "As events become more frequent, a warning a few hours ahead saves lives."},
		"fact": {"tr": "Dünya Meteoroloji Örgütü'nün Herkes için Erken Uyarı girişimi, 2027 sonuna kadar dünyadaki herkesin erken uyarı sistemleriyle korunmasını hedefliyor.", "en": "The World Meteorological Organization's Early Warnings for All initiative aims to cover everyone on Earth with early warning systems by the end of 2027."},
		"opts": [
			{"label": {"tr": "Herkes için erken uyarı: SMS ve siren", "en": "Early warning for all: SMS and sirens"}, "desc": {"tr": "Tüm olaylarda zararı yarıya indirir.", "en": "Halves the damage of any event."}, "cost": 4, "eff": {"h": 10}, "tags": ["warn"]},
			{"label": {"tr": "Okullarda iklim eğitimi ve mahalle gönüllüleri", "en": "Climate lessons in schools, neighbourhood volunteers"}, "desc": {"tr": "Halk ne yapacağını bilir; olaylarda zarar yarıya iner.", "en": "People know what to do; event damage is halved."}, "cost": 3, "eff": {"h": 6, "n": 4}, "tags": ["warn"]},
			{"label": {"tr": "Uyarıyı mevcut sistemlere bırak", "en": "Leave warnings to existing systems"}, "desc": {"tr": "Bütçe korunur.", "en": "Saves the budget."}, "cost": 0, "eff": {"e": 3}, "risk": true},
		],
	},
]

const EVENTS := {
	"heat": {"title": {"tr": "Rekor sıcak hava dalgası", "en": "Record heatwave"}, "desc": {"tr": "Günlerce 44°C'nin üzerinde sıcaklık. Hastaneler doluyor, sokaklar boşalıyor.", "en": "Days above 44°C. Hospitals fill up and streets empty."}, "tags": ["heat", "energy"], "dmg": {"h": -16, "e": -6}, "prot": {"h": -5, "e": -2}},
	"fire": {"title": {"tr": "Orman yangını", "en": "Wildfire"}, "desc": {"tr": "Kuru ve rüzgârlı bir öğleden sonra Toroslar'da yangın başladı.", "en": "On a dry, windy afternoon a fire breaks out in the Taurus Mountains."}, "tags": ["fire"], "dmg": {"n": -18, "e": -8, "h": -6}, "prot": {"n": -6, "e": -2}},
	"drought": {"title": {"tr": "Uzun kuraklık", "en": "Prolonged drought"}, "desc": {"tr": "İki kış üst üste yağış gelmedi. Barajlar ve kuyular çekiliyor, seralar susuz.", "en": "Two dry winters in a row. Reservoirs and wells shrink, greenhouses go dry."}, "tags": ["water", "food"], "dmg": {"w": -16, "e": -6}, "prot": {"w": -5, "e": -2}},
	"flood": {"title": {"tr": "Ani sel", "en": "Flash flood"}, "desc": {"tr": "Bir gecede aylık yağışın yarısı düştü. Alt geçitler ve kıyı mahalleleri su altında.", "en": "Half a month's rain fell overnight. Underpasses and coastal districts are under water."}, "tags": ["flood"], "dmg": {"e": -12, "h": -8, "w": -4}, "prot": {"e": -3, "h": -2}},
	"marine": {"title": {"tr": "Deniz sıcak dalgası", "en": "Marine heatwave"}, "desc": {"tr": "Deniz suyu haftalarca normalin çok üzerinde kaldı. Balıklar çekildi, kıyı ekosistemi zarar gördü.", "en": "The sea stayed far above normal for weeks. Fish moved away and coastal ecosystems suffered."}, "tags": ["sea"], "dmg": {"n": -14, "e": -6}, "prot": {"n": -5}},
}

const POOLS := [["heat", "fire", "drought"], ["flood", "drought", "heat"], ["fire", "flood", "marine", "heat"]]

const GRADES := [
	{"min": 66, "tr": ["Dirençli Antalya", "2050'de şehir sıcağa, yangına ve sele rağmen ayakta. Erken davrandın ve takasları dengeli yönettin."], "en": ["Resilient Antalya", "In 2050 the city still stands despite heat, fire and floods. You acted early and balanced the trade-offs."]},
	{"min": 50, "tr": ["Ayakta ama kırılgan", "Şehir krizleri atlattı ama zayıf noktaları açıkta. Bir sonraki büyük olayın bedeli ağır olabilir."], "en": ["Standing, but fragile", "The city got through the crises, but its weak spots are exposed. The next big event could be costly."]},
	{"min": 0, "tr": ["Kriz kenti", "Ertelenen kararların faturası birikti. 2050'de Antalya kendi iklimine uyum sağlayamadı."], "en": ["City in crisis", "The bill for postponed decisions piled up. By 2050 Antalya could not adapt to its own climate."]},
]
