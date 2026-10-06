import '../domain/question.dart';

/// Uygulamanın soru bankası.
///
/// Testler bu bankadan deterministik olarak beslenir (bkz. `TestCatalog`).
/// Gerçek/AI üretimli soru bankası bağlandığında yalnızca bu dosyanın yerine
/// bir veri kaynağı geçecek; model ve ekranlar aynı kalacak.
abstract final class QuestionBank {
  static const List<Question> all = [
    // ----------------------------------------------- Trafik ve Çevre
    Question(
      id: 'tr-01',
      category: QuestionCategory.trafik,
      text: 'Kavşaklarda, tali yoldan ana yola çıkan sürücü ne yapmalıdır?',
      options: [
        'Kavşağa hızla girip geçmelidir',
        'Ana yoldaki araçlara geçiş hakkı vermelidir',
        'Korna çalarak geçiş hakkı istemelidir',
        'Ana yoldaki araçları takip etmelidir',
      ],
      correctIndex: 1,
      explanation: 'Tali yoldan ana yola çıkan sürücü, ana yolda seyreden '
          'araçlara geçiş hakkı vermek zorundadır.',
    ),
    Question(
      id: 'tr-02',
      category: QuestionCategory.trafik,
      text: 'Yerleşim yeri içinde otomobiller için azami hız sınırı kaç '
          'km/saattir?',
      options: ['30 km/saat', '50 km/saat', '70 km/saat', '90 km/saat'],
      correctIndex: 1,
      explanation: 'Aksi bir işaretle belirtilmedikçe yerleşim yeri içinde '
          'otomobiller için hız sınırı 50 km/saattir.',
    ),
    Question(
      id: 'tr-03',
      category: QuestionCategory.trafik,
      text: 'Otoyolda otomobiller için asgari (en az) hız sınırı kaç '
          'km/saattir?',
      options: ['30 km/saat', '40 km/saat', '50 km/saat', '60 km/saat'],
      correctIndex: 1,
      explanation: 'Otoyollarda asgari hız sınırı 40 km/saattir; bu hızın '
          'altında seyretmek trafiği tehlikeye atar.',
    ),
    Question(
      id: 'tr-04',
      category: QuestionCategory.trafik,
      text: 'Şehirler arası çift yönlü karayolunda otomobiller için azami hız '
          'sınırı kaç km/saattir?',
      options: ['70 km/saat', '82 km/saat', '90 km/saat', '110 km/saat'],
      correctIndex: 2,
      explanation: 'Şehirler arası çift yönlü karayollarında otomobiller için '
          'azami hız 90 km/saattir.',
    ),
    Question(
      id: 'tr-05',
      category: QuestionCategory.trafik,
      text: 'Sarı ışık yandığında sürücü ne yapmalıdır?',
      options: [
        'Hızlanarak kavşağı geçmelidir',
        'Yavaşlayıp durma çizgisinde durmalıdır',
        'Korna çalarak devam etmelidir',
        'Şerit değiştirmelidir',
      ],
      correctIndex: 1,
      explanation: 'Sarı ışık "durmaya hazırlan" anlamındadır; güvenli şekilde '
          'yavaşlayıp durma çizgisinde durulur.',
    ),
    Question(
      id: 'tr-06',
      category: QuestionCategory.trafik,
      text: 'Dönel kavşakta (göbekli kavşak) geçiş hakkı kimindir?',
      options: [
        'Kavşağa yeni girecek olan sürücünün',
        'Kavşak içinde, ada etrafında dönmekte olan sürücünün',
        'Daha büyük araç kullanan sürücünün',
        'Sağdan gelen sürücünün',
      ],
      correctIndex: 1,
      explanation: 'Dönel kavşakta ada etrafında dönmekte olan araç geçiş '
          'hakkına sahiptir; kavşağa girecek olan bekler.',
    ),
    Question(
      id: 'tr-07',
      category: QuestionCategory.trafik,
      text: 'Kuralına uygun takip mesafesi nasıl hesaplanır?',
      options: [
        'Hızın yarısı kadar metre',
        'Hızın iki katı kadar metre',
        'Her zaman 10 metre',
        'Araç uzunluğunun yarısı kadar metre',
      ],
      correctIndex: 0,
      explanation: 'Takip mesafesi, kilometre/saat cinsinden hızın yarısı '
          'kadar metre olarak alınır (80 km/saat için 40 metre).',
    ),
    Question(
      id: 'tr-08',
      category: QuestionCategory.trafik,
      text: 'Kenarında yaya geçidi bulunan bir yerde yaya geçide girmişse '
          'sürücü ne yapar?',
      options: [
        'Korna çalıp yayayı uyarır',
        'Yavaşlayıp yayaya geçiş hakkı verir',
        'Yayanın arkasından hızla geçer',
        'Farlarını yakarak geçer',
      ],
      correctIndex: 1,
      explanation: 'Yaya geçidinde geçiş hakkı yayanındır; sürücü yavaşlayıp '
          'gerekirse durur.',
    ),
    Question(
      id: 'tr-09',
      category: QuestionCategory.trafik,
      text: 'Aşağıdakilerden hangisi geçme (sollama) yapılmasının yasak '
          'olduğu yerlerden biridir?',
      options: [
        'Üç şeritli yolun orta şeridi',
        'Görüşün yeterli olduğu düz yol',
        'Dönemeç ve tepe üstü gibi görüşün kapalı olduğu yerler',
        'Yerleşim yeri dışındaki bölünmüş yollar',
      ],
      correctIndex: 2,
      explanation: 'Görüşün yeterli olmadığı dönemeç, tepe üstü ve kavşaklarda '
          'geçme yasaktır.',
    ),
    Question(
      id: 'tr-10',
      category: QuestionCategory.trafik,
      text: 'Üçgen şeklindeki trafik işaretleri neyi bildirir?',
      options: [
        'Tehlike uyarısı',
        'Trafik yasağı',
        'Bilgi ve yönlendirme',
        'Zorunlu yön',
      ],
      correctIndex: 0,
      explanation: 'Kenarları kırmızı, zemini beyaz üçgen levhalar tehlike '
          'uyarı işaretleridir.',
    ),
    Question(
      id: 'tr-11',
      category: QuestionCategory.trafik,
      text: 'Yerleşim yeri içinde dönüş yapacak sürücü, dönüş işaretini en az '
          'kaç metre önceden vermelidir?',
      options: ['10 metre', '30 metre', '80 metre', '150 metre'],
      correctIndex: 1,
      explanation: 'Yerleşim yeri içinde en az 30 metre, dışında en az 150 '
          'metre önceden dönüş işareti verilir.',
    ),
    Question(
      id: 'tr-12',
      category: QuestionCategory.trafik,
      text: 'Aşağıdakilerden hangisi park etmenin yasak olduğu yerlerden '
          'biridir?',
      options: [
        'Geniş banketli yollar',
        'Otoparklar',
        'Yaya geçitleri ve kavşaklar',
        'Park levhası bulunan alanlar',
      ],
      correctIndex: 2,
      explanation: 'Yaya geçitleri, kavşaklar, duraklar ve dönemeçlerde park '
          'etmek yasaktır.',
    ),
    Question(
      id: 'tr-13',
      category: QuestionCategory.trafik,
      text: 'Alkollü içki içen bir sürücüde ilk bozulan yetenek hangisidir?',
      options: [
        'Kas gücü',
        'Muhakeme ve karar verme yeteneği',
        'İşitme duyusu',
        'Tat alma duyusu',
      ],
      correctIndex: 1,
      explanation: 'Alkol önce muhakeme, dikkat ve karar verme yeteneğini '
          'bozar; sürücü riski fark etmeden özgüveni artar.',
    ),
    Question(
      id: 'tr-14',
      category: QuestionCategory.trafik,
      text: 'Araçta emniyet kemeri kullanmak kimler için zorunludur?',
      options: [
        'Yalnızca sürücü için',
        'Yalnızca ön koltuktakiler için',
        'Sürücü dâhil tüm yolcular için',
        'Yalnızca şehirler arası yolculuklarda',
      ],
      correctIndex: 2,
      explanation: 'Emniyet kemeri sürücü dâhil bütün yolcular için zorunludur.',
    ),
    Question(
      id: 'tr-15',
      category: QuestionCategory.trafik,
      text: 'Kavşağa yaklaşan sürücü, kavşak içinde beklemek zorunda kalacağını '
          'anlarsa ne yapmalıdır?',
      options: [
        'Kavşağa girip beklemelidir',
        'Kavşağa girmeden önce durmalıdır',
        'Korna çalarak yol açtırmalıdır',
        'Geri manevra yapmalıdır',
      ],
      correctIndex: 1,
      explanation: 'Kavşağı tıkamamak için, geçemeyeceğini anlayan sürücü '
          'kavşağa girmeden durur.',
    ),

    // --------------------------------------------------------- İlk Yardım
    Question(
      id: 'iy-01',
      category: QuestionCategory.ilkYardim,
      text: 'Bilinci kapalı, solunumu ve nabzı olan bir kazazedeye hangi '
          'pozisyon verilir?',
      options: [
        'Sırt üstü düz yatış',
        'Yarı oturuş pozisyonu',
        'Koma (yan yatış) pozisyonu',
        'Şok pozisyonu',
      ],
      correctIndex: 2,
      explanation: 'Solunum yolunun açık kalması ve kusmuğun akciğere '
          'kaçmaması için koma pozisyonu verilir.',
    ),
    Question(
      id: 'iy-02',
      category: QuestionCategory.ilkYardim,
      text: 'Yetişkinlerde dış kalp masajı dakikada kaç bası hızıyla '
          'uygulanır?',
      options: ['50-60', '80-90', '100-120', '140-160'],
      correctIndex: 2,
      explanation: 'Temel yaşam desteğinde göğüs basısı dakikada 100-120 '
          'hızında uygulanır.',
    ),
    Question(
      id: 'iy-03',
      category: QuestionCategory.ilkYardim,
      text: 'Yetişkinde temel yaşam desteğinde bası-suni solunum oranı kaçtır?',
      options: ['15 bası / 1 solunum', '30 bası / 2 solunum', '5 bası / 1 solunum', '10 bası / 2 solunum'],
      correctIndex: 1,
      explanation: 'Yetişkinde 30 göğüs basısına 2 suni solunum uygulanır.',
    ),
    Question(
      id: 'iy-04',
      category: QuestionCategory.ilkYardim,
      text: 'Atardamar kanamasının belirtisi aşağıdakilerden hangisidir?',
      options: [
        'Koyu renkli, sızarak akan kan',
        'Açık kırmızı renkli, kalp atımıyla fışkıran kan',
        'Renksiz, köpüklü sıvı',
        'Yalnızca deri altında morarma',
      ],
      correctIndex: 1,
      explanation: 'Atardamar kanamasında kan oksijenli olduğu için açık '
          'kırmızıdır ve kalp atımıyla kesik kesik fışkırır.',
    ),
    Question(
      id: 'iy-05',
      category: QuestionCategory.ilkYardim,
      text: 'Solunum yolu tam tıkanmış bilinci açık bir yetişkine hangi '
          'uygulama yapılır?',
      options: [
        'Şok pozisyonu verilir',
        'Bol su içirilir',
        'Heimlich manevrası uygulanır',
        'Sırt üstü yatırılıp beklenir',
      ],
      correctIndex: 2,
      explanation: 'Tam tıkanmada karına bası (Heimlich) manevrası ile yabancı '
          'cismin çıkarılması sağlanır.',
    ),
    Question(
      id: 'iy-06',
      category: QuestionCategory.ilkYardim,
      text: 'Şok pozisyonu nasıl verilir?',
      options: [
        'Sırt üstü yatırılıp bacaklar 30 cm yukarı kaldırılır',
        'Yüz üstü yatırılır',
        'Oturtulup öne eğilir',
        'Yan yatırılıp dizler karına çekilir',
      ],
      correctIndex: 0,
      explanation: 'Şokta beyne giden kanı artırmak için kazazede sırt üstü '
          'yatırılır ve bacakları 30 cm kaldırılır.',
    ),
    Question(
      id: 'iy-07',
      category: QuestionCategory.ilkYardim,
      text: 'Kırık şüphesi olan bir kazazedeye ilk yardımda ne yapılır?',
      options: [
        'Kırık bölge yerine oturtulmaya çalışılır',
        'Kırık bölge hareketsiz hâle getirilir (tespit edilir)',
        'Bölgeye sıcak uygulama yapılır',
        'Kazazede yürütülerek dolaştırılır',
      ],
      correctIndex: 1,
      explanation: 'Kırıkta amaç kemik uçlarının damar ve siniri zedelemesini '
          'önlemektir; bölge olduğu gibi tespit edilir.',
    ),
    Question(
      id: 'iy-08',
      category: QuestionCategory.ilkYardim,
      text: 'İlk yardımın temel uygulamalarından "koruma" ne anlama gelir?',
      options: [
        'Kazazedeyi hastaneye götürmek',
        'Olay yerini güvenli hâle getirip yeni kazaları önlemek',
        'Kazazedeye ilaç vermek',
        'Yakınlarına haber vermek',
      ],
      correctIndex: 1,
      explanation: 'Koruma, olay yerinde ikinci bir kaza olmasını önlemek için '
          'gerekli güvenlik önlemlerini almaktır.',
    ),
    Question(
      id: 'iy-09',
      category: QuestionCategory.ilkYardim,
      text: 'Kazazedenin bilinç durumu nasıl değerlendirilir?',
      options: [
        'Nabzı sayılarak',
        'Omuzlarından hafifçe sarsıp yüksek sesle seslenerek',
        'Göz bebeğine ışık tutularak',
        'Vücut ısısı ölçülerek',
      ],
      correctIndex: 1,
      explanation: 'Bilinç kontrolü, omuzlardan hafifçe sarsıp sesli uyaran '
          'vererek yapılır.',
    ),
    Question(
      id: 'iy-10',
      category: QuestionCategory.ilkYardim,
      text: 'Birinci derece yanıkta görülen belirti hangisidir?',
      options: [
        'Deride kızarıklık ve ağrı',
        'Su toplaması (bül)',
        'Derinin kömürleşmesi',
        'Kas ve kemiğin görünmesi',
      ],
      correctIndex: 0,
      explanation: 'Birinci derece yanık yalnızca üst deriyi etkiler; '
          'kızarıklık, ağrı ve hafif şişlik görülür.',
    ),
    Question(
      id: 'iy-11',
      category: QuestionCategory.ilkYardim,
      text: 'Kanama olan bir yarada ilk yapılması gereken nedir?',
      options: [
        'Yaraya turnike uygulamak',
        'Kanayan yere temiz bezle doğrudan bası yapmak',
        'Yarayı sabunla yıkamak',
        'Yaraya pudra dökmek',
      ],
      correctIndex: 1,
      explanation: 'Kanamada ilk uygulama, temiz bir bezle yaraya doğrudan '
          'bası yapıp bölgeyi kalp seviyesinden yukarı kaldırmaktır.',
    ),
    Question(
      id: 'iy-12',
      category: QuestionCategory.ilkYardim,
      text: 'Hayat kurtarma zincirinin ilk halkası nedir?',
      options: [
        'Temel yaşam desteği',
        'Olay yerinin değerlendirilmesi ve 112\'nin aranması',
        'Hastaneye nakil',
        'İlaç uygulaması',
      ],
      correctIndex: 1,
      explanation: 'Zincir, olay yerinin değerlendirilip acil yardımın (112) '
          'haberdar edilmesiyle başlar.',
    ),

    // ------------------------------------------------ Motor ve Araç Tekniği
    Question(
      id: 'mt-01',
      category: QuestionCategory.motor,
      text: 'Aşağıdakilerden hangisi motor yağının görevi değildir?',
      options: [
        'Yağlama yapmak',
        'Soğutmaya yardımcı olmak',
        'Motoru çalıştırmak',
        'Sürtünmeyi azaltmak',
      ],
      correctIndex: 2,
      explanation: 'Motoru çalıştırma görevi marş motorunundur; yağ yağlar, '
          'soğutur, temizler ve sürtünmeyi azaltır.',
    ),
    Question(
      id: 'mt-02',
      category: QuestionCategory.motor,
      text: 'Fren pedalına basıldığında fren lambalarının yanmasını sağlayan '
          'parça hangisidir?',
      options: ['Fren müşiri', 'Distribütör', 'Alternatör', 'Marş motoru'],
      correctIndex: 0,
      explanation: 'Fren müşiri, pedal hareketini algılayıp fren lambalarının '
          'elektrik devresini tamamlar.',
    ),
    Question(
      id: 'mt-03',
      category: QuestionCategory.motor,
      text: 'Akünün görevi aşağıdakilerden hangisidir?',
      options: [
        'Yakıtı püskürtmek',
        'Elektrik enerjisini kimyasal olarak depolamak',
        'Motoru soğutmak',
        'Egzoz gazını temizlemek',
      ],
      correctIndex: 1,
      explanation: 'Akü, elektrik enerjisini kimyasal enerji olarak depolar ve '
          'özellikle ilk harekette marş motorunu besler.',
    ),
    Question(
      id: 'mt-04',
      category: QuestionCategory.motor,
      text: 'Alternatörün görevi nedir?',
      options: [
        'Motor çalışırken elektrik üretip aküyü şarj etmek',
        'Motoru ilk hareket ettirmek',
        'Yakıt filtresini temizlemek',
        'Vites değiştirmek',
      ],
      correctIndex: 0,
      explanation: 'Alternatör, motor çalışırken hareket enerjisini elektriğe '
          'çevirir; araç elektriğini besler ve aküyü şarj eder.',
    ),
    Question(
      id: 'mt-05',
      category: QuestionCategory.motor,
      text: 'Benzinli motorlarda yakıt-hava karışımını ateşleyen parça '
          'hangisidir?',
      options: ['Buji', 'Enjektör', 'Termostat', 'Karbüratör'],
      correctIndex: 0,
      explanation: 'Benzinli motorlarda ateşleme bujinin oluşturduğu kıvılcımla '
          'sağlanır; dizelde ise sıkıştırma ısısı yeterlidir.',
    ),
    Question(
      id: 'mt-06',
      category: QuestionCategory.motor,
      text: 'Radyatördeki suyun görevi nedir?',
      options: [
        'Motoru yağlamak',
        'Motorun ısısını alıp soğutmasını sağlamak',
        'Yakıt tüketimini azaltmak',
        'Frenleri çalıştırmak',
      ],
      correctIndex: 1,
      explanation: 'Soğutma suyu motordan aldığı ısıyı radyatörde havaya '
          'vererek motorun çalışma sıcaklığını korur.',
    ),
    Question(
      id: 'mt-07',
      category: QuestionCategory.motor,
      text: 'Termostatın görevi aşağıdakilerden hangisidir?',
      options: [
        'Motorun çalışma sıcaklığına çabuk ulaşmasını ve bu sıcaklıkta '
            'kalmasını sağlamak',
        'Yağ basıncını ölçmek',
        'Aküyü şarj etmek',
        'Egzoz sesini azaltmak',
      ],
      correctIndex: 0,
      explanation: 'Termostat, soğuk motorda su dolaşımını kısıtlar; motor '
          'ısındığında devreyi açarak sıcaklığı sabit tutar.',
    ),
    Question(
      id: 'mt-08',
      category: QuestionCategory.motor,
      text: 'Debriyaj (kavrama) sisteminin görevi nedir?',
      options: [
        'Motor gücünü tekerleklere ileten bağlantıyı kesip birleştirmek',
        'Aracı yavaşlatmak',
        'Direksiyonu hafifletmek',
        'Motoru soğutmak',
      ],
      correctIndex: 0,
      explanation: 'Kavrama, vites değiştirirken motor ile şanzıman arasındaki '
          'bağlantıyı geçici olarak keser.',
    ),
    Question(
      id: 'mt-09',
      category: QuestionCategory.motor,
      text: 'Lastik hava basıncının gereğinden düşük olması neye yol açar?',
      options: [
        'Yakıt tüketiminin artmasına ve lastiğin yanlarından aşınmasına',
        'Frenlerin daha iyi tutmasına',
        'Motorun daha az ısınmasına',
        'Direksiyonun ağırlaşmamasına',
      ],
      correctIndex: 0,
      explanation: 'Düşük basınç yuvarlanma direncini artırır; yakıt tüketimi '
          'yükselir ve lastik omuzlarından aşınır.',
    ),
    Question(
      id: 'mt-10',
      category: QuestionCategory.motor,
      text: 'Şanzımanın (vites kutusu) görevi nedir?',
      options: [
        'Motor devrini ve torku yol koşullarına göre tekerleklere aktarmak',
        'Yakıtı depolamak',
        'Motoru ateşlemek',
        'Frenlere basınç üretmek',
      ],
      correctIndex: 0,
      explanation: 'Şanzıman, farklı dişli oranlarıyla motor gücünü yola ve '
          'hıza uygun şekilde tekerleklere iletir.',
    ),
    Question(
      id: 'mt-11',
      category: QuestionCategory.motor,
      text: 'Marş motorunun görevi aşağıdakilerden hangisidir?',
      options: [
        'Motoru ilk hareket ettirmek',
        'Aküyü şarj etmek',
        'Yakıt karışımını ayarlamak',
        'Fren lambalarını yakmak',
      ],
      correctIndex: 0,
      explanation: 'Marş motoru, aküden aldığı elektrikle krank milini '
          'döndürerek motora ilk hareketi verir.',
    ),
    Question(
      id: 'mt-12',
      category: QuestionCategory.motor,
      text: 'Gösterge panelinde yağ basıncı uyarı lambası yanarsa ne '
          'yapılmalıdır?',
      options: [
        'Yola devam edilir, sorun kendiliğinden geçer',
        'Motor derhâl durdurulup yağ seviyesi kontrol edilir',
        'Motor devri yükseltilir',
        'Klima açılır',
      ],
      correctIndex: 1,
      explanation: 'Yağ basıncı uyarısı yağlamanın kesildiğini gösterir; motor '
          'hemen durdurulmazsa ciddi hasar oluşur.',
    ),

    // ------------------------------------------------------- Trafik Adabı
    Question(
      id: 'ta-01',
      category: QuestionCategory.trafikAdabi,
      text: 'Trafikte "geçiş kolaylığı sağlamak" davranışı hangi değerle '
          'ilgilidir?',
      options: [
        'Hız tutkusu',
        'Empati ve nezaket',
        'Rekabet duygusu',
        'Dikkat dağınıklığı',
      ],
      correctIndex: 1,
      explanation: 'Geçiş kolaylığı sağlamak, karşıdakini düşünmeyi gerektiren '
          'bir empati ve nezaket davranışıdır.',
    ),
    Question(
      id: 'ta-02',
      category: QuestionCategory.trafikAdabi,
      text: 'Gece şehir dışında karşıdan araç gelirken hangi far kullanılır?',
      options: [
        'Uzun farlar',
        'Kısa (yakın) farlar',
        'Dörtlü flaşör',
        'Sis farları ve uzun farlar birlikte',
      ],
      correctIndex: 1,
      explanation: 'Karşıdan gelen sürücünün gözünü almamak için uzun far '
          'söndürülüp kısa farla devam edilir.',
    ),
    Question(
      id: 'ta-03',
      category: QuestionCategory.trafikAdabi,
      text: 'Öfkeli bir sürücünün trafikteki en olası davranışı hangisidir?',
      options: [
        'Takip mesafesini artırmak',
        'Saldırgan sürüş ve gereksiz korna kullanımı',
        'Yol verme davranışı',
        'Hız sınırına uymak',
      ],
      correctIndex: 1,
      explanation: 'Öfke, dikkati daraltır ve saldırgan sürüşe yol açar; kaza '
          'riskini belirgin şekilde artırır.',
    ),
    Question(
      id: 'ta-04',
      category: QuestionCategory.trafikAdabi,
      text: 'Trafikte kurallara uymanın temel amacı nedir?',
      options: [
        'Ceza almamak',
        'Daha hızlı gitmek',
        'Herkesin güvenli ve düzenli şekilde yolculuk etmesini sağlamak',
        'Sigorta indirimi kazanmak',
      ],
      correctIndex: 2,
      explanation: 'Kurallar, yolu paylaşan herkesin can güvenliğini ve trafik '
          'düzenini korumak için vardır.',
    ),
  ];

  /// Belirli bir kategorideki sorular.
  static List<Question> byCategory(QuestionCategory category) =>
      all.where((question) => question.category == category).toList();
}
